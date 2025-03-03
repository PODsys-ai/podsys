#!/bin/bash

# Function to enable PXE and UEFI using mlxconfig tool
configure_infiniband_with_mlx() {
    INFINIBAND_SYS_PATH="/sys/class/infiniband/"
    
    # Iterate through all InfiniBand devices
    for device in $(ls ${INFINIBAND_SYS_PATH}); do
        echo "Enabling PXE and UEFI on InfiniBand device: $device"
        
        # Enable PXE
        mlxconfig -y -d $device set EXP_ROM_PXE_ENABLE=1
        
        # Enable UEFI for x86 architecture
        mlxconfig -y -d $device set EXP_ROM_UEFI_x86_ENABLE=1
    done
}

# Function to enable PXE and UEFI using mstconfig tool
configure_infiniband_with_mst() {
    PCI_DEVICES_PATH="/sys/bus/pci/devices"
    
    # Loop through all PCI devices
    for bus_dev_func in $(ls "${PCI_DEVICES_PATH}"); do
        # Check if the device is an InfiniBand device
        if [[ -e "${PCI_DEVICES_PATH}/${bus_dev_func}/infiniband" ]]; then
            echo "Enabling PXE and UEFI on PCI device: $bus_dev_func"
            
            # Enable PXE
            mstconfig -y -d "$bus_dev_func" set EXP_ROM_PXE_ENABLE=1
            
            # Enable UEFI for x86 architecture
            mstconfig -y -d "$bus_dev_func" set EXP_ROM_UEFI_x86_ENABLE=1
        fi
    done
}

# Main function to enable PXE and UEFI on Mellanox InfiniBand devices
enable_mellanox_pxe() {
    if which mlxconfig > /dev/null 2>&1; then
        configure_infiniband_with_mlx
    elif which mstconfig > /dev/null 2>&1; then
        configure_infiniband_with_mst
    else
        echo "Error: Neither mlxconfig nor mstconfig is available on this system."
        exit 1
    fi
}

# Check if the script is run as root user
if [ "$(id -u)" != "0" ]; then 
    echo "This script must be run with root privileges. Please use sudo or switch to the root user."
    exit 1 
fi

# Execute the function to enable PXE and UEFI
enable_mellanox_pxe