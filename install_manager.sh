#!/bin/bash
cd $(dirname $0)

set -eu

if [ "$(id -u)" != "0" ]; then echo "Error:please use sudo" &&  exit 1 ;fi

if type uname >/dev/null 2>&1; then
    case "$(uname)" in
    Linux)
        ;;
    *)
        echo "OS $(uname) is not supported"
        exit 1
        ;;
    esac
fi

if type uname >/dev/null 2>&1; then
    case "$(uname -m)" in
    aarch64) ;;
    *)
        echo "Processor $(uname -m) is not supported"
        exit 1
        ;;
    esac
fi

if ! type lsb_release >/dev/null 2>&1; then
    . /etc/os-release
    OS_Description=$(echo "$PRETTY_NAME" )
else
    OS_Description=$(lsb_release -d -s 2>/dev/null || echo "" )
fi

if [ "$OS_Description" != "Ubuntu 22.04.5 LTS" ]; then
    echo "Error: This script is only supported on Ubuntu 22.04.5 LTS"
    exit 1
fi

if [ ! -d "workspace/log" ]; then mkdir -p workspace/log; fi

hostname=$(hostname)
timestamp=$(date +%Y-%m-%d_%H-%M-%S)
install_log="./workspace/log/${hostname}_install_${timestamp}.log"

IB=MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu22.04-ext

# install common deb
echo -e "\033[32m---Install deb---\033[0m"
tar -xzf workspace/drivers/common.tgz > /dev/null &
pid=$!
while ps -p $pid > /dev/null; do
    echo -n "*"
    sleep 2
done
echo
echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install deb------\e[0m"  >> $install_log
apt-get purge -y unattended-upgrades                    >> $install_log
dpkg -i ./common/lib/*.deb                              >> $install_log
dpkg -i ./common/tools/*.deb                            >> $install_log
dpkg -i ./common/docker/*.deb                           >> $install_log
dpkg -i ./common/updates/*.deb                          >> $install_log
dpkg -i ./common/nfs/*.deb                              >> $install_log
echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish install deb------\e[0m"  >> $install_log
rm -rf common/

# install MLNX
if lspci | grep -i "Mellanox"; then
        echo -e  "\033[32m---Install MLNX---\033[0m"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install MLNX------\e[0m"  >> $install_log
        tar -xzf workspace/drivers/ib.tgz > /dev/null &
        pid=$!
        while ps -p $pid > /dev/null; do
            echo -n "*"
            sleep 2
        done
        echo
        ./ib/${IB}/mlnxofedinstall \
        --without-fw-update  --with-nfsrdma --all --force >> $install_log
        systemctl enable openibd    >> $install_log
        systemctl enable opensmd     >> $install_log
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish install MLNX------\e[0m"  >> $install_log
        rm -rf ib/
else
        echo -e "\033[31m\033[1mno Infiniband controller device\033[0m"  >> $install_log
fi

# Install NVIDIA Driver
if lspci | grep -i "3D controller: NVIDIA"; then
        tar -xzf workspace/drivers/nvidia.tgz > /dev/null &
        pid=$!
        while ps -p $pid > /dev/null; do
            echo -n "*"
            sleep 2
        done
        echo
        echo -e  "\033[32m---Install NVIDIA 3D controller Driver---\033[0m"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install NVIDIA 3D controller Driver------\e[0m"  >> $install_log
        touch /etc/modprobe.d/nouveau-blacklist.conf
        echo "blacklist nouveau" |  tee /etc/modprobe.d/nouveau-blacklist.conf
        echo "options nouveau modeset=0" |  tee -a /etc/modprobe.d/nouveau-blacklist.conf
        update-initramfs -u >> $install_log
        ./nvidia/*.run --accept-license --no-questions \
        --no-install-compat32-libs --ui=none --disable-nouveau >> $install_log
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish install NVIDIA 3D controller Driver------\e[0m"  >> $install_log

        # Load nvidia_peermem module
        echo -e  "\033[32m---Load nvidia_peermem module---\033[0m"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Load nvidia_peermem module------\e[0m"  >> $install_log
        touch /etc/systemd/system/load-nvidia-peermem.service
        echo '[Unit]' >> /etc/systemd/system/load-nvidia-peermem.service
        echo 'Description=Load nvidia_peermem Module' >> /etc/systemd/system/load-nvidia-peermem.service
        echo 'After=network.target' >> /etc/systemd/system/load-nvidia-peermem.service
        echo "" >> /etc/systemd/system/load-nvidia-peermem.service
        echo '[Service]' >> /etc/systemd/system/load-nvidia-peermem.service
        echo 'ExecStart=/sbin/modprobe nvidia_peermem' >> /etc/systemd/system/load-nvidia-peermem.service
        echo "" >> /etc/systemd/system/load-nvidia-peermem.service
        echo '[Install]' >> /etc/systemd/system/load-nvidia-peermem.service
        echo 'WantedBy=multi-user.target' >> /etc/systemd/system/load-nvidia-peermem.service

        # Enable nvidia-persistenced
        echo -e  "\033[32m---Enable nvidia-persistenced---\033[0m"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Enable nvidia-persistenced------\e[0m"  >> $install_log
        touch /etc/systemd/system/nvidia-persistenced.service
        echo '[Unit]' >> /etc/systemd/system/nvidia-persistenced.service
        echo 'Description=Enable nvidia-persistenced' >> /etc/systemd/system/nvidia-persistenced.service
        echo "" >> /etc/systemd/system/nvidia-persistenced.service
        echo '[Service]' >> /etc/systemd/system/nvidia-persistenced.service
        echo 'Type=oneshot' >> /etc/systemd/system/nvidia-persistenced.service
        echo 'ExecStart=/usr/bin/nvidia-smi -pm 1' >> /etc/systemd/system/nvidia-persistenced.service
        echo 'RemainAfterExit=yes' >> /etc/systemd/system/nvidia-persistenced.service
        echo "" >> /etc/systemd/system/nvidia-persistenced.service
        echo '[Install]' >> /etc/systemd/system/nvidia-persistenced.service
        echo 'WantedBy=default.target' >> /etc/systemd/system/nvidia-persistenced.service

        systemctl daemon-reload             >> $install_log
        systemctl enable load-nvidia-peermem
        systemctl start load-nvidia-peermem >> $install_log
        systemctl enable nvidia-persistenced.service
        systemctl start nvidia-persistenced.service >> $install_log


        # Install CUDA
        echo -e "\033[32m---Install CUDA---\033[0m"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start install CUDA------\e[0m"  >> $install_log
        ./workspace/drivers/*.run --silent --toolkit >> $install_log
        echo 'export PATH=$PATH:/usr/local/cuda/bin' >> /etc/profile
        echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' >> /etc/profile
        source  /etc/profile
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish install CUDA------\e[0m"  >> $install_log

        # Install nv docker
        echo -e "\033[32m---Install nv docker---\033[0m"
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Start Install nv docker------\e[0m"  >> $install_log
        dpkg -i ./nvidia/docker/*.deb >> $install_log
        nvidia-ctk runtime configure --runtime=docker >> $install_log
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Finish Install nv docker------\e[0m"  >> $install_log

        # Install NVIDIA fabricmanager

        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Install NVIDIA fabricmanager------\e[0m"  >> $install_log
        device_id=$(lspci | grep -i nvidia | head -n 1 | awk '{print $7}')
        if [ "$device_id" = "26b9" ]; then
           echo "Does not support NVIDIA fabricmanager" >> $install_log
        else
            echo -e "\033[32m---Install NVIDIA fabricmanager---\033[0m"
            dpkg -i ./nvidia/nv-fm/*.deb >> $install_log
            systemctl enable nvidia-fabricmanager.service >> $install_log
            systemctl start nvidia-fabricmanager.service  >> $install_log
        fi

        # Install DCGM
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Install NVIDIA DCGM------\e[0m"  >> $install_log
        dpkg -i ./nvidia/dcgm/*.deb >> $install_log
        systemctl --now enable nvidia-dcgm >> $install_log

        # Install NCCL
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Install NVIDIA NCCL------\e[0m"  >> $install_log
        dpkg -i ./nvidia/nccl/*.deb >> $install_log

        # Install cudnn
        echo -e "\e[32m$(date +%Y-%m-%d_%H-%M-%S) Install NVIDIA cuDNN------\e[0m"  >> $install_log
        dpkg -i ./nvidia/cudnn/*.deb >> $install_log

        rm -rf nvidia/
else
        echo  "no nvidia 3D controller device" >> $install_log
fi

systemctl restart docker >> $install_log


set_release() {
    current_datetime=$(date +%Y-%m-%d-%H-%M-%S)
    echo "PODsys_Version=\"3.0.1\"" > /etc/podsys-release
    echo "PODsys_Deployment_DATE=\"$current_datetime\"" >> /etc/podsys-release
}

set_limit() {
    local pattern="$1"
    content=$(<"/etc/security/limits.conf")
    if ! echo "$content" | grep -qF "$pattern"; then
        echo "$pattern" >> /etc/security/limits.conf
    fi
}


# set_limits
set_limit "root soft nofile 65536"
set_limit "root hard nofile 65536"
set_limit "* soft nofile 65536"
set_limit "* hard nofile 65536"
set_limit "* soft stack unlimited"
set_limit "* soft nproc unlimited"
set_limit "* hard stack unlimited"
set_limit "* hard nproc unlimited"

# set release
set_release

# Check if user entered yes
read -p "Do you want to reboot now? Enter yes or no: " choice
if [ "$choice" = "yes" ]; then
    reboot
else
    echo "Please restart to apply the IB driver."
fi