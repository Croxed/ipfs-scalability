#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DEV=lo
DEV1=enp1s0
DELAY=50ms
KBITSPEED=10240 # 100Mbit in Kbit
NODE=64

printf "" > "$DIR/clients.txt"

tc qdisc del dev "$DEV" root netem
tc qdisc del dev "$DEV1" root netem
rm -rf "$DIR/ipfs_*"
APIPORT=5001
APILIST=()
pids=()
for (( i = 0; i < NODE + 1; i++ )); do
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
for (( i = 0; i < NODE + 1; i++ )); do
    export IPFS_PATH="$DIR/ipfs_$i"
    if [[ "$i" -eq 0 ]]; then
        ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
        ipfs config Datastore.StorageMax 0GB
        ipfs config --json Datastore.StorageGCWatermark 0
        ipfs config Datastore.GCPeriod 0h
        ipfs config Addresses.API /ip4/0.0.0.0/tcp/"$((APIPORT + i))"
        APILIST+=( $((APIPORT + i)) )
        trickle -s -u "$KBITSPEED" -d "$KBITSPEED" ipfs daemon --enable-gc=true > "$IPFS_PATH/daemon.stdout" 2> "$IPFS_PATH/daemon.stderr" &
        echo $! > "$IPFS_PATH/daemon.pid"
        echo "Starting node $i"
    else
        ipfs config Addresses.API /ip4/0.0.0.0/tcp/"$((APIPORT + i))"
        APILIST+=( $((APIPORT + i)) )
        trickle -s -u "$KBITSPEED" -d "$KBITSPEED" ipfs daemon > "$IPFS_PATH/daemon.stdout" 2> "$IPFS_PATH/daemon.stderr" &
        echo $! > "$IPFS_PATH/daemon.pid"
        echo "Starting node $i"
    fi
    unset IPFS_PATH
done
STARTED=0
while((STARTED < NODE + 1)); do
    STARTED=0
    for requsts in "${APILIST[@]}"; do
        if ! curl -fs "http://localhost:$requsts"; then
            ((STARTED++))
        fi
    done
    sleep 1
done
echo "Done starting daemons"
NODE_0_ADDR="$(curl -s http://localhost:5001/api/v0/id?format=\<id\> | jq '.Addresses[0]' | cut -d "\"" -f 2)"
echo "${NODE_0_ADDR}" > node0.txt

MYIP="$(ip add | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.*')"
for (( i = 0; i < NODE + 1; i++ )); do
    API="http://localhost:$((APIPORT + i))/api/v0"
    curl -sSn "$API/bootstrap/add?arg=${NODE_0_ADDR}" &> /dev/null
    curl -sSn "$API/swarm/connect?arg=${NODE_0_ADDR}" &> /dev/null
    # ADDR="$(curl -s $API/id?format=\<id\> | jq '.Addresses[1]' | cut -d "\"" -f 2)"
    echo "$API" >> "$DIR/clients.txt"

done
echo "Done bootstrapping $((NODE)) nodes.."
NODE_0_ADDR="$(curl -s http://localhost:5001/api/v0/id?format=\<id\> | jq '.Addresses[0]' | cut -d "\"" -f 2 | sed "s/127.0.0.1/${MYIP}/")"
IFS=' ' read -r -a array <<< "$@"
for cluster in "${array[@]}" ; do
    ssh root@"$cluster" bash -c "'(cd /root/ipfs-scalability; bash /root/ipfs-scalability/deploy_cluster.sh $NODE_0_ADDR) &'"
done
tc qdisc add dev "$DEV" root netem delay "$DELAY" 20ms distribution normal
tc qdisc add dev "$DEV1" root netem delay "$DELAY" 20ms distribution normal
sleep 2
watch -n1 ps -C ipfs -o cmd,%cpu,%mem
cat
