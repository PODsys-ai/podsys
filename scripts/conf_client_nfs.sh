#!/bin/bash
cd $(dirname "$0")

# Fix nfs-common not starting properly
rm /lib/systemd/system/nfs-common.service >/dev/null 2>&1
systemctl daemon-reload
systemctl start nfs-common

if systemctl is-active nfs-common | grep "active" >/dev/null; then
    echo "nfs-common active"
else
    echo "nfs-common dead"
fi

# $1 represents the ip of nfs server
# $2 represents the directory shared by nfs server
# $3 represents the nfs client mounted to the local directory
IP=$1
server_directory=$2
client_directory=$3
if [ -z "$IP" ]; then
    echo "Please input nfs_server's IP."
fi
if [ ! -d "$client_directory" ]; then
    mkdir -p $client_directory
fi
chmod 755 "$client_directory"
mount $IP:$server_directory $client_directory
