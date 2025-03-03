#!/bin/bash
cd $(dirname $0)
start_flask_app() {
        nohup  /root/podsys-core  > /dev/null 2>&1 &
}

ISO=ubuntu-22.04.5-live-server-amd64.iso
manager_ip=$(grep "manager_ip" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
manager_nic=$(grep "manager_nic" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
compute_storage=$(grep "compute_storage" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
compute_passwd=$(grep "compute_passwd" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
dhcp_s=$(grep "dhcp_s" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
dhcp_e=$(grep "dhcp_e" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')

echo -e "\033[43;31m "Welcome to the cluster deployment software v3.0.1"\033[0m"
echo "  ____     ___    ____    ____   __   __  ____  ";
echo " |  _ \   / _ \  |  _ \  / ___|  \ \ / / / ___| ";
echo " | |_) | | | | | | | | | \___ \   \ V /  \___ \ ";
echo " |  __/  | |_| | | |_| |  ___) |   | |    ___) |";
echo " |_|      \___/  |____/  |____/    |_|   |____/ ";
echo

echo -e "\033[31mdhcp-config : /etc/dnsmasq.conf\033[0m"
echo -e "\033[31muser-data   : /jammy/user-data\033[0m"

if [ "${download_mode}" == "p2p" ]; then
  nohup /root/opentracker > /dev/null 2>&1 &
  mkdir -p "/workspace/torrents"
  transmission-create -o /workspace/torrents/drivers.torrent -t http://${manager_ip}:6969/announce -p /workspace/drivers/
  chmod 755 -R /workspace/torrents
  nohup ctorrent -s /workspace/drivers /workspace/torrents/drivers.torrent > /dev/null 2>&1 &
  sleep 2s
fi

compute_encrypted_password=$(printf "${compute_passwd}" | openssl passwd -6 -salt 'FhcddHFVZ7ABA4Gi' -stdin)

################################ get /etc/dnsmasq.conf
dnsmasq_conf=$(cat << EOF
port=5353
interface=$manager_nic
bind-interfaces
dhcp-range=${dhcp_s},${dhcp_e},255.255.0.0,6h
dhcp-match=set:bios,option:client-arch,0
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-boot=tag:bios,pxelinux.0
dhcp-boot=tag:efi-x86_64,bootx64.efi
enable-tftp
tftp-root=/tftp/pxe_ubuntu2204
log-facility=/workspace/log/dnsmasq.log
log-queries
log-dhcp
EOF
)

dnsmasq_conf_ipxe=$(cat << EOF
port=5353
interface=$manager_nic
bind-interfaces
dhcp-range=${dhcp_s},${dhcp_e},255.255.0.0,12h
dhcp-match=set:bios,option:client-arch,0
dhcp-match=set:x64-uefi,option:client-arch,7
dhcp-match=set:x64-uefi,option:client-arch,9
dhcp-match=set:ipxe,175
dhcp-boot=tag:bios,undionly.kpxe
dhcp-boot=tag:x64-uefi,snponly.efi
dhcp-boot=tag:ipxe,ubuntu2204.cfg
enable-tftp
tftp-root=/tftp/ipxe_ubuntu2204
log-facility=/workspace/log/dnsmasq.log
log-queries
log-dhcp
EOF
)

################################ get grub.cfg
grub_cfg=$(cat << EOF
set default="1"
set timeout=5

#if loadfont unicode ; then
#  set gfxmode=auto
#  set locale_dir=\$prefix/locale
#  set lang=en_US
#fi
terminal_output gfxterm

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray
if background_color 44,0,30; then
  clear
fi

function gfxmode {
        set gfxpayload="\${1}"
        if [ "\${1}" = "keep" ]; then
                set vt_handoff=vt.handoff=7
        else
                set vt_handoff=
        fi
}

set linux_gfx_mode=keep
export linux_gfx_mode

menuentry 'Ubuntu 22.04.5 autoinstall' {
        gfxmode \$linux_gfx_mode
        linux /vmlinuz \$vt_handoff root=/dev/ram0 ramdisk_size=2000000 ip=dhcp url=http://${manager_ip}:5000/workspace/${ISO} autoinstall ds=nocloud-net\;s=http://${manager_ip}:5000/jammy/ ---
        initrd /initrd
}
EOF
)

pxelinux_cfg_default=$(cat << EOF
DEFAULT menu.c32
MENU TITLE ULTIMATE PXE SERVER - By Griffon - Ver 1.0
PROMPT 0
TIMEOUT 0

MENU COLOR TABMSG  37;40  #ffffffff #00000000
MENU COLOR TITLE   37;40  #ffffffff #00000000
MENU COLOR SEL      7     #ffffffff #00000000
MENU COLOR UNSEL    37;40 #ffffffff #00000000
MENU COLOR BORDER   37;40 #ffffffff #00000000

LABEL Ubuntu Server 22.04.5
    kernel /vmlinuz
    initrd /initrd
    append root=/dev/ram0 ip=dhcp ramdisk_size=2000000 url=http://${manager_ip}:5000/workspace/${ISO} autoinstall ds=nocloud-net;s=http://${manager_ip}:5000/jammy/  cloud-config-url=/dev/null
EOF
)

ipxe_ubuntu2204_cfg=$(cat << EOF
#!ipxe
set product-name ubuntu2204
set os-name ubuntu2204

set menu-timeout 1000
set submenu-timeout \${menu-timeout}
set menu-default exit

:start
menu boot from iPXE server
item --gap --             --------------------------------------------
item --gap -- serial:\${serial}
item --gap -- mac:\${mac}
item --gap -- ip:\${ip}
item --gap -- netmask:\${netmask}
item --gap -- gateway:\${gateway}
item --gap -- dns:\${dns}
item
item --gap --             --------------------------------------------
item install-os \${product-name}
choose --timeout \${menu-timeout} --default \${menu-default} selected || goto cancel
goto \${selected}

:install-os
set server http://${manager_ip}:5000/
initrd \${server}jammy/initrd
kernel \${server}jammy/vmlinuz initrd=initrd ip=dhcp url=\${server}workspace/${ISO} autoinstall ds=nocloud-net;s=\${server}jammy/ root=/dev/ram0 cloud-config-url=/dev/null
boot
EOF
)


if [ "$mode" = "ipxe_ubuntu2204" ]; then
   echo "$dnsmasq_conf_ipxe" > /etc/dnsmasq.conf
   echo "$ipxe_ubuntu2204_cfg" > /tftp/ipxe_ubuntu2204/ubuntu2204.cfg
elif [ "$mode" = "pxe_ubuntu2204" ]; then
   echo "$dnsmasq_conf"        > /etc/dnsmasq.conf
   echo "$grub_cfg"            > /tftp/pxe_ubuntu2204/grub/grub.cfg
   echo "$pxelinux_cfg_default"   > /tftp/pxe_ubuntu2204/pxelinux.cfg/default
   cp /jammy/vmlinuz /tftp/pxe_ubuntu2204/vmlinuz
   cp /jammy/initrd   /tftp/pxe_ubuntu2204/initrd
else
   echo "$dnsmasq_conf_ipxe" > /etc/dnsmasq.conf
   echo "$ipxe_ubuntu2204_cfg" > /tftp/ipxe_ubuntu2204/ubuntu2204.cfg
fi

if [ -s /workspace/mac_ip.txt ]; then
    echo "dhcp-ignore=tag:!known" >> /etc/dnsmasq.conf
    echo "dhcp-hostsfile=/workspace/mac_ip.txt" >> /etc/dnsmasq.conf
fi

################################### get user-data
userdata=$(cat << EOF
#cloud-config
autoinstall:
  version: 1
  updates: security
  apt:
    disable_components: []
    geoip: true
    fallback: continue-anyway
    preserve_sources_list: false
    primary:
    - arches:
      - amd64
      - i386
      uri: http://archive.ubuntu.com/ubuntu
    - arches:
      - default
      uri: http://ports.ubuntu.com/ubuntu-ports
  drivers:
    install: false
  kernel:
    package: linux-generic
  keyboard:
    layout: us
    toggle: null
    variant: ''
  locale: en_US.UTF-8
  network:
    ethernets:
      nic:
        dhcp4: true
    version: 2
  source:
    id: ubuntu-server
    search_drivers: false
  identity:
    hostname: nexus
    password: ${compute_encrypted_password}
    realname: nexus
    username: nexus
  ssh:
    allow-pw: true
    authorized-keys: [${NEW_PUB_KEY}]
    install-server: true
  early-commands:
    - echo "${NEW_PUB_KEY}" >/root/.ssh/authorized_keys
    - wget http://${manager_ip}:5000/jammy/preseed.sh && chmod 755 preseed.sh && bash preseed.sh ${manager_ip} ${compute_storage}
  late-commands:
    - cp /etc/netplan/00-installer-config.yaml /target/etc/netplan/00-installer-config.yaml
    - mkdir /target/root/.ssh && echo "${NEW_PUB_KEY}" >/target/root/.ssh/authorized_keys
    - wget http://${manager_ip}:5000/jammy/preseed1.sh && chmod 755 preseed1.sh && bash preseed1.sh ${manager_ip} ${download_mode}
    - curtin in-target --target=/target -- wget http://${manager_ip}:5000/jammy/install.sh
    - curtin in-target --target=/target -- chmod 755 install.sh || true
    - curtin in-target --target=/target -- /install.sh ${manager_ip} ${download_mode}
    - umount /target/podsys || true
    - rm -f  /target/install.sh || true
    - cp /autoinstall.yaml /target/podsys/autoinstall.yaml || true
    - reboot
  storage:
    swap:
        size: 0
    grub:
        reorder_uefi: false
    config:
    - ptable: gpt
      path: /dev/${compute_storage}
      wipe: superblock-recursive
      preserve: false
      name: ''
      grub_device: false
      type: disk
      id: disk-${compute_storage}
    - device: disk-${compute_storage}
      size: 1127219200
      wipe: superblock
      flag: boot
      number: 1
      preserve: false
      grub_device: true
      offset: 1048576
      type: partition
      id: partition-0
    - fstype: fat32
      volume: partition-0
      preserve: false
      type: format
      id: format-0
    - device: disk-${compute_storage}
      size: 2147483648
      wipe: superblock
      number: 2
      preserve: false
      grub_device: false
      offset: 1128267776
      type: partition
      id: partition-1
    - fstype: ext4
      volume: partition-1
      preserve: false
      type: format
      id: format-1
    - device: disk-${compute_storage}
      size: -1
      wipe: superblock
      number: 3
      preserve: false
      grub_device: false
      offset: 3275751424
      type: partition
      id: partition-2
    - name: ubuntu-vg-1
      devices:
      - partition-2
      preserve: false
      type: lvm_volgroup
      id: lvm_volgroup-0
    - name: ubuntu-lv
      volgroup: lvm_volgroup-0
      size: -1
      wipe: superblock
      preserve: false
      type: lvm_partition
      id: lvm_partition-0
    - fstype: ext4
      volume: lvm_partition-0
      preserve: false
      type: format
      id: format-2
    - path: /
      device: format-2
      type: mount
      id: mount-2
    - path: /boot
      device: format-1
      type: mount
      id: mount-1
    - path: /boot/efi
      device: format-0
      type: mount
      id: mount-0
EOF
)
echo -e "$userdata" >> /jammy/user-data

########################################start server
echo
sleep 1
echo "starting services: "
service dnsmasq start
echo
sleep 1
echo "checking services: "
service dnsmasq status
echo
chmod 755 -R /workspace/log
start_flask_app