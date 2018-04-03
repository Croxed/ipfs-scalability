
    echo "Trying to find API port for node $i"
    while true; do
        if grep "API" "$IPFS_PATH/daemon.stdout"; then
            node_port="$(grep "API" "$IPFS_PATH/daemon.stdout" | awk '{split($5,a,"/"); print a[5] }')"
            echo "Found API poty for node $i..."
            APILIST+=( "$node_port" )
            break
        fi
        sleep 1
    done
	printf "http://%s:%s\n" "$MYIP" "$node_port" >>"$DIR/client.txt"
