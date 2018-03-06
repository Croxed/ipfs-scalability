#! /usr/bin/env bash
HOST=$1
IPFS_HASH=$2
IPFS_FILE_SIZE=$3
IPFS_FILE=$4
nodes=$5
ITERATIONS=$6
KBITSPEED=1048576 # 1Gbit in Kbit

export IPFS_PATH="$HOME/testbed/$HOST"
for (( i = 0; i < "$ITERATIONS"; i++ )); do
    start_time="$(date +%s%3N | sed 's/N$//')"
    trickle -s -u "$KBITSPEED" -d "$KBITSPEED" ipfs get "$IPFS_HASH" -a -o /dev/null > /dev/null
    end_time="$(date +%s%3N | sed 's/N$//')"
    milli_time="$(($end_time - $start_time))"
    time_secs=$(echo "scale=2;${milli_time}/1000" | bc)
    echo "$time_secs,$IPFS_FILE_SIZE,$IPFS_FILE,$nodes" 
    ipfs repo gc &> /dev/null
done
unset IPFS_PATH
