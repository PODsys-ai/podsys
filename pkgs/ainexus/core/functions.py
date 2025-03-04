import ipaddress
import re


def parse_config(config_path):
    with open(config_path, "r") as file:
        content = file.read()
    """
manager_ip:192.168.2.11
dhcp_s:192.168.2.201
dhcp_e:192.168.2.220
manager_nic:enp61s0f2
compute_passwd:123
compute_storage:sda
"""
    manager_ip_match = re.search(r"manager_ip:\s*(\S+)", content)
    manager_nic_match = re.search(r"manager_nic:\s*(\S+)", content)
    dhcp_s_match = re.search(r"dhcp_s:\s*(\S+)", content)
    dhcp_e_match = re.search(r"dhcp_e:\s*(\S+)", content)
    compute_passwd_match = re.search(r"compute_passwd:\s*(\S+)", content)
    compute_storage_match = re.search(r"compute_storage:\s*(\S+)", content)

    manager_ip = manager_ip_match.group(1).strip() if manager_ip_match else None
    manager_nic = manager_nic_match.group(1).strip() if manager_nic_match else None
    dhcp_s = dhcp_s_match.group(1).strip() if dhcp_s_match else None
    dhcp_e = dhcp_e_match.group(1).strip() if dhcp_e_match else None
    compute_passwd = compute_passwd_match.group(1).strip() if compute_passwd_match else None
    compute_storage = compute_storage_match.group(1).strip() if compute_storage_match else None

    return {
        "manager_ip": manager_ip,
        "manager_nic": manager_nic,
        "dhcp_s": dhcp_s,
        "dhcp_e": dhcp_e,
        "compute_passwd": compute_passwd,
        "compute_storage": compute_storage,
    }


def get_len_iprange(start_ip, end_ip):
    network_start = ipaddress.ip_network(f"{start_ip}/32")
    network_end = ipaddress.ip_network(f"{end_ip}/32")
    end_ip_addr = network_end.broadcast_address
    total_ips = int(end_ip_addr) - int(network_start[0]) + 1
    return total_ips


# for ipxe
def count_dnsmasq(dnsmasq_log_path):
    starttag_count = 0
    try:
        with open(dnsmasq_log_path, "r") as file:
            for line in file:
                if "/tftp/ubuntu2204.cfg" in line:
                    starttag_count += 1
    except FileNotFoundError:
        print(f"Error: The file {dnsmasq_log_path} does not exist.")
        return -1
    return starttag_count


# generation monitor.txt temple
def generation_monitor_temple(iplist_path):
    try:
        with open(iplist_path, "r", encoding="utf-8") as original_file:
            lines = original_file.readlines()
    except FileNotFoundError:
        print(f"Error: The file {iplist_path} does not exist.")
        return 0

    # Create the header
    header = ["IP Serial_Number HostName Installing Disk IB GPU Finished log".split()]
    processed_lines = [
        [line.strip().split()[2], line.strip().split()[0], line.strip().split()[1]]
        + ["F", "F", "F", "F", "F", "click"]
        for line in lines
    ]
    monitor_data = header + processed_lines

    return monitor_data


def load_iplist(iplist_path):
    try:
        with open(iplist_path, "r") as file:
            lines = file.readlines()
        iplist = []
        for line in lines:
            parts = line.strip().split()
            iplist.append(
                {
                    "serial": parts[0],
                    "hostname": parts[1],
                    "ip": parts[2],
                    "gateway": parts[3],
                    "dns": parts[4],
                    "ipoib": parts[5],
                    "dockerip": parts[6],
                }
            )
        return iplist
    except FileNotFoundError:
        return None


def update_installing_status(monitor_data, serial_number, client_ip):
    found = False
    for i, line in enumerate(monitor_data):
        if i == 0:
            continue
        parts = line
        if parts[1] == serial_number:
            monitor_data[i][3] = "T"
            found = True
            return found, monitor_data
    node_serial = f"node{serial_number}"
    client_ip = f"{client_ip}/16"
    new_entry = [
        client_ip,
        serial_number,
        node_serial,
        "T",
        "F",
        "F",
        "F",
        "F",
        "click",
    ]
    return found, monitor_data.append(new_entry)


def update_diskstate(monitor_data, serial_number, diskstate):
    found = False
    for i, line in enumerate(monitor_data):
        if i == 0:
            continue
        parts = line
        if (
            parts[1] == serial_number
            and parts[4] == "F"
            or parts[4] == "W"
            or parts[4] == "M"
        ):

            if diskstate == "ok":
                monitor_data[i][4] = "T"
            elif diskstate == "nomatch":
                monitor_data[i][4] = "M"
            else:
                monitor_data[i][4] = "W"
            found = True

    return found, monitor_data


def update_ibstate(monitor_data, serial_number, ibstate):
    found = False
    for i, line in enumerate(monitor_data):
        if i == 0:
            continue
        parts = line
        if parts[1] == serial_number and parts[5] == "F" or parts[5] == "W":
            if ibstate == "ok":
                monitor_data[i][5] = "T"
            else:
                monitor_data[i][5] = "W"
            found = True
    return found, monitor_data


def update_gpustate(monitor_data, serial_number, gpustate):
    found = False
    for i, line in enumerate(monitor_data):
        if i == 0:
            continue
        parts = line

        if parts[1] == serial_number and (parts[6] == "F" or parts[6] == "W"):

            if gpustate == "ok":
                monitor_data[i][6] = "T"
            else:
                monitor_data[i][6] = "W"
            found = True

    return found, monitor_data


def update_finished_status(monitor_data, serial_number):
    found = False
    for i, line in enumerate(monitor_data):
        if i == 0:
            continue
        parts = line

        if parts[1] == serial_number and (parts[7] == "F" or parts[7] == "W"):
            monitor_data[i][7] = "T"
            found = True
    return found, monitor_data


def update_finished_ip(monitor_data, serial_number, client_ip):
    for i, line in enumerate(monitor_data):
        if i == 0:
            continue
        parts = line
        if parts[1] == serial_number:
            client_ip = f"{client_ip}/16"
            monitor_data[i][0] = client_ip
    return monitor_data


def update_logname(monitor_data, serial_number, logname):
    found = False
    for i, line in enumerate(monitor_data):
        if i == 0:
            continue
        parts = line
        if parts[1] == serial_number:
            monitor_data[i][8] = logname
            found = True
    return found, monitor_data


# Installation Timeout
def install_timeout(monitor_data):

    for i, line in enumerate(monitor_data):
        if i == 0:
            continue
        parts = line
        if parts[7] == "F":
            monitor_data[i][7] = "W"
            
    return monitor_data
