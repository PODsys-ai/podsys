#!/bin/bash
cd $(dirname $0)

dpkg -i ./dwarves/*.deb
cp /sys/kernel/btf/vmlinux /usr/lib/modules/$(uname -r)/build/
dpkg -i ./beegfs_server_software/*.deb
cp ./beegfs_server_software/beegfs-client-autobuild.conf /etc/beegfs
/etc/init.d/beegfs-client rebuild
