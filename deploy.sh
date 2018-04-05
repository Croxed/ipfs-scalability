#! /usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STATS_FILE="stats.csv"
head -n 1 "$DIR/template" >"$DIR/$STATS_FILE"
# touch $STATS_FILE
# sed -i "1s/.*/time,size,file,nodes,clients/" "$STATS_FILE"

DEV=lo
DEV1=enp1s0
# KBITSPEED=12800 # 100Mbit in Kbit
KBITSPEED=125000
CLIENTS=1
# NODES=32
CLUSTER_NODES=(16 32 64)
MYIP="$(ip add | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.*')"
tc qdisc del dev "$DEV" root netem
tc qdisc del dev "$DEV1" root netem
umount /ipfs
umount /ipns
rm -rf "$DIR/deploy/ipfs*"
APIPORT=5001
APILIST=()
pids=()
rm -rf "$DIR/deploy/ipfs0"
mkdir -p "$DIR/deploy/ipfs0"
export IPFS_PATH="$DIR/deploy/ipfs0"
ipfs init -e --profile test &>/dev/null &
pids+=($!)
ipfs bootstrap rm all &>/dev/null &
unset IPFS_PATH
wait "${pids[@]}"

export IPFS_PATH="$DIR/deploy/ipfs0"
ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
ipfs config Datastore.StorageMax 0GB
ipfs config --json Datastore.StorageGCWatermark 0
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin "[\"*\"]"
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods "[\"PUT\", \"POST\", \"GET\"]"
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Credentials "[\"true\"]"
ipfs config Datastore.GCPeriod 0h
ipfs config Addresses.API /ip4/0.0.0.0/tcp/"$APIPORT"
APILIST+=("$APIPORT")
sed -i 's/127.0.0.1/0.0.0.0/g' "$IPFS_PATH/config"
trickle -s -u "$KBITSPEED" -d "$KBITSPEED" ipfs daemon --enable-gc=true >"$IPFS_PATH/daemon.stdout" 2>"$IPFS_PATH/daemon.stderr" &
echo $! >"$IPFS_PATH/daemon.pid"
echo "Starting gateway node"
unset IPFS_PATH

STARTED=0
while ((STARTED < CLIENTS)); do
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

API="http://localhost:$APIPORT/api/v0"
curl -sSn "$API/bootstrap/add?arg=${NODE_0_ADDR}" &>/dev/null
curl -sSn "$API/swarm/connect?arg=${NODE_0_ADDR}" &>/dev/null
echo "Done bootstrapping $((CLIENTS)) clients.."
NODE_0_ADDR="$(curl -s http://localhost:5001/api/v0/id?format=\<id\> | jq '.Addresses[0]' | cut -d "\"" -f 2 | sed "s/127.0.0.1/${MYIP}/")"
IFS=' ' read -r -a array <<<"$@"
for NODES in "${CLUSTER_NODES[@]}"; do
    export IPFS_PATH="$DIR/deploy/ipfs0"
    readarray -t client_nodes < <(ipfs swarm peers)
    for client_node in "${client_nodes[@]}"; do
        ipfs swarm disconnect "$client_node" &> /dev/null
    done
    unset IPFS_PATH
    rm -rf "$DIR/clients_*"
    for cluster in "${array[@]}"; do
        ssh -n -f root@"$cluster" bash -c "'(cd /root/ipfs-scalability; nohup bash /root/ipfs-scalability/deploy_cluster.sh $NODE_0_ADDR $NODES > /root/ipfs-scalability/daemon.out 2>&1 & echo $! > /root/ipfs-scalability/daemon.pid) &'"
    done
    sleep 2
    for cluster in "${array[@]}"; do
        while true; do
            rm -rf "$DIR/clients_$cluster.txt"
            if scp root@"$cluster:/root/ipfs-scalability/clients.txt" "$DIR/clients_$cluster.txt" &>/dev/null; then
                break
            fi
            sleep 3
        done
    done

    IPFS_FILE="$(find $DIR/files/* -maxdepth 0 -type d -exec basename {} \;)"
    IPFS_FILE_SIZE="$(du -sh "$DIR/files/go-ipfs-0.4.13" | awk '{ print $1 }')"
    ITERATIONS=1000
    pids=()
    echo "python3 "$DIR/node_download.py" $((${#array[@]} * NODES)) $ITERATIONS $IPFS_FILE $IPFS_FILE_SIZE"
    python3 "$DIR/node_download.py" "$((${#array[@]} * NODES))" "$ITERATIONS" "$IPFS_FILE" "$IPFS_FILE_SIZE"
done
