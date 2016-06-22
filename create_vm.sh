#!/bin/bash

# obligatory variables
# $1 = new hostname
if [ -z $1 ]; then
echo '$1 = hostname'
exit
fi

# create variables
LASTIP=`grep -P 192.168.122.[0-9][0-9]"\t" /etc/hosts | awk '{print $1}' | awk -F"." '{print $4}' | tail -1` 
NEWIP=$((`grep -P 192.168.122.[0-9][0-9]"\t" /etc/hosts | awk '{print $1}' | awk -F"." '{print $4}' | tail -1` + 1))

# /etc/hosts - backup and add entry

grep $1 /etc/hosts && echo "entry exists, exit" && exit || continue
cp -p /etc/hosts /etc/hosts.`date +%y%m%d`
sed -i -e "/$LASTIP/a 192.168.122.$NEWIP\t$1 $1.example.com" /etc/hosts


# create templates: kvm script and kickstart
mkdir "$1"
sed "s/NAME/$1/g" create_TEMPLATE.sh > "$1"/create_"$1".sh
chmod u+x "$1"/create_"$1".sh
sed -e "s/NAME/$1/g" -e "s/IP/$NEWIP/g" ks-TEMPLATE.cfg > /var/www/html/C7/ks-"$1".cfg | tee "$1"/ks-"$1".cfg


## launch installation

"$1"/create_"$1".sh

### add client to nagios


# delete already existing
rm -f /etc/nagios/servers/"$1".cfg

## start creating host template - host definition
iphost=`grep $1 /etc/hosts | awk '{print $1}'`

echo "define host{" > to_monitor_"$1"
echo "        use                     linux-server",host-pnp >> to_monitor_"$1"
echo "        host_name               "$1"" >> to_monitor_"$1"
echo "        alias                   "$1"" >> to_monitor_"$1"
echo "        address                 "$iphost"" >> to_monitor_"$1"
echo "        }" >> to_monitor_"$1"

## add standard monitors: ping

echo "define service{" >> to_monitor_"$1"
echo "        use                     generic-service,srv-pnp" >> to_monitor_"$1"
echo "        host_name               "$1"" >> to_monitor_"$1"
echo "        service_description      PING" >> to_monitor_"$1"
echo "        check_command            check_ping!100.0,20%!500.0,60%" >> to_monitor_"$1"
echo "        }" >> to_monitor_"$1"

## add standard monitors: ressources

for resource in check_load root_disk check_mem; do
echo "define service{" >> to_monitor_"$1"
echo  "       use                               generic-service,srv-pnp"  >> to_monitor_"$1"
echo "        host_name                       "$1"" >> to_monitor_"$1"
echo "        service_description             "$resource"" >> to_monitor_"$1"
echo "        check_command                   check_nrpe!"$resource"" >> to_monitor_"$1"
echo "        }" >> to_monitor_"$1"
done

mv to_monitor_"$1" "$1"/to_monitor_"$1"
cat "$1"/to_monitor_"$1" > /etc/nagios/servers/"$1".cfg
#nagios -v /etc/nagios/nagios.cfg && systemctl restart nagios

systemctl restart nagios

## disable monitoring for 10 min
/usr/bin/printf "[%lu] DISABLE_HOST_CHECK;$1\n" `date +%s`  > /var/spool/nagios/cmd/nagios.cmd
/usr/bin/printf "[%lu] ENABLE_HOST_NOTIFICATIONS;$1\n" `date +%s --date "now + 10 min"`  > /var/spool/nagios/cmd/nagios.cmd
#[1466332337] EXTERNAL COMMAND: DISABLE_HOST_CHECK;block1


