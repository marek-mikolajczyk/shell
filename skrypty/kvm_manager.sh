#!/bin/bash 

function giveip {
for i in `virsh domiflist $GUEST| grep '52:54:00' | awk '{print $5}'`; do 
	arp -a | grep $i  | cut -d " " -f 2 | sed -e 's/(//' -e 's/)//'
done
}

function givedisks {
for i in `virsh domblklist $GUEST | grep '/'  | awk '{print $2}'`; do 
	virsh vol-info $i
done
}

function givememory {
echo $((`virsh dommemstat $GUEST | grep actual | awk '{print $2}'`/1024))
}
echo "Hello, what you want do do?"
echo '1. show guest IP'
echo '2. show guest STORAGE'
echo '3. show guest MEMORY'
read ANSWER1

if [ $# = 0 ]; then
virsh list --all
echo "which host?"
read GUEST
else
GUEST=$1
fi

case "$ANSWER1" in
	1)  giveip  ;;
	2)  givedisks ;; 
	3)  givememory ;; 
esac
