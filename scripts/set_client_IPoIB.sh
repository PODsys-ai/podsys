#!/bin/bash
h=$(ibstat | grep -n LinkUp | awk -F ":" '{print $1}' | awk 'NR==1 {print}')
h=$[$h-9]
ibport=$(ibstat | awk 'NR==1 {print}' | awk -F " " '{print $2}' | awk -F "'" '{print $2}')
networkcard=$(ibdev2netdev | grep $ibport | awk -F '==> ' '{print $2}' | awk -F ' ' '{print $1}')
echo $networkcard
SN=`dmidecode -t 1|grep Serial|awk -F : '{print $2}'|awk -F ' ' '{print $1}'`
ibip=`grep $SN /podsys/iplist.txt|awk '{print $6}'`
echo $ibip
isnicconfigbefore=$(grep -i "$networkcard" "/etc/netplan/00-installer-config.yaml")
if [ -n "$ibip"  ]; then
        if [ -z "$isnicconfigbefore" ]; then
                c=$(cat /etc/netplan/00-installer-config.yaml | grep -n version | awk -F ":" '{print $1}')
                sed -i "${c}i \    $networkcard:" /etc/netplan/00-installer-config.yaml
                c=$[$c+1]
                sed -i "${c}i \      dhcp4: no"  /etc/netplan/00-installer-config.yaml
                c=$[$c+1]
                sed -i "${c}i \      dhcp6: no"  /etc/netplan/00-installer-config.yaml
                c=$[$c+1]
                sed -i "${c}i \      addresses: [$ibip]"  /etc/netplan/00-installer-config.yaml
                netplan apply
        else
                echo "$networkcard has already been configured"
        fi
else
        echo "IPoIB is Empty"
fi