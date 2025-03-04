cd $(dirname $0)
service dnsmasq stop
rm -f /etc/dnsmasq.conf
rm /workspace/log/dnsmasq.log

umount /iso

rm -f /tftp/ubuntu2404.cfg
rm -f /user-data/user-data

rm -f /var/log/*.log
rm -f /var/log/apt/eipp.log.xz
rm -f /var/log/apt/*.log

rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

rm .viminfo
rm -rf /tmp/* /var/tmp/*
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/*

cat /dev/null > ~/.bash_history

ps aux | grep podsys-core