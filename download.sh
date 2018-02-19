#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

HOST="http://localhost:8080/ipfs"
IPFS_HASH="QmVQzYSyg8UKESocmMjdzj1XofJDGHg59iK3QtRviL6pvo"
STATS_FILE="stats.csv"
touch $STATS_FILE
sed -i "1s/.*/time,size,speed,file,nodes/" "$STATS_FILE"

SPEED="125M"    # Limit network speed for cURL
NODES="$(jq '. | length' ~/testbed/nodespec)"
IPFS_FILE="song.mp3"
ITERATIONS=40
for (( i = 0; i < "$ITERATIONS"; i++ )); do
    curl --limit-rate "$SPEED" -sSn "$HOST/$IPFS_HASH/$IPFS_FILE" -o /dev/null -w "%{time_total},%{size_download},%{speed_download}," >> $STATS_FILE
    echo "$IPFS_FILE,$NODES" >> $STATS_FILE
done

ITERATIONS=15
IPFS_FILE="film.mp4"
for (( i = 0; i < "$ITERATIONS"; i++ )); do
    curl --limit-rate "$SPEED" -sSn "$HOST/$IPFS_HASH/$IPFS_FILE" -o /dev/null -w "%{time_total},%{size_download},%{speed_download}," >> $STATS_FILE
    echo "$IPFS_FILE,$NODES" >> $STATS_FILE
done
