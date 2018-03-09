#! /usr/bin/env bash
HOST=$1
IPFS_HASH=$2
IPFS_FILE_SIZE=$3
IPFS_FILE=$4
node=$5
ITERATIONS=$6
# API=$7
CLIENTS=$7
SPEED="12M"
TIME=10

for (( i = 0; i < "$ITERATIONS"; i++ )); do
    curl_data="$(curl --connect-timeout 2.37 -m 5 --limit-rate $SPEED -sSn "$HOST/$IPFS_HASH" -o /dev/null -w "%{time_total}")"
    echo "$curl_data,$IPFS_FILE_SIZE,$IPFS_FILE,$node,$CLIENTS"
    # curl -sSn "$API/repo/gc" &> /dev/null
done
