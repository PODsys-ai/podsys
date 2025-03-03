#!/bin/bash
cd $(dirname $0)

G_SERVER_IP="$1"
G_DOWNLOAD_MODE="$2"

setup_nfs() {
    wget http://${G_SERVER_IP}:5000/workspace/nfs.tgz
    tar -xzf nfs.tgz
    dpkg -i nfs/*.deb || true
    rm /lib/systemd/system/nfs-common.service || true
    systemctl daemon-reload || true
    systemctl start nfs-common || true
    mkdir -p /target/podsys
    mount -t nfs -o vers=3 ${G_SERVER_IP}:/home/nexus/podsys/workspace /target/podsys || true
}

setup_nfs

if [ "$G_DOWNLOAD_MODE" == "p2p" ]; then

    nohup ctorrent -s /tmp /target/podsys/torrents/drivers.torrent > /tmp/ctorrent.log 2>&1 &
    ctorrent_pid=$!
    while true; do
        if tail -n 20 /tmp/ctorrent.log | grep -q "Download complete"; then
            curl -X POST  "http://${G_SERVER_IP}:5000/receive_p2p_status"
            break
        fi
        sleep 10
    done
    sleep 10
    tar -xzf /tmp/common.tgz -C /target/
    tar -xzf /tmp/ib.tgz -C /target/
    tar -xzf /tmp/nvidia.tgz -C /target/
    cp /tmp/cuda_12.2.2_535.104.05_linux.run /target/cuda_12.2.2_535.104.05_linux.run
fi