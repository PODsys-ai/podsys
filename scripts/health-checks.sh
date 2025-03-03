#!/bin/bash
cd $(dirname $0)

if [ "$(id -u)" != "0" ]; then echo "Error:please use sudo" &&  exit 1 ;fi

system_version=$(lsb_release -ds)
kernel_version=$(uname -r)
gpu_driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n 1)
cuda_version=$(/usr/local/cuda/bin/nvcc --version 2>/dev/null | grep "release" | awk '{print $5}' | tr -d ',')
docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
nvidia_container_version=$(nvidia-container-cli --version 2>/dev/null | awk '{print $2}' | head -n 1)
ofed_info=$(ofed_info -s 2>/dev/null)
pdsh=$(pdsh -V 2>/dev/null | head -n 1)
nfs_version=$(dpkg-query -W -f='${Version}' nfs-kernel-server 2>/dev/null)
nfs_status=$(systemctl is-active nfs-server 2>/dev/null)

# expected
expected_system_version="Ubuntu 24.04.2 LTS"
expected_kernel_version="6.8.0-41-generic"
expected_gpu_driver_version="570.86.15"
expected_cuda_version="12.8"
expected_docker_version="27.5.1"
expected_nvidia_container_version="1.17.4"
expected_ofed_info="MLNX_OFED_LINUX-24.10-1.1.4.0:"
expected_pdsh="pdsh-2.34 (+readline+debug)"
expected_nfs_version="1:2.6.4-3ubuntu5.1"
expected_nfs_status="active"

all_conditions_met=true

# check system_version
if [ "$system_version" != "$expected_system_version" ]; then
    echo -n "System mismatch: Expected '$expected_system_version', got '$system_version';"
    all_conditions_met=false
fi

# check kernel_version
if [ "$kernel_version" != "$expected_kernel_version" ]; then
    echo -n "Kernel mismatch: Expected '$expected_kernel_version', got '$kernel_version';"
    all_conditions_met=false
fi

# check gpu_driver_version
if [ "$gpu_driver_version" != "$expected_gpu_driver_version" ]; then
    echo -n "GPU Driver mismatch: Expected '$expected_gpu_driver_version', got '$gpu_driver_version';"
    all_conditions_met=false
fi

# check cuda_version
if [ "$cuda_version" != "$expected_cuda_version" ]; then
    echo -n "CUDA mismatch: Expected '$expected_cuda_version', got '$cuda_version';"
    all_conditions_met=false
fi

# check docker_version
if [ "$docker_version" != "$expected_docker_version" ]; then
    echo -n "Docker mismatch: Expected '$expected_docker_version', got '$docker_version';"
    all_conditions_met=false
fi

# check nvidia_container_version
if [ "$nvidia_container_version" != "$expected_nvidia_container_version" ]; then
    echo -n "NVIDIA Container mismatch: Expected '$expected_nvidia_container_version', got '$nvidia_container_version';"
    all_conditions_met=false
fi

# check ofed_info
if [ "$ofed_info" != "$expected_ofed_info" ]; then
    echo -n "OFED mismatch: Expected '$expected_ofed_info', got '$ofed_info';"
    all_conditions_met=false
fi

# check pdsh
if [ "$pdsh" != "$expected_pdsh" ]; then
    echo -n "PDSH mismatch: Expected '$expected_pdsh', got '$pdsh';"
    all_conditions_met=false
fi

# check nfs_version
if [ "$nfs_version" != "$expected_nfs_version" ]; then
    echo -n "NFS mismatch: Expected '$expected_nfs_version', got '$nfs_version';"
    all_conditions_met=false
fi

# check nfs_status
if [ "$nfs_status" != "$expected_nfs_status" ]; then
    echo -n "NFS status : Expected '$expected_nfs_status', got '$nfs_status';"
    all_conditions_met=false
fi

# print result
if $all_conditions_met; then
    echo "PODsys deployment successful"
else
    echo ""
fi