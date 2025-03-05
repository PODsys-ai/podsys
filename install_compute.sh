#!/bin/bash
cd $(dirname $0)

if [ "$(id -u)" = "0" ]; then
    # configuration nfs-server
    file="/etc/exports"
    text="$(pwd)/workspace *(rw,async,insecure,no_root_squash)"
    if ! grep -qF "$text" "$file"; then
        echo $text >>$file
    fi
    systemctl restart nfs-kernel-server
fi

source scripts/func_podsys.sh
delete_logs
get_rsa nexus
check_iplist_format "workspace/iplist.txt"

if docker ps -a --format '{{.Image}}' | grep -q "ainexus:v3.0"; then
    docker stop $(docker ps -a -q --filter ancestor=ainexus:v3.0) >/dev/null
    docker rm $(docker ps -a -q --filter ancestor=ainexus:v3.0) >/dev/null
    docker rmi ainexus:v3.0 >/dev/null
fi

docker import pkgs/ainexus-arm-3.0 ainexus:v3.0 >/dev/null &
pid=$!
while ps -p $pid >/dev/null; do
    echo -n "*"
    sleep 2
done
echo

# download_mode=http|p2p
download_mode="http"

docker run -e "download_mode=$download_mode" -e "NEW_PUB_KEY=$new_pub_key" --name podsys --privileged=true -it --network=host -v $PWD/workspace:/workspace ainexus:v3.0 /bin/bash

sleep 1
if docker ps -a --format '{{.Image}}' | grep -q "ainexus:v3.0"; then
    docker stop $(docker ps -a -q --filter ancestor=ainexus:v3.0) >/dev/null
    docker rm $(docker ps -a -q --filter ancestor=ainexus:v3.0) >/dev/null
    docker rmi ainexus:v3.0 >/dev/null
fi

if [ "$download_mode" = "nfs" ]; then
    rm -rf $PWD/workspace/common
    rm -rf $PWD/workspace/ib
    rm -rf $PWD/workspace/nvidia
fi

if [ "$(id -u)" = "0" ]; then
    # del configuration nfs-server
    file="/etc/exports"
    text="$(pwd)/workspace *(rw,async,insecure,no_root_squash)"
    if grep -qF "$text" "$file"; then
        sed -i "/$(sed 's/[^^]/[&]/g' <<<"$text")/d" "$file"
    fi
fi