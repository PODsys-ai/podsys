#!/bin/bash
cd $(dirname "$0")

systemctl stop systemd-timesyncd.service > /dev/null 2>&1
systemctl disable systemd-timesyncd.service > /dev/null 2>&1
apt-get remove systemd-timesyncd -y > /dev/null 2>&1
apt-get autoremove --purge -y systemd-timesync > /dev/null 2>&1

if dpkg -l | grep -q "ntp"; then
  :
else
  dpkg -i  ./ntp/*.deb > /dev/null 2>&1
fi

ntp_service_ip=$1

if [ -z "$ntp_service_ip" ];then
  echo "Please input ntp_server's IP."
  exit 1
fi

search_string1="server $ntp_service_ip iburst"
file_path1="/etc/ntp.conf"

if [ ! -f "$file_path1" ];then
        touch $file_path1
fi

if ! grep -qF "$search_string1" "$file_path1"; then
  echo "$search_string1" >> "$file_path1"
fi

systemctl restart ntp.service

sleep 1
date
hwclock -w