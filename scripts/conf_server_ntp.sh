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



systemctl restart ntp.service
systemctl status ntp.service

ntpq -p

sleep 1
date
hwclock -w