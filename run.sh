#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

HOST="http://localhost:8080/ipfs"
IPFS_HASH="QmVQzYSyg8UKESocmMjdzj1XofJDGHg59iK3QtRviL6pvo"
STATS_FILE="stats.csv"
touch $STATS_FILE
sed -i "1s/.*/time,size,speed,file,nodes/" "$STATS_FILE"

SPEED="125M"    # Limit network speed for cURL
NODES=(10 30 50)
for node in "${NODES[@]}"; do
    iptb init -n "$node" --bootstrap=star -f
    # sed -e 's/"Gateway": ""/"Gateway": "\/ip4\/0.0.0.0\/tcp\/8080"/g' ~/testbed/0/config
    iptb start --wait
    iptb run 0 ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080;
    NODE_0_ADDR="$(iptb run 0 ipfs id -f \"\<addrs\>\" | head -n 1 | cut -c 2-)"
    echo "${NODE_0_ADDR}"
    for (( i = 1; i < "$node" - 1; i++ )); do
        iptb run "$i" ipfs swarm connect "${NODE_0_ADDR}"
    done
    iptb run $(("$node" - 1)) ipfs swarm connect "${NODE_0_ADDR}"; ipfs add -r ~/performace_experiment/files

    IPFS_FILE="song.mp3"
    ITERATIONS=40
    for (( i = 0; i < "$ITERATIONS"; i++ )); do
        curl --limit-rate "$SPEED" -sSn "$HOST/$IPFS_HASH/$IPFS_FILE" -o /dev/null -w "%{time_total},%{size_download},%{speed_download}," >> $STATS_FILE
        echo "$IPFS_FILE,$node" >> $STATS_FILE
    done

    # ITERATIONS=15
    # IPFS_FILE="film.mp4"
    # for (( i = 0; i < "$ITERATIONS"; i++ )); do
    #     curl --limit-rate "$SPEED" -sSn "$HOST/$IPFS_HASH/$IPFS_FILE" -o /dev/null -w "%{time_total},%{size_download},%{speed_download}," >> $STATS_FILE
    #     echo "$IPFS_FILE,$node" >> $STATS_FILE
    # done

    iptb stop
done
