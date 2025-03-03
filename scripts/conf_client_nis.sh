#!/bin/bash
cd $(dirname "$0")

# $1 represents the IP address of the nis server
if dpkg -l libnss-nis nis ypbind-mt ypserv yp-tools | grep -q "^ii"; then
    echo "All required packages are already installed."
else
    dpkg -i ./nis/*.deb
fi

domain=podsys
hostname=$1
if [ ! -f "/etc/defaultdomain" ];then
        touch /etc/defaultdomain
fi
if [ -z "$hostname" ];then
        hostname=mu01
fi
echo $domain > /etc/defaultdomain
nisdomainname $domain
sed -i 's/NISCLIENT=false/NISCLIENT=true/g' /etc/default/nis

# Modify /etc/yp.conf
yp=$(cat << EOF
#
# yp.conf       Configuration file for the ypbind process. You can define
#               NIS servers manually here if they can't be found by
#               broadcasting on the local net (which is the default).
#
#               See the manual page of ypbind for the syntax of this file.
#
# IMPORTANT:    For the "ypserver", use IP addresses, or make sure that
#               the host is in /etc/hosts. This file is only interpreted
#               once, and if DNS isn't reachable yet the ypserver cannot
#               be resolved and ypbind won't ever bind to the server.

# ypserver ypserver.network.com
domain $domain server $hostname
EOF
)
echo "$yp" > /etc/yp.conf

# Modify /etc/nsswitch.conf
h=$(cat /etc/nsswitch.conf | grep -n passwd | awk -F ":" '{print $1}')
l=$(cat /etc/nsswitch.conf | grep -n group | awk -F ":" '{print $1}' | awk 'NR==1 {print}')
i=$(cat /etc/nsswitch.conf | grep -n shadow | awk -F ":" '{print $1}' | awk 'NR==1 {print}')
k=$(cat /etc/nsswitch.conf | grep -n hosts | awk -F ":" '{print $1}' | awk 'NR==1 {print}')

sed -i "${h}c passwd:\         files systemd nis "   /etc/nsswitch.conf
sed -i "${l}c group:\          files systemd nis "    /etc/nsswitch.conf
sed -i "${i}c shadow:\         files nis "  /etc/nsswitch.conf
sed -i "${k}c hosts:\          files dns nis"  /etc/nsswitch.conf

# Modify /etc/pam.d/common-session
search_string1="session required pam_mkhomedir.so skel=/etc/skel/ umask=0077"
file_path1="/etc/pam.d/common-session"

if ! grep -q "$search_string1" "$file_path1"; then
  echo "$search_string1" >> "$file_path1"
fi

# Restart service
systemctl restart rpcbind nscd ypbind
systemctl enable rpcbind nscd ypbind