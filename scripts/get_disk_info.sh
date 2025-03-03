#!/bin/bash
echo -n "SATA: "
sata_devices=$(lsblk -o NAME,TRAN | grep -i "^sd" | awk '{printf "%s ", $1}')
if [ -z "$sata_devices" ]; then
  echo "none"
else
  echo "$sata_devices"
fi

sleep 2

echo -n "NVMe: "
nvme_devices=$(lsblk -o NAME,TRAN | grep -i "^nvme" | awk '{printf "%s ", $1}')
if [ -z "$nvme_devices" ]; then
  echo "none"
else
  echo "$nvme_devices"
fi