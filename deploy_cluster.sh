#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DEV=lo
DEV1=enp1s0
DELAY=50ms
KBITSPEED=10240 # 100Mbit in Kbit
eval NODE="$2"
MYIP="$(ip add | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.*')"
rm -rf "$DIR/clients.txt"
printf "Running... %s \n" "$(date)" > "$DIR/running.txt"

printf "" > "$DIR/client.txt"

pkill ipfs
pkill ipfs

tc qdisc del dev "$DEV" root netem
tc qdisc del dev "$DEV1" root netem
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
    printf "http://%s:%s\n" "$MYIP" "$((APIPORT + i))" >> "$DIR/client.txt"
    echo "Starting node $i"
    unset IPFS_PATH
done


STARTED=0
while((STARTED < NODE)); do
    STARTED=0
    for requsts in "${APILIST[@]}"; do
        if ! curl -fs "http://localhost:$requsts"; then
            ((STARTED++))
        fi
    done
    sleep 1
done
echo "Done starting daemons"
NODE_0_ADDR=$1
# NODE_0_ADDR="$(curl -s http://localhost:5001/api/v0/id?format=\<id\> | jq '.Addresses[0]' | cut -d "\"" -f 2)"
echo "${NODE_0_ADDR}"

for (( i = 0; i < NODE; i++ )); do
    API="http://localhost:$((APIPORT + i))/api/v0"
    curl -sSn "$API/bootstrap/add?arg=${NODE_0_ADDR}" &> /dev/null
    curl -sSn "$API/swarm/connect?arg=${NODE_0_ADDR}" &> /dev/null
done
echo "Done bootstrapping $((NODE)) nodes.."

mv "$DIR/client.txt" "$DIR/clients.txt"
tc qdisc add dev "$DEV" root netem delay "$DELAY" 20ms distribution normal
tc qdisc add dev "$DEV1" root netem delay "$DELAY" 20ms distribution normal

cat
