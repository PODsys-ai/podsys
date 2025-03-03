#!/bin/bash
cd $(dirname "$0")

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
sed -i 's/NISSERVER=false/NISSERVER=master/g' /etc/default/nis

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
nisdomainname $domain
EOF
)
echo "$yp" > /etc/yp.conf
nisdomainname $domain > /dev/null
systemctl restart rpcbind ypserv yppasswdd ypxfrd > /dev/null
systemctl enable  rpcbind ypserv yppasswdd ypxfrd > /dev/null
systemctl restart ypbind > /dev/null