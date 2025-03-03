#!/bin/bash
cd $(dirname $0)

username="nexus"

if [ "$(id -u)" != "0" ]; then  echo "Error:please use sudo" &&  exit 1 ; fi

if [ "$1" = "-nfsordma" ];then
        if [ $# -lt 2 ]; then
                echo "Error: Insufficient arguments provided."
                echo "Usage:sudo $0 -nfsordma <share_directory>"
                exit 1
        fi
        echo "Config nfs server"
        # $2 shared  floder
        if [[ $2 == /* ]];then
                ./scripts/conf_server_nfsordma.sh $2
        else
                echo "Please enter an absolute path"
        fi

elif [ "$1" = "-nfs" ];then
        if [ $# -lt 2 ]; then
                echo "Error: Insufficient arguments provided."
                echo "Usage:sudo $0 -nfs <share_directory>"
                exit 1
        fi
        echo "Config nfs server"
        # $2 shared floder
        if [[ $2 == /* ]];then
                ./scripts/conf_server_nfs.sh $2
        else
                echo "Please enter an absolute path"
        fi

elif [ "$1" = "-nis" ];then
        if [ $# -lt 2 ]; then
            echo "Error: Insufficient arguments provided."
            echo "Usage: $0 -nis  <nis_server_ip>"
            exit 1
        fi
        echo "Config nis server"
        # $2 represents the IP address of the nis server
        ip_info=$(ip a | grep -E "inet\s$2\/[0-9]+")
        if [ -z "$ip_info" ]; then
            echo "Error: IP address $2 not found."
            exit 1
        fi
        ./scripts/conf_server_nis.sh $2

elif [ "$1" = "-ldap" ];then
        if [ $# -lt 3 ]; then
                echo "Error: Insufficient arguments provided."
                echo "Usage:sudo $0 -ldap <ldap_server_ip> <ldap_password>"
                exit 1
         fi
         echo "Config ldap server"
         # $2 represents the IP address of the Openldap server
         ip_info=$(ip a | grep -A 1 $2)
         if [ -z "$ip_info" ]; then
            echo "Error: IP address $2 not found."
            exit 1
         fi
         # $3 represents the password for Openldap
         ./scripts/conf_server_ldap.sh $2 $3

elif [ "$1" = "-pre" ];then
        if [ $# -gt 1 ]; then
              echo "Error: Too many arguments provided."
              echo "Usage: $0 -pre"
         exit 1
        fi
        if [ ! -f "workspace/iplist.txt" ]; then
             echo "Error: workspace/iplist.txt does not exist."
             exit 1
        fi
        if [ ! -f "hosts.txt" ]; then
             touch hosts.txt &&  chmod 666 hosts.txt
        else
             cat /dev/null > hosts.txt
        fi
        hosts=$(awk '{split($3, parts, "/"); print parts[1]}' workspace/iplist.txt | grep -v '^$')
        for host in ${hosts[*]}
        do
           grep -wqF "$host" hosts.txt || echo "$host" >> hosts.txt
        done

        if [ ! -f "hosts.txt" ]; then
            echo "Error: Generating hosts.txt failed"
            exit 1
        else
            echo "Generating hosts.txt successfully"
        fi
        # test SSH
        machines=()
        while IFS= read -r line; do
          machines+=("$line")
        done < hosts.txt

        for machine in "${machines[@]}"
        do
            sudo -u ${username} ssh-keygen -f "/home/${username}/.ssh/known_hosts" -R "$machine" > /dev/null 2>&1
            sudo -u ${username} ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${username}@$machine" "echo 'SSH to $machine successful'" 2>/dev/null
            if [ $? -eq 0 ]; then
                sudo -u ${username} ssh "${username}@$machine" "exit"
            else
                echo "Failed to SSH to $machine"
                sed -i "/$machine/d"  hosts.txt
            fi
        done
        echo -e "Generating hosts.txt successfully\n"

        # ssh localhost
        manager_ip=$(cat workspace/config.yaml | grep "manager_ip" | cut -d ":" -f 2 | tr -d ' ')
        sudo -u ${username} ssh-keygen -f "/home/${username}/.ssh/known_hosts" -R "manager_ip" > /dev/null 2>&1
        sudo -u ${username} ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${username}@$manager_ip" "echo 'SSH to $manager_ip successful'" 2>/dev/null
        if [ $? -eq 0 ]; then
               sudo -u ${username} ssh "${username}@$manager_ip" "exit"
               echo
        fi

        # mkdir for client
        folder="podsys"
        sudo -u ${username} pdsh -R ssh -w ^hosts.txt "[ -d $folder ] && echo 'Folder podsys already exists' || (mkdir -p $folder)"
        # transfer files to client
        sudo -u ${username} pdcp -R ssh -w ^hosts.txt /home/${username}/.ssh/id_rsa     /home/${username}/.ssh/
        sudo -u ${username} pdcp -R ssh -w ^hosts.txt /home/${username}/.ssh/id_rsa.pub /home/${username}/.ssh/
        sudo -u ${username} pdcp -R ssh -w ^hosts.txt /home/${username}/.ssh/known_hosts /home/${username}/.ssh/
        sudo -u ${username} pdcp -R ssh -w ^hosts.txt -r scripts  $folder
        sudo -u ${username} pdsh -l root -R ssh -w ^hosts.txt  source /etc/profile

else
        echo "Invalid arguement: $1"
        echo "Valid arguments: -pre, -nfs, -nfsordma, -nis, -IPoIB, -ldap"
fi