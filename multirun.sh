#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

HOST="http://localhost:8080/ipfs"
IPFS_HASH="QmUtyrtpwXy7fq6pu6rFQijNcmZaY6XeR2n3oThu2XjBEQ"
STATS_FILE="stats.csv"
head -n 1 "$DIR/template" > "$DIR/$STATS_FILE"
touch $STATS_FILE
sed -i "1s/.*/time,size,file,nodes,clients/" "$STATS_FILE"

DEV=lo
DELAY=50ms
SPEED="125M"    # Limit network speed for cURL
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
    # iptb start --wait
    for (( i = 0; i < node + client; i++ )); do
        export IPFS_PATH="$HOME/testbed/$i"
        ipfs config Addresses.API /ip4/0.0.0.0/tcp/"$((APIPORT + i))"
        trickle -s -u "$KBITSPEED" -d "$KBITSPEED" ipfs daemon > "$IPFS_PATH/daemon.stdout" 2> "$IPFS_PATH/daemon.stderr" &
        echo $! > "$IPFS_PATH/daemon.pid"
        unset IPFS_PATH
    done
    STARTED="$(find $HOME/testbed/ -maxdepth 2 -type f -name "daemon.stdout" -print0 | xargs -0 awk '/Daemon is ready/{print $5}' | wc -l)"
    while((STARTED > (node + client))); do
        STARTED="$(find $HOME/testbed/ -maxdepth 2 -type f -name "daemon.stdout" -print0 | xargs -0 awk '/Daemon is ready/{print $5}' | wc -l)"
        sleep 2
    done
    echo "Done starting daemons"
    export IPFS_PATH="$HOME/testbed/0"
    NODE_0_ADDR="$(ipfs id -f \"\<addrs\>\" | head -n 1 | cut -c 2-)"
    unset IPFS_PATH
    echo "${NODE_0_ADDR}"

    for (( i = 1; i < node + client; i++ )); do
        API="http://localhost:$((APIPORT + i))/api/v0"
        curl -sSn "$API/bootstrap/add?arg=${NODE_0_ADDR}"
        curl -sSn "$API/swarm/connect?arg=${NODE_0_ADDR}"
    done

    pids=()
    replicas="$(shuf -n${client}-$((node + client)) -n$((node / client)))"
    it=$(((node - 1) % 6))
    echo "$replicas"
    for replica in "${replicas[@]}"; do
        export IPFS_PATH="$HOME/testbed/$replica"
        files=$(find $DIR/files/go-ipfs-0.4.13/* -maxdepth 0 | head -n $((8 * it)))
        for file in "${files[@]}"; do
            ipfs add -r "$file" &> /dev/null &
            pids+=($!)
        done
        ((it++))
        echo "Node: $(ipfs id -f \"\<id\>\") is adding files"
        unset IPFS_PATH
    done
    export IPFS_PATH="$HOME/testbed/$((node -1))"
    ipfs add -r "$DIR/files/go-ipfs-0.4.13" &> /dev/null &
    pids+=($!)
    echo "Node: $(ipfs id -f \"\<id\>\") is adding files"
    unset IPFS_PATH
    wait "${pids[@]}"

    echo "Done adding files"

    tc qdisc add dev "$DEV" root netem delay "$DELAY" 20ms distribution normal

    export IPFS_PATH="$HOME/testbed/0"
    IPFS_FILE="$(find $DIR/files/* -maxdepth 0 -type d -exec basename {} \;)"
    IPFS_FILE_SIZE="$(ipfs files stat "/ipfs/$IPFS_HASH" | awk 'FNR == 2 { print $2 }')"
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
    unset IPFS_PATH
    pkill ipfs
    pkill trickle
    pkill trickled
    tc qdisc del dev "$DEV" root netem # iptb stop
done
