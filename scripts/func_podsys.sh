# is_valid_ip
function is_valid_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        return $?
    else
        echo "Error:manager_ip:$1 is illegal"
        exit 1
    fi
}

# is_valid_storage
is_valid_storage() {
    local a=$1

    # "sdx" SATA
    if [[ $a =~ ^sd[a-z] ]]; then
        return 0
    fi

    # "nvmex" NVMe
    if [[ $a =~ ^nvme[0-9]+n[0-9]+ ]]; then
        return 0
    fi

    echo "compute_storage:$1 does not meet the requirements"
    exit 1
}


# delete_logs of apache and dnsmasq(docker)
delete_logs() {
    if [ ! -d "workspace/log" ]; then
        mkdir -p "workspace/log"
    fi
    logs=("workspace/log/dnsmasq.log" "workspace/log/conf_ip.log")

    for log in "${logs[@]}"; do
        if [ -f "$log" ]; then
            rm "$log"
        fi
    done
}


# get id_rsa ssh-key
get_rsa (){
  local user=$1
  if [ ! -f /home/$user/.ssh/id_rsa.pub ] || [ ! -f /home/$user/.ssh/id_rsa ]; then
       sudo -u $user ssh-keygen -t rsa -N "" -f /home/$user/.ssh/id_rsa
  fi
  if [ ! -f /home/$user/.ssh/authorized_keys ]; then
          cp /home/$user/.ssh/id_rsa.pub /home/$user/.ssh/authorized_keys
          chown $user:$user /home/$user/.ssh/authorized_keys
          chmod 644 /home/$user/.ssh/authorized_keys
  else
         if ! grep -q "$(cat /home/$user/.ssh/id_rsa.pub)" /home/$user/.ssh/authorized_keys 2>/dev/null; then
               cat /home/$user/.ssh/id_rsa.pub >> /home/$user/.ssh/authorized_keys
         fi
  fi
  new_pub_key=$(<"/home/$user/.ssh/id_rsa.pub")
}

# Function to check the iplist.txt format
check_iplist_format() {
    file_path="$1"
    # Check if the file exists
    if [ ! -f "$file_path" ]; then
        echo "Warning: File $file_path does not exist."
        return 1
    fi
    while IFS= read -r line
    do
        fields=($line) # Split the line into fields
        # Check if the number of fields is 7
        if [ ${#fields[@]} -ne 7 ]; then
            echo "Incorrect format on line iplist.txt: $line"
            continue
        fi
        # Check if the 3rd column is a valid IP address with subnet mask
        if ! echo "${fields[2]}" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$'; then
            echo "Invalid IP address with subnet mask in the 3rd column on line of iplist.txt: $line"
            continue
        fi

        # Check if the DNS column is a valid IP address
        if [ "${fields[4]}" != "none" ] && ! echo "${fields[4]}" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$'; then
            echo "Invalid DNS in the 4th column on line of iplist.txt: $line"
            continue
        fi

        # Check if the ib ip column is a valid IP address with subnet mask
        if [ "${fields[5]}" != "none" ] && ! echo "${fields[5]}" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$'; then
            echo "Invalid IB IP address  in the 5th column on line of iplist.txt: $line"
            continue
        fi
    done < "$file_path"
}

get_subnet_mask() {
    ip_address=$1
    ip_info=$(ip a | grep -A 1 $ip_address)
    if [ -z "$ip_info" ]; then
        echo "Error: IP address $ip_address not found." >&2
        exit 1
    fi
    subnet_mask=$(echo "$ip_info" | grep -oE 'inet\s[0-9\.]+/[0-9]+' | grep -oE '/[0-9]+')
    echo $subnet_mask
}