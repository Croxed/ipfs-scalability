#! /usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEV=lo
DEV1=enp1s0
# KBITSPEED=12800 # 100Mbit in Kbit
KBITSPEED=125000
eval NODE="$2"
MYIP="$(ip add | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.*')"
rm -rf "$DIR/clients.txt"
printf "Running... %s \n" "$(date)" >"$DIR/running.txt"

printf "client\n" >"$DIR/client.txt"

kill -9 "$(cat "$DIR/deploy.pid")" &> /dev/null
echo $$ >"$DIR/deploy.pid"

# ipfs_pids="$(find $DIR -mindepth 2 -maxdepth 2 -type f -name "*.pid")"

# readarray -t ipfs_nodes < <(find $DIR -mindepth 2 -maxdepth 2 -type f -name "*.pid" -exec cat {} \;)

# for ipfs_node in "${ipfs_nodes[@]}"; do
# 	kill -9 "$ipfs_node" &>/dev/null
# done

tc qdisc del dev "$DEV" root netem
tc qdisc del dev "$DEV1" root netem
rm -rf "$DIR/ipfs_*"
APILIST=()
pids=()
for ((i = 0; i < NODE; i++)); do
    echo "$DIR/ipfs_$i"
    rm -rf "$DIR/ipfs_$i"
    mkdir -p "$DIR/ipfs_$i"
    export IPFS_PATH="$DIR/ipfs_$i"
    ipfs init -e --profile test &>/dev/null &
    pids+=($!)
    ipfs bootstrap rm all &>/dev/null &
    unset IPFS_PATH
done
wait "${pids[@]}"
for ((i = 0; i < NODE; i++)); do
    export IPFS_PATH="$DIR/ipfs_$i"
    ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin "[\"*\"]"
    ipfs config --json API.HTTPHeaders.Access-Control-Allow-Credentials "[\"true\"]"
    ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods "[\"PUT\", \"POST\", \"GET\"]"
    ipfs config Addresses.API /ip4/0.0.0.0/tcp/0
    trickle -s -u "$KBITSPEED" -d "$KBITSPEED" ipfs daemon >"$IPFS_PATH/daemon.stdout" 2>"$IPFS_PATH/daemon.stderr" &
    echo $! >"$IPFS_PATH/daemon.pid"
    echo "Trying to find API port for node $i"
    while true; do
        if grep "API" "$IPFS_PATH/daemon.stdout" &> /dev/null; then
            node_port="$(grep "API" "$IPFS_PATH/daemon.stdout" | awk '{split($5,a,"/"); print a[5] }')"
            echo "Found API port for node $i..."
            APILIST+=( "$node_port" )
            break
        fi
        sleep 1
    done
    printf "http://%s:%s\n" "$MYIP" "$node_port" >>"$DIR/client.txt"
    echo "Starting node $i"
    unset IPFS_PATH
done

# STARTED=0
# while ((STARTED < NODE)); do
# 	STARTED=0
# 	for requsts in "${APILIST[@]}"; do
# 		if ! curl -fs "http://localhost:$requsts"; then
# 			((STARTED++))
# 		fi
# 	done
# 	sleep 1
# done
echo "Done starting daemons"
NODE_0_ADDR=$1
# NODE_0_ADDR="$(curl -s http://localhost:5001/api/v0/id?format=\<id\> | jq '.Addresses[0]' | cut -d "\"" -f 2)"
echo "${NODE_0_ADDR}"

for api_port in "${APILIST[@]}"; do
    API="http://localhost:$api_port/api/v0"
    curl -sSn "$API/bootstrap/add?arg=${NODE_0_ADDR}" &>/dev/null
    curl -sSn "$API/swarm/connect?arg=${NODE_0_ADDR}" &>/dev/null
done
echo "Done bootstrapping $((NODE)) nodes.."

mv "$DIR/client.txt" "$DIR/clients.txt"

while : ; do
    for api_port in "${APILIST[@]}"; do
        API="http://localhost:$api_port/api/v0"
        stats="$(curl -sSn "$API/swarm/connect?arg=${NODE_0_ADDR}" &>/dev/null)"
        echo "$api_port : $stats" >> "$DIR/stats_bw.log"
    done
done
cat
