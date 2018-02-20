#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

HOST="http://localhost:8080/ipfs"
# IPFS_HASH="QmVQzYSyg8UKESocmMjdzj1XofJDGHg59iK3QtRviL6pvo"
IPFS_HASH="QmRQrVc93rq5JCGH4kPnxSBt8HbMbXQrEpkdP1dkiTfC6M"
STATS_FILE="stats.csv"
touch $STATS_FILE
sed -i "1s/.*/time,size,file,nodes/" "$STATS_FILE"

SPEED="125M"    # Limit network speed for cURL
NODES=(10)
for node in "${NODES[@]}"; do
    comcast --stop
    
    iptb init -n "$node" --bootstrap none -f
    
    iptb start
    export IPFS_PATH="$HOME/testbed/0"
    NODE_0_ADDR="$(ipfs id -f \"\<addrs\>\" | head -n 1 | cut -c 2-)"
    unset IPFS_PATH
    echo "${NODE_0_ADDR}"
    
    find ~/testbed/* -maxdepth 0 -type d -exec bash -c "export IPFS_PATH=$1; ipfs bootstrap add ${NODE_0_ADDR}; unset IPFS_PATH" _ {} \;
   
    for (( i = 1; i < "$node"; i++ )); do
        export IPFS_PATH="$HOME/testbed/$i"
        ipfs swarm connect "${NODE_0_ADDR}"
        unset IPFS_PATH
    done
    export IPFS_PATH="$HOME/testbed/$(($node - 1))"
    ipfs add -r "$DIR/files"
    unset IPFS_PATH
    
    comcast --device=lo0 --latency=50 --target-bw=1000000 --packet-loss=2%
    export IPFS_PATH="$HOME/testbed/0"
    IPFS_FILE="song.mp3"
    ITERATIONS=40
    IPFS_FILE_SIZE="$(ipfs files stat /ipfs/QmRQrVc93rq5JCGH4kPnxSBt8HbMbXQrEpkdP1dkiTfC6M/song.mp3 | awk 'FNR == 2 { print $2 }')"
    for (( i = 0; i < "$ITERATIONS"; i++ )); do
        start_time="$(date +%s%3N | sed 's/N$//')"
        ipfs get "$IPFS_HASH/$IPFS_FILE" -o /dev/null
        end_time="$(date +%s%3N | sed 's/N$//')"
        milli_time="$(($end_time - $start_time))"
        time_secs=$(echo "scale=2;${milli_time}/1000" | bc)
        echo "$time_secs,$IPFS_FILE_SIZE,$IPFS_FILE,$node" >> $STATS_FILE
    done

    # ITERATIONS=15
    # IPFS_FILE="film.mp4"
    # for (( i = 0; i < "$ITERATIONS"; i++ )); do
    #     curl --limit-rate "$SPEED" -sSn "$HOST/$IPFS_HASH/$IPFS_FILE" -o /dev/null -w "%{time_total},%{size_download},%{speed_download}," >> $STATS_FILE
    #     echo "$IPFS_FILE,$node" >> $STATS_FILE
    # done
    comcast --stop
    unset IPFS_PATH
    iptb stop
done
python3 "$DIR/graph_builder/grapher.py" "$DIR/stats.csv"
