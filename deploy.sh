#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DEV=lo
DEV1=enp1s0
DELAY=50ms
KBITSPEED=10240 # 100Mbit in Kbit
CLIENTS=1
NODES=32
MYIP="$(ip add | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.*')"

tc qdisc del dev "$DEV" root netem
tc qdisc del dev "$DEV1" root netem
rm -rf "$DIR/ipfs_*"
APIPORT=5001
APILIST=()
pids=()
rm -rf "$DIR/ipfs_0"
mkdir -p "$DIR/ipfs_0"
export IPFS_PATH="$DIR/ipfs_0"
ipfs init -e --profile test &> /dev/null &
pids+=($!)
ipfs bootstrap rm all &> /dev/null &
APILIST+=( $((APIPORT + i)) )
unset IPFS_PATH
wait "${pids[@]}"

export IPFS_PATH="$DIR/ipfs_0"
ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
ipfs config Datastore.StorageMax 0GB
ipfs config --json Datastore.StorageGCWatermark 0
ipfs config Datastore.GCPeriod 0h
ipfs config Addresses.API /ip4/0.0.0.0/tcp/"$((APIPORT + i))"
APILIST+=( $((APIPORT + i)) )
sed -i 's/127.0.0.1/0.0.0.0/g' "$IPFS_PATH/config"
trickle -s -u "$KBITSPEED" -d "$KBITSPEED" ipfs daemon --enable-gc=true > "$IPFS_PATH/daemon.stdout" 2> "$IPFS_PATH/daemon.stderr" &
echo $! > "$IPFS_PATH/daemon.pid"
echo "Starting node $i"
unset IPFS_PATH

STARTED=0
while((STARTED < CLIENTS)); do
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
export IPFS_PATH="$DIR/ipfs_0"

if [ ! -f "$DIR/files/v0.4.13.tar.gz" ]; then
    wget "https://github.com/ipfs/go-ipfs/archive/v0.4.13.tar.gz" -O "$DIR/files/v0.4.13.tar.gz"
fi

rm -rf "$DIR/files/go-ipfs-0.4.13"
tar -xf "$DIR/files/v0.4.13.tar.gz" -C "$DIR/files/"

IPFS_HASH="$(ipfs add -nr "$DIR/files/go-ipfs-0.4.13" | tail -n 1 | awk '{print $2}')"
unset IPFS_PATH

for (( i = 0; i < CLIENTS; i++ )); do
    API="http://localhost:$((APIPORT + i))/api/v0"
    curl -sSn "$API/bootstrap/add?arg=${NODE_0_ADDR}" &> /dev/null
    curl -sSn "$API/swarm/connect?arg=${NODE_0_ADDR}" &> /dev/null
done
echo "Done bootstrapping $((CLIENTS)) clients.."
NODE_0_ADDR="$(curl -s http://localhost:5001/api/v0/id?format=\<id\> | jq '.Addresses[0]' | cut -d "\"" -f 2 | sed "s/127.0.0.1/${MYIP}/")"
IFS=' ' read -r -a array <<< "$@"
for cluster in "${array[@]}" ; do
    ssh -n -f root@"$cluster" bash -c "'(cd /root/ipfs-scalability; nohup bash /root/ipfs-scalability/deploy_cluster.sh $NODE_0_ADDR $NODES > /root/ipfs-scalability/daemon.out 2>&1) &'"
done
tc qdisc add dev "$DEV" root netem delay "$DELAY" 20ms distribution normal
tc qdisc add dev "$DEV1" root netem delay "$DELAY" 20ms distribution normal
sleep 2
for cluster in "${array[@]}" ; do
    while true; do
        rm -rf "$DIR/clients_$cluster.txt"
        if scp root@"$cluster:/root/ipfs-scalability/clients.txt" "$DIR/clients_$cluster.txt" &> /dev/null; then
            break;
        fi
        sleep 3
    done
done


inFiles=(clients_*.txt)

readarray -t myarray < <(cat "${inFiles[@]}")

declare -a replicas
readarray -t replicas < <(shuf -i0-$((${#myarray[@]} - 1)) -n$((${#myarray[@]} / 8)))
for replica in "${replicas[@]}"; do
	API="http://localhost:$((APIPORT + replica))/api/v0"
	curl --connect-timeout 20 --mat-time 10 -s -F file="$DIR/files/go-ipfs-0.4.13" "$API/add?recursive=true" &> /dev/null
	echo "Node: $(curl "$API/id?format=\<id\>" | jq '.ID') is adding files"
done

for (( i = 0; i < CLIENTS; i++)); do
    IPFS_PATH="$DIR/ipfs_$i"
    echo "python3 $DIR/node_download.py $IPFS_PATH $IPFS_HASH 1000 $((NODES * 3))"
    python3 "$DIR/node_download.py" "$IPFS_PATH" "$IPFS_HASH" 1000 $((NODES * 3)) 
done
