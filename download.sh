#! /usr/bin/env bash
HOST=$1
IPFS_HASH=$2
IPFS_FILE_SIZE=$3
IPFS_FILE=$4
node=$5
SPEED="125M"

curl_data="$(curl --limit-rate $SPEED -sSn "$HOST/$IPFS_HASH" -o /dev/null -w "%{time_total}")"
echo "$curl_data,$IPFS_FILE_SIZE,$IPFS_FILE,$node"
ipfs repo gc &> /dev/null