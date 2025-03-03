#!/bin/bash
cd $(dirname $0)

set_release() {
    current_datetime=$(date +%Y-%m-%d-%H-%M-%S)
    echo "PODsys_Version=\"3.0.1\"" >/etc/podsys-release
    echo "PODsys_Deployment_DATE=\"$current_datetime\"" >>/etc/podsys-release
}

set_limit() {
    local pattern="$1"
    content=$(<"/etc/security/limits.conf")
    if ! echo "$content" | grep -qF "$pattern"; then
        echo "$pattern" >>/etc/security/limits.conf
    fi
}

conf_ip() {
    if [ "$http_code" -eq 200 ]; then
        h=$(cat /etc/netplan/00-installer-config.yaml | grep -n dhcp | awk -F ":" '{print $1}' | awk 'NR==1 {print}')
        sed -i ${h}s/true/false/ /etc/netplan/00-installer-config.yaml
        h=$(($h + 1))
        sed -i "${h}i \      addresses: [$IP]" /etc/netplan/00-installer-config.yaml

        if [ -n "$GATEWAY" ] && [ "$GATEWAY" != "none" ]; then
            h=$(($h + 1))
            sed -i "${h}i \      routes:" /etc/netplan/00-installer-config.yaml
            h=$(($h + 1))
            sed -i "${h}i \        - to: default" /etc/netplan/00-installer-config.yaml
            h=$(($h + 1))
            sed -i "${h}i \          via: $GATEWAY" /etc/netplan/00-installer-config.yaml
        else
            echo "$SN NO GATEWAY" >>/podsys/log/conf_ip.log
        fi

        if [ -n "$DNS" ] && [ "$DNS" != "none" ]; then
            h=$(($h + 1))
            sed -i "${h}i \      nameservers:" /etc/netplan/00-installer-config.yaml
            h=$(($h + 1))
            sed -i "${h}i \        addresses: [${DNS}]" /etc/netplan/00-installer-config.yaml
        else
            echo "$SN NO DNS" >>/podsys/log/conf_ip.log
        fi
        
        if [ -n "$docker0_ip" ] && [ "$docker0_ip" != "none" ]; then
            mkdir -p /etc/docker
            if [ ! -f /etc/docker/daemon.json ]; then
                echo '{"bip": "'"$docker0_ip"'"}' >/etc/docker/daemon.json
            else
                if grep -q "bip" "/etc/docker/daemon.json"; then
                    sed -i "2c \    \"bip\": \"$docker0_ip\"," /etc/docker/daemon.json
                else
                    sed -i "1a \    \"bip\": \"$docker0_ip\"," /etc/docker/daemon.json
                fi
            fi
        fi
    else
        network_interface=$(ip route | grep default | awk 'NR==1 {print $5}')
        DHCP_IP=$(ip addr show $network_interface | grep 'inet\b' | awk '{print $2}' | cut -d/ -f1)
        SUBNET_MASK=$(ip addr show $network_interface | grep 'inet\b' | awk '{print $2}' | cut -d/ -f2)
        h=$(cat /etc/netplan/00-installer-config.yaml | grep -n dhcp | awk -F ":" '{print $1}' | awk 'NR==1 {print}')
        sed -i ${h}s/true/false/ /etc/netplan/00-installer-config.yaml
        h=$(($h + 1))
        sed -i "${h}i \      addresses: [$DHCP_IP/$SUBNET_MASK]" /etc/netplan/00-installer-config.yaml
        curl -X POST -d "serial=$SN" http://"$1":5000/receive_serial_ip
        echo "$SN NO IP, DHCP address will be used statically." >>/podsys/log/conf_ip.log
        echo -e "$SN\tnode${SN}\t${DHCP_IP}/${SUBNET_MASK}\tnone\tnone\tnone\tnone" >>/podsys/iplist.txt
    fi
    # disable cloud init networkconfig
    echo "network: {config: disabled}" >>/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    netplan apply
}

# Function to install packages from a specified directory
install_packages_from_dir() {
    local dir=$1
    dpkg -i "$dir"/lib/*.deb >>"$install_log"
    dpkg -i "$dir"/tools/*.deb >>"$install_log"
    dpkg -i "$dir"/docker/*.deb >>"$install_log"
    dpkg -i "$dir"/nfs/*.deb >>"$install_log"
    dpkg -i "$dir"/updates/*.deb >>"$install_log"
}

install_compute() {
    local method=$2

    timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    install_log="/podsys/log/${HOSTNAME}_install_${timestamp}.log"
    log_name="${HOSTNAME}_install_${timestamp}.log"
    curl -X POST -d "serial=$SN&log=$log_name" "http://$1:5000/updatelog"

    CUDA=cuda_12.2.2_535.104.05_linux.run
    IB=MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu22.04-ext

    # install deb
    echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install deb------\e[0m" >>$install_log
    apt purge -y unattended-upgrades >>$install_log

    if [ "$method" == "http" ]; then
        wget -q http://$1:5000/workspace/drivers/common.tgz
        tar -xzf common.tgz
        install_packages_from_dir "./common"
    elif [ "$method" == "nfs" ]; then
        install_packages_from_dir "./podsys/common"
        curl -X POST -d "file=common" "http://$1:5000/receive_nfs_status"
    elif [ "$method" == "p2p" ]; then
        install_packages_from_dir "./common"
    else
        wget -q http://$1:5000/workspace/drivers/common.tgz
        tar -xzf common.tgz
        install_packages_from_dir "./common"
    fi

    echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish install deb------\e[0m" >>$install_log

    # install MLNX
    if lspci | grep -i "Mellanox"; then

        curl -X POST -d "serial=$SN&ibstate=ok" "http://$1:5000/ibstate"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install MLNX------\e[0m" >>$install_log

        if [ "$method" == "http" ]; then
            wget -q http://$1:5000/workspace/drivers/ib.tgz
            tar -xzf ib.tgz
            ./ib/${IB}/mlnxofedinstall --without-fw-update --with-nfsrdma --all --force >>$install_log
        elif [ "$method" == "nfs" ]; then
            ./podsys/ib/${IB}/mlnxofedinstall --without-fw-update --with-nfsrdma --all --force >>$install_log
            curl -X POST -d "file=ib" "http://$1:5000/receive_nfs_status"
        elif [ "$method" == "p2p" ]; then
            ./ib/${IB}/mlnxofedinstall --without-fw-update --with-nfsrdma --all --force >>$install_log
        else
            wget -q http://$1:5000/workspace/drivers/ib.tgz
            tar -xzf ib.tgz
            ./ib/${IB}/mlnxofedinstall --without-fw-update --with-nfsrdma --all --force >>$install_log
        fi

        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish install MLNX------\e[0m" >>$install_log
        systemctl enable openibd >>$install_log
    else
        curl -X POST -d "serial=$SN&ibstate=0" "http://$1:5000/ibstate"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) No MLNX Infiniband Device\e[0m" >>$install_log
    fi

    if lspci | grep -i nvidia; then

        curl -X POST -d "serial=$SN&gpustate=ok" "http://$1:5000/gpustate"
        # install GPU driver
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install GPU driver------\e[0m" >>$install_log
        touch /etc/modprobe.d/nouveau-blacklist.conf
        echo "blacklist nouveau" | tee /etc/modprobe.d/nouveau-blacklist.conf
        echo "options nouveau modeset=0" | tee -a /etc/modprobe.d/nouveau-blacklist.conf

        if [ "$method" == "http" ]; then
            wget -q http://$1:5000/workspace/drivers/nvidia.tgz
            tar -xzf nvidia.tgz
            ./nvidia/*.run --accept-license --no-questions --no-install-compat32-libs --ui=none --disable-nouveau >>$install_log
        elif [ "$method" == "nfs" ]; then
            ./podsys/nvidia/*.run --accept-license --no-questions --no-install-compat32-libs --ui=none --disable-nouveau >>$install_log
        elif [ "$method" == "p2p" ]; then
            ./nvidia/*.run --accept-license --no-questions --no-install-compat32-libs --ui=none --disable-nouveau >>$install_log
        else
            wget -q http://$1:5000/workspace/drivers/nvidia.tgz
            tar -xzf nvidia.tgz
            ./nvidia/*.run --accept-license --no-questions --no-install-compat32-libs --ui=none --disable-nouveau >>$install_log
        fi

        # Load nvidia_peermem module
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start Load nvidia_peermem module------\e[0m" >>$install_log
        touch /etc/systemd/system/load-nvidia-peermem.service
        echo '[Unit]' >>/etc/systemd/system/load-nvidia-peermem.service
        echo 'Description=Load nvidia_peermem Module' >>/etc/systemd/system/load-nvidia-peermem.service
        echo 'After=network.target' >>/etc/systemd/system/load-nvidia-peermem.service
        echo "" >>/etc/systemd/system/load-nvidia-peermem.service
        echo '[Service]' >>/etc/systemd/system/load-nvidia-peermem.service
        echo 'ExecStart=/sbin/modprobe nvidia_peermem' >>/etc/systemd/system/load-nvidia-peermem.service
        echo "" >>/etc/systemd/system/load-nvidia-peermem.service
        echo '[Install]' >>/etc/systemd/system/load-nvidia-peermem.service
        echo 'WantedBy=multi-user.target' >>/etc/systemd/system/load-nvidia-peermem.service

        # Enable nvidia-persistenced
        echo -e "\033[32m---Enable nvidia-persistenced---\033[0m"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Enable nvidia-persistenced------\e[0m" >>$install_log
        touch /etc/systemd/system/nvidia-persistenced.service
        echo '[Unit]' >>/etc/systemd/system/nvidia-persistenced.service
        echo 'Description=Enable nvidia-persistenced' >>/etc/systemd/system/nvidia-persistenced.service
        echo "" >>/etc/systemd/system/nvidia-persistenced.service
        echo '[Service]' >>/etc/systemd/system/nvidia-persistenced.service
        echo 'Type=oneshot' >>/etc/systemd/system/nvidia-persistenced.service
        echo 'ExecStart=/usr/bin/nvidia-smi -pm 1' >>/etc/systemd/system/nvidia-persistenced.service
        echo 'RemainAfterExit=yes' >>/etc/systemd/system/nvidia-persistenced.service
        echo "" >>/etc/systemd/system/nvidia-persistenced.service
        echo '[Install]' >>/etc/systemd/system/nvidia-persistenced.service
        echo 'WantedBy=default.target' >>/etc/systemd/system/nvidia-persistenced.service

        systemctl daemon-reload >>$install_log
        systemctl enable load-nvidia-peermem >>$install_log
        systemctl start load-nvidia-peermem >>$install_log
        systemctl enable nvidia-persistenced.service >>$install_log
        systemctl start nvidia-persistenced.service >>$install_log

        # Install nv docker
        if [ "$method" == "http" ]; then
            dpkg -i ./nvidia/docker/*.deb >>$install_log
        elif [ "$method" == "nfs" ]; then
            dpkg -i ./podsys/nvidia/docker/*.deb >>$install_log
        elif [ "$method" == "p2p" ]; then
            dpkg -i ./nvidia/docker/*.deb >>$install_log
        else
            dpkg -i ./nvidia/docker/*.deb >>$install_log
        fi

        nvidia-ctk runtime configure --runtime=docker >>$install_log
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish install nv docker------\e[0m" >>$install_log

        # Install NVIDIA fabricmanager
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install NVIDIA fabricmanager------\e[0m" >>$install_log
        device_id=$(lspci | grep -i nvidia | head -n 1 | awk '{print $7}')
        if [ "$device_id" = "26b9" ]; then
            echo "Does not support NVIDIA fabricmanager" >>$install_log
        else
            if [ "$method" == "http" ]; then
                dpkg -i ./nvidia/nv-fm/*.deb >>$install_log
            elif [ "$method" == "nfs" ]; then
                dpkg -i ./podsys/nvidia/nv-fm/*.deb >>$install_log
            elif [ "$method" == "p2p" ]; then
                dpkg -i ./nvidia/nv-fm/*.deb >>$install_log
            else
                dpkg -i ./nvidia/nv-fm/*.deb >>$install_log
            fi

            systemctl enable nvidia-fabricmanager.service >>$install_log
            systemctl start nvidia-fabricmanager.service >>$install_log
        fi

        # Install CUDA
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install cuda------\e[0m" >>$install_log
        if [ "$method" == "http" ]; then
            wget -q http://$1:5000/workspace/drivers/${CUDA}
            chmod 755 ${CUDA}
            ./${CUDA} --silent --toolkit >>$install_log
        elif [ "$method" == "nfs" ]; then
            ./podsys/drivers/${CUDA} --silent --toolkit >>$install_log
        elif [ "$method" == "p2p" ]; then
            chmod 755 ${CUDA}
            ./${CUDA} --silent --toolkit >>$install_log
            curl -X POST -d "file=cuda" "http://$1:5000/receive_nfs_status"
        else
            wget -q http://$1:5000/workspace/drivers/${CUDA}
            chmod 755 ${CUDA}
            ./${CUDA} --silent --toolkit >>$install_log
        fi

        echo 'export PATH=$PATH:/usr/local/cuda/bin' >>/etc/profile
        echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' >>/etc/profile
        source /etc/profile

        # Install DCGM
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Install NVIDIA DCGM------\e[0m" >>$install_log
        if [ "$method" == "http" ]; then
            dpkg -i ./nvidia/dcgm/*.deb >>$install_log
        elif [ "$method" == "nfs" ]; then
            dpkg -i ./podsys/nvidia/dcgm/*.deb >>$install_log
        elif [ "$method" == "p2p" ]; then
            dpkg -i ./nvidia/dcgm/*.deb >>$install_log
        else
            dpkg -i ./nvidia/dcgm/*.deb >>$install_log
        fi

        systemctl --now enable nvidia-dcgm >>$install_log

        # Install NCCL
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Install NVIDIA NCCL------\e[0m" >>$install_log
        if [ "$method" == "http" ]; then
            dpkg -i ./nvidia/nccl/*.deb >>$install_log
        elif [ "$method" == "nfs" ]; then
            dpkg -i ./podsys/nvidia/nccl/*.deb >>$install_log
        elif [ "$method" == "p2p" ]; then
            dpkg -i ./nvidia/nccl/*.deb >>$install_log
        else
            dpkg -i ./nvidia/nccl/*.deb >>$install_log
        fi

        # Install cudnn
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Install NVIDIA cuDNN------\e[0m" >>$install_log
        if [ "$method" == "http" ]; then
            dpkg -i ./nvidia/cudnn/*.deb >>$install_log
        elif [ "$method" == "nfs" ]; then
            dpkg -i ./podsys/nvidia/cudnn/*.deb >>$install_log
            curl -X POST -d "file=nvidia" "http://$1:5000/receive_nfs_status"
        elif [ "$method" == "p2p" ]; then
            dpkg -i ./nvidia/cudnn/*.deb >>$install_log
        else
            dpkg -i ./nvidia/cudnn/*.deb >>$install_log
        fi
    else
        curl -X POST -d "serial=$SN&gpustate=0" "http://$1:5000/gpustate"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) No NVIDIA GPU Device\e[0m" >>$install_log

    fi

    systemctl restart docker >>$install_log
    echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish ALL------\e[0m" >>$install_log
    rm -rf common/ ib/ nvidia/
    rm -f common.tgz ib.tgz nvidia.tgz ${CUDA}

}


# install compute
SN=$(dmidecode -t 1 | grep Serial | awk -F : '{print $2}' | awk -F ' ' '{print $1}')
response=$(curl -s -w "\n%{http_code}" -X POST -d "serial=$SN" http://$1:5000/request_iplist)

http_code=$(echo "$response" | tail -n 1)
json_response=$(echo "$response" | sed '$d')
if [ "$http_code" -eq 200 ]; then
    HOSTNAME=$(echo "$json_response" | grep -oP '"hostname":\s*"\K[^"]+')
    IP=$(echo "$response" | grep -oP '"ip":\s*"\K[^"]+')
    GATEWAY=$(echo "$response" | grep -oP '"gateway":\s*"\K[^"]+')
    DNS=$(echo "$json_response" | grep -oP '"dns":\s*"\K[^"]+')
    docker0_ip=$(echo "$json_response" | grep -oP '"dockerip":\s*"\K[^"]+')
else
    HOSTNAME="node${SN}"
fi


install_compute "$1" "$2" 
curl -X POST -d "serial=$SN" http://"$1":5000/receive_serial_e

# set limits
set_limit "root soft nofile 65536"
set_limit "root hard nofile 65536"
set_limit "* soft nofile 65536"
set_limit "* hard nofile 65536"
set_limit "* soft stack unlimited"
set_limit "* soft nproc unlimited"
set_limit "* hard stack unlimited"
set_limit "* hard nproc unlimited"

# conf_ip
conf_ip "$1"

# set release
set_release
