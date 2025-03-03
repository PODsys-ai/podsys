cd $(dirname $0)
service dnsmasq stop
rm -f /etc/dnsmasq.conf
rm /workspace/log/dnsmasq.log

rm -f /tftp/pxe_ubuntu2204/pxelinux.cfg/default
rm -f /tftp/pxe_ubuntu2204/grub/grub.cfg
rm -f /tftp/pxe_ubuntu2204/vmlinuz
rm -f /tftp/pxe_ubuntu2204/initrd

rm -f /tftp/ipxe_ubuntu2204/ubuntu2204.cfg
rm -f /jammy/user-data

rm -f /var/log/dpkg.log
rm -f /var/log/apt/eipp.log.xz
rm -f /var/log/apt/history.log
rm -f /var/log/apt/term.log
rm .viminfo
rm -rf /tmp/*
cat /dev/null > ~/.bash_history

ps aux | grep podsys-core