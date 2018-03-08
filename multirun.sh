#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# HOST="http://localhost:8080/ipfs"
# IPFS_HASH="QmUtyrtpwXy7fq6pu6rFQijNcmZaY6XeR2n3oThu2XjBEQ"
STATS_FILE="stats.csv"
head -n 1 "$DIR/template" > "$DIR/$STATS_FILE"
touch $STATS_FILE
sed -i "1s/.*/time,size,file,nodes,clients/" "$STATS_FILE"

DEV=lo
DELAY=50ms
SPEED="12M"    # Limit network speed for cURL
KBITSPEED=10240 # 1Gbit in Kbit
NODES=(50 60 70)
client=10
tc qdisc del dev "$DEV" root netem
for node in "${NODES[@]}"; do
    iptb init -n "$((node + client))" --bootstrap none -f
    trickled 
    WEBPORT=8080
    APIPORT=5001
    export IPFS_PATH="$HOME/testbed/0"
    IPFS_HASH="$(ipfs add -nr "$DIR/files/go-ipfs-0.4.13" | tail -n 1 | awk '{print $2}')"
    unset IPFS_PATH
    for (( i = 0; i < client; i++ )); do
        export IPFS_PATH="$HOME/testbed/$i"
        ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/"$((WEBPORT + i))"
        ipfs config Datastore.StorageMax 0GB
        ipfs config Datastore.GCPeriod 0h
        unset IPFS_PATH
    done
    APILIST=()
    for (( i = 0; i < node + client; i++ )); do
        export IPFS_PATH="$HOME/testbed/$i"
        ipfs config Addresses.API /ip4/0.0.0.0/tcp/"$((APIPORT + i))"
        APILIST+=$((APIPORT + i))
        trickle -s -u "$KBITSPEED" -d "$KBITSPEED" ipfs daemon > "$IPFS_PATH/daemon.stdout" 2> "$IPFS_PATH/daemon.stderr" &
        echo $! > "$IPFS_PATH/daemon.pid"
        echo "Starting node $i"
        unset IPFS_PATH
    done
    STARTED=0
    while((STARTED > (node + client))); do
        STARTED=0
        for requsts in "${APILIST[@]}"; do
            if curl -s "http://localhost:$requsts"; then
                ((started++))
            fi
        done
        sleep 1
    done
    echo "Done starting daemons"
    NODE_0_ADDR="$(curl -s http://localhost:5001/api/v0/id?format=\<id\> | jq '.Addresses[0]' | cut -d "\"" -f 2)"
    echo "${NODE_0_ADDR}"

    for (( i = 1; i < node + client; i++ )); do
        API="http://localhost:$((APIPORT + i))/api/v0"
        curl -sSn "$API/bootstrap/add?arg=${NODE_0_ADDR}"
        curl -sSn "$API/swarm/connect?arg=${NODE_0_ADDR}"
    done

    replicas="$(shuf -i${client}-$((node + client - 1)) -n$((node / 8)))"
    for replica in "${replicas[@]}"; do
        files=$(find $DIR/files/go-ipfs-0.4.13/* -maxdepth 0 | head -n $((replica % 6)))
        API="http://localhost:$((APIPORT + replica))/api/v0"
        echo "$API"
        for file in "${files[@]}"; do
            curl -s -F file="@$file" "$API/add?recursive=true"
        done
        echo "Node: $(curl "$API/id?format=\<id\>" | jq '.ID') is adding files"
    done
    API="http://localhost:$((APIPORT + (client + node - 1)))/api/v0"
    IPFS_HASH="$(curl -s -F file="@$DIR/files/go-ipfs-0.4.13" "$API/add?recursive=true" | jq '.Hash' | cut -d "\"" -f 2)"
    echo "Node: $(curl "$API/id?format=\<id\>" | jq '.ID') is adding files"

    echo "Done adding files"

    tc qdisc add dev "$DEV" root netem delay "$DELAY" 20ms distribution normal

    IPFS_FILE="$(find $DIR/files/* -maxdepth 0 -type d -exec basename {} \;)"
    IPFS_FILE_SIZE="$(curl -s http://localhost:5001/api/v0/files/stat?arg="/ipfs/$IPFS_HASH" | jq '.CumulativeSize')"
    ITERATIONS=50
    pids=()
    WEBPORT=8080
    APIPORT=5001
    {
        for (( i = 0; i < "$client"; i++ )); do
            HOST="http://localhost:$((WEBPORT + i))/ipfs"
            API="http://localhost:$((APIPORT + i))/api/v0"
            bash "$DIR/download.sh" $HOST $IPFS_HASH $IPFS_FILE_SIZE $IPFS_FILE $node $ITERATIONS $API $client &
            pids+=($!)
        done
    } >> "$DIR/stats.csv"
    wait "${pids[@]}"
    pkill ipfs
    pkill trickle
    pkill trickled
    tc qdisc del dev "$DEV" root netem # iptb stop
done
