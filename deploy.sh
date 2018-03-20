#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DEV=lo
DELAY=50ms
KBITSPEED=10240 # 100Mbit in Kbit
NODE=64

echo "" > "$DIR/clients.txt"

tc qdisc del dev "$DEV" root netem
rm -rf "$DIR/ipfs_*"
APIPORT=5001
APILIST=()
pids=()
for (( i = 0; i < NODE; i++ )); do
    rm -rf "$DIR/ipfs_$i"
    mkdir -p "$DIR/ipfs_$i"
    export IPFS_PATH="$DIR/ipfs_$i"
    ipfs init -e --profile test &> /dev/null &
    pids+=($!)
    ipfs bootstrap rm all &> /dev/null &
    APILIST+=( $((APIPORT + i)) )
    unset IPFS_PATH
done
wait "${pids[@]}"
for (( i = 0; i < NODE; i++ )); do
    export IPFS_PATH="$DIR/ipfs_$i"
    ipfs config Addresses.API /ip4/0.0.0.0/tcp/"$((APIPORT + i))"
    APILIST+=( $((APIPORT + i)) )
    trickle -s -u "$KBITSPEED" -d "$KBITSPEED" ipfs daemon > "$IPFS_PATH/daemon.stdout" 2> "$IPFS_PATH/daemon.stderr" &
    echo $! > "$IPFS_PATH/daemon.pid"
    echo "Starting node $i"
    unset IPFS_PATH
done
STARTED=0
while(STARTED > NODE); do
    STARTED=0
    for requsts in "${APILIST[@]}"; do
        if curl -s "http://localhost:$requsts"; then
            ((STARTED++))
        fi
    done
    sleep 1
done
echo "Done starting daemons"
NODE_0_ADDR="$(curl -s http://localhost:5001/api/v0/id?format=\<id\> | jq '.Addresses[0]' | cut -d "\"" -f 2)"
echo "${NODE_0_ADDR}"

for (( i = 0; i < NODE; i++ )); do
    API="http://localhost:$((APIPORT + i))/api/v0"
    curl -sSn "$API/bootstrap/add?arg=${NODE_0_ADDR}" &> /dev/null
    curl -sSn "$API/swarm/connect?arg=${NODE_0_ADDR}" &> /dev/null
    ADDR="$(curl -s $API/id?format=\<id\> | jq '.Addresses[1]' | cut -d "\"" -f 2)"
    echo "$ADDR" >> "$DIR/clients.txt"

done
echo "Done bootstrapping $((NODE)) nodes.."

tc qdisc add dev "$DEV" root netem delay "$DELAY" 20ms distribution normal

array=()
while IFS=  read -r -d $'\0'; do
    array+=("$REPLY")
done < <(find . -name "*.pid" -exec cat {} \;)
watch -n1 -p "${array[*]// /,}" -o comm,%cpu,%mem
