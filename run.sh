#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

HOST="http://localhost:8080/ipfs"
IPFS_HASH="QmUtyrtpwXy7fq6pu6rFQijNcmZaY6XeR2n3oThu2XjBEQ"
STATS_FILE="stats.csv"
touch $STATS_FILE
sed -i "1s/.*/time,size,file,nodes/" "$STATS_FILE"

DEV=lo
DELAY=50ms
ITERATIONS=300
SPEED="125M"    # Limit network speed for cURL
KBITSPEED=1048576 # 1Gbit in Kbit
NODES=(10 20 30)
tc qdisc del dev "$DEV" root netem
for node in "${NODES[@]}"; do
    
    iptb init -n "$node" --bootstrap none -f
    trickled 
    export IPFS_PATH="$HOME/testbed/0"
    ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
    unset IPFS_PATH
    # iptb start --wait
    for (( i = 0; i < "$node"; i++ )); do
        export IPFS_PATH="$HOME/testbed/$i"
        trickle -s -u "$KBITSPEED" -d "$KBITSPEED" ipfs daemon > "$IPFS_PATH/daemon.stdout" 2> "$IPFS_PATH/daemon.stderr" &
        echo $! > "$IPFS_PATH/daemon.pid"
        unset IPFS_PATH
    done
    
    sleep 10
    export IPFS_PATH="$HOME/testbed/0"
    NODE_0_ADDR="$(ipfs id -f \"\<addrs\>\" | head -n 1 | cut -c 2-)"
    ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
    ipfs config Datastore.StorageMax 0GB
    ipfs config Datastore.GCPeriod 0h
    unset IPFS_PATH
    echo "${NODE_0_ADDR}"
   
    for (( i = 1; i < "$node"; i++ )); do
        export IPFS_PATH="$HOME/testbed/$i"
        ipfs bootstrap add "${NODE_0_ADDR}"
        ipfs swarm connect "${NODE_0_ADDR}"
        unset IPFS_PATH
    done
    
    pids=()
    it=$(((node - 1) % 6))
    for (( i = 1; i < 9; i++ )); do
        export IPFS_PATH="$HOME/testbed/$i"
        files=$(find "$DIR/files/go-ipfs-0.4.13/*" -maxdepth 0 | head -n $((8 * i)))
        for file in "${files[@]}"; do
            ipfs add -r "$file" &> /dev/null &
            pids+=($!)
        done
        echo "Node: $(ipfs id -f \"\<id\>\") is adding files"
        unset IPFS_PATH
    done
    wait "${pids[@]}"

    echo "Done adding files"

    tc qdisc add dev "$DEV" root netem delay "$DELAY" 20ms distribution normal
    
    export IPFS_PATH="$HOME/testbed/0"
    IPFS_FILE="$(find $DIR/files/* -maxdepth 0 -type d -exec basename {} \;)"
    rm -rf "$DIR/downloaded"
    IPFS_FILE_SIZE="$(ipfs files stat "/ipfs/$IPFS_HASH" | awk 'FNR == 2 { print $2 }')"
    for (( i = 0; i < "$ITERATIONS"; i++ )); do
        trickle -s -u "$KBITSPEED" -d "$KBITSPEED" curl -sSn "$HOST/$IPFS_HASH" -o /dev/null -w "%{time_total},%{size_download}," >> $STATS_FILE
        echo "$IPFS_FILE,$node" >> $STATS_FILE
        ipfs repo gc &> /dev/null
        rm -rf "$DIR/downloaded"
    done

    unset IPFS_PATH
    pkill ipfs
    pkill trickle
    pkill trickled
    tc qdisc del dev "$DEV" root netem # iptb stop
done
