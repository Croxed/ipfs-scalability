#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

HOST="http://localhost:8080/ipfs"
# IPFS_HASH="QmVQzYSyg8UKESocmMjdzj1XofJDGHg59iK3QtRviL6pvo"
IPFS_HASH="QmUtyrtpwXy7fq6pu6rFQijNcmZaY6XeR2n3oThu2XjBEQ"
STATS_FILE="stats.csv"
touch $STATS_FILE
sed -i "1s/.*/time,size,file,nodes/" "$STATS_FILE"

ITERATIONS=300
SPEED="125M"    # Limit network speed for cURL
KBITSPEED=1048576 # 1Gbit in Kbit
NODES=(10)
for node in "${NODES[@]}"; do
    Comcast --stop
    
    iptb init -n "$node" --bootstrap none -f
    trickled 
    # iptb start --wait
    for (( i = 0; i < "$node"; i++ )); do
        export IPFS_PATH="$HOME/testbed/$i"
        trickle -u "$KBITSPEED" -d "$KBITSPEED" ipfs daemon > "$IPFS_PATH/daemon.stdout" 2> "$IPFS_PATH/daemon.stderr" &
        echo $! > "$IPFS_PATH/daemon.pid"
        unset IPFS_PATH
    done
    
    sleep 10
    export IPFS_PATH="$HOME/testbed/0"
    NODE_0_ADDR="$(ipfs id -f \"\<addrs\>\" | head -n 1 | cut -c 2-)"
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
    
    for (( i = 1; i < $node -1; i++ )); do
        export IPFS_PATH="$HOME/testbed/$i"
        ipfs pin add -r "/ipfs/$IPFS_HASH" &> /dev/null
        unset IPFS_PATH
    done

    Comcast --device=lo --latency=50
    
    export IPFS_PATH="$HOME/testbed/0"
    IPFS_FILE="$(find "$DIR" -maxdepth 0 -type d)"
    rm -rf "$DIR/downloaded"
    IPFS_FILE_SIZE="$(ipfs files stat "/ipfs/$IPFS_HASH" | awk 'FNR == 2 { print $2 }')"
    for (( i = 0; i < "$ITERATIONS"; i++ )); do
        start_time="$(date +%s%3N | sed 's/N$//')"
        ipfs get "$IPFS_HASH" -o "$DIR/downloaded"
        end_time="$(date +%s%3N | sed 's/N$//')"
        milli_time="$(($end_time - $start_time))"
        time_secs=$(echo "scale=2;${milli_time}/1000" | bc)
        echo "$time_secs,$IPFS_FILE_SIZE,$IPFS_FILE,$node" >> $STATS_FILE
        ipfs repo gc &> /dev/null
        rm -rf "$DIR/downloaded"
    done

    unset IPFS_PATH
    pkill ipfs
    pkill trickle
    pkill trickled
    Comcast --stop
    # iptb stop
done
