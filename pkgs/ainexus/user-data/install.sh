#!/bin/bash
cd $(dirname $0)

set_release() {
    current_datetime=$(date +%Y-%m-%d-%H-%M-%S)
    echo "PODsys_Version=\"3.1\"" >/etc/podsys-release
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

install_compute() {
    local method=$2

    timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    install_log="/podsys/log/${HOSTNAME}_install_${timestamp}.log"
    log_name="${HOSTNAME}_install_${timestamp}.log"
    curl -X POST -d "serial=$SN&log=$log_name" "http://$1:5000/updatelog"

    CUDA=cuda_12.8.0_570.86.10_linux_sbsa.run

    # install deb
    echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install deb------\e[0m" >>$install_log
    apt purge -y unattended-upgrades >>$install_log

    if [ "$method" == "http" ]; then
        wget -q -P /podsys http://$1:5000/workspace/drivers/common.tgz
    fi

    echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish install deb------\e[0m" >>$install_log

    # install MLNX
    if lspci | grep -i "Mellanox"; then

        curl -X POST -d "serial=$SN&ibstate=ok" "http://$1:5000/ibstate"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install MLNX------\e[0m" >>$install_log

        if [ "$method" == "http" ]; then
            wget -q -P /podsys http://$1:5000/workspace/drivers/ib.tgz
        fi

        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish install MLNX------\e[0m" >>$install_log

    else
        curl -X POST -d "serial=$SN&ibstate=0" "http://$1:5000/ibstate"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) No MLNX Infiniband Device\e[0m" >>$install_log
    fi

    if lspci | grep -i nvidia; then

        curl -X POST -d "serial=$SN&gpustate=ok" "http://$1:5000/gpustate"
        # install GPU driver
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install GPU driver------\e[0m" >>$install_log

        if [ "$method" == "http" ]; then
            wget -q -P /podsys http://$1:5000/workspace/drivers/nvidia.tgz
        fi

        # Install CUDA
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install cuda------\e[0m" >>$install_log
        if [ "$method" == "http" ]; then
            wget -q -P /podsys http://$1:5000/workspace/drivers/${CUDA}
        fi

    else
        curl -X POST -d "serial=$SN&gpustate=0" "http://$1:5000/gpustate"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) No NVIDIA GPU Device\e[0m" >>$install_log

    fi

    systemctl restart docker >>$install_log
    echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish ALL------\e[0m" >>$install_log

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
