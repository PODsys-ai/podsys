#!/bin/bash
cd $(dirname $0)

G_SERVER_IP="$1"
G_DOWNLOAD_MODE="$2"
CUDA=cuda_12.8.0_570.86.10_linux.run

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

    nohup ctorrent -s /target /target/podsys/torrents/drivers.torrent \
        -X "curl -X POST http://${G_SERVER_IP}:5000/receive_p2p_status && sleep 20 && touch /tmp/complated.flag" \
        >/dev/null 2>&1 &

    ctorrent_pid=$!

    while [ ! -f "/tmp/complated.flag" ]; do
        sleep 10
    done
    tar -xzf /target/common.tgz -C /target/
    tar -xzf /target/ib.tgz -C /target/
    tar -xzf /target/nvidia.tgz -C /target/

elif [ "$G_DOWNLOAD_MODE" == "nfs" ]; then
    echo
else

    wget -q -P /target http://${G_SERVER_IP}:5000/workspace/drivers/common.tgz
    tar -xzf /target/common.tgz -C /target/

    if lspci | grep -i "Mellanox"; then
        wget -q -P /target http://${G_SERVER_IP}:5000/workspace/drivers/ib.tgz
        tar -xzf /target/ib.tgz -C /target/
    fi

    if lspci | grep -i nvidia; then
        wget -q -P /target http://${G_SERVER_IP}:5000/workspace/drivers/nvidia.tgz
        wget -q -P /target http://${G_SERVER_IP}:5000/workspace/drivers/${CUDA}
        tar -xzf /target/nvidia.tgz -C /target/
    fi

fi
