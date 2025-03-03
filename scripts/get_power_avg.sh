#!/bin/bash

rm -f tmp1.txt
rm -f tmp2.txt
rm -f total_power.txt

if [ "$(id -u)" != "0" ]; then
    for ((COUNT=0; COUNT<10; COUNT++)); do
        pdsh -l root -R ssh -w ^hosts.txt ipmitool sdr get "Total_Power" |
        grep "Sensor Reading" >> tmp1.txt
        sleep 30
    done
else
    for ((COUNT=0; COUNT<10; COUNT++)); do
        sudo -u nexus pdsh -l root -R ssh -w ^hosts.txt ipmitool sdr get "Total_Power" |
        grep "Sensor Reading" >> tmp1.txt
        sleep 30
    done
fi

awk -F ' +|\\([+-]' '{print $1 "\t" $5}' tmp1.txt | sort -nrk2 > total_power.txt

declare -A sum_map
declare -A count_map

while read line
do
        ip_address=$(echo $line | awk -F : '{print $1}')
        sensor_reading=$(echo $line | tr -d ' ' | awk -F : '{print $2}')

        if [ -z "${sum_map[$ip_address]}" ]; then
                sum_map[$ip_address]=0
                count_map[$ip_address]=0
        fi
        sum_map[$ip_address]=$((${sum_map[$ip_address]} + $sensor_reading))
        count_map[$ip_address]=$((count_map[$ip_address] + 1))
done < total_power.txt

for ip_address in "${!sum_map[@]}"; do
    average=$(bc <<< "scale=2; ${sum_map[$ip_address]} / ${count_map[$ip_address]}")
    echo "$ip_address:$average" >> tmp2.txt
done

timestamp=$(date +%m-%d_%H-%M-%S)
sort -t ':' -k 2nr tmp2.txt > total_power_avg_${timestamp}.txt

rm -f tmp1.txt
rm -f tmp2.txt
rm -f total_power.txt