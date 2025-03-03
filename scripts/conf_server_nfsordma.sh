#!/bin/bash

# Check if the directory exists, if not, create it
directory=$1
if [ ! -d "$directory" ]; then
  echo "Directory '$directory' does not exist. Creating now..."
  mkdir -p "$directory" || {
    echo "Failed to create directory '$directory'"
    exit 1
  }
else
  echo "Directory '$directory' already exists."
fi

echo "Setting permissions for directory '$directory' to 755..."
chmod 755 "$directory"

# Modify /etc/exports
search_string1="$directory  *(rw,async,insecure,no_root_squash)"
file_path1="/etc/exports"

if ! grep -qF "$search_string1" "$file_path1"; then
  echo "$search_string1" >>"$file_path1"
fi

# Load RDMA module
modprobe svcrdma
if lsmod | grep svcrdma >/dev/null; then
  echo "svcrdma load success"
else
  echo "svcrdma load fail"
fi

# Restarting the nfs service
service nfs-kernel-server restart
if [ $? -ne 0 ]; then
  echo "Failed to restart nfs-kernel-server"
  exit 1
fi

# Instruct the server to listen to RDMA transmission ports
echo rdma 20049 >/proc/fs/nfsd/portlist
echo "Config Finished"
echo