#!/usr/bin/ksh93

 

########################### get lpar,vioses
echo 'give lpar (ax1035)'
read LPAR
echo 'give lunids (6C09 6C0A 6C0B)'
read LUN
LUN_AMOUNT=`echo $LUN | wc -w`
echo 'give storage box (75VR771)'
read BOX

counter_lun=0
for i in $LUN; do
  ARRAY_LUNS[$counter_lun]=$BOX$i
  counter_lun=$(( $counter_lun + 1 ))
done

 

echo "ARRAY_LUNS[*] is ${ARRAY_LUNS[*]}"
# get vioses
#ssh $LPAR /repos/home/mikolm/get_vscsi_info.sh
#vscsi0 ax1079 vhost2
#vscsi1 ax1080 vhost2

echo "now checking vioses and vhosts"
ARRAY_VIOSES=( $( ssh $LPAR /home/marek/get_vscsi_info.sh | awk '{print $2}' ) )
echo "ARRAY_VIOSES[0] is ${ARRAY_VIOSES[0]}"
echo "ARRAY_VIOSES[1] is ${ARRAY_VIOSES[1]}"
 
ARRAY_VHOSTS=( $( ssh $LPAR /home/get_vscsi_info.sh | awk '{print $3}' ) )
echo "ARRAY_VHOSTS[0] is ${ARRAY_VHOSTS[0]}"
echo "ARRAY_VHOSTS[1] is ${ARRAY_VHOSTS[1]}"


echo 'Proceed (y/n)?'
read ANSWER
if [[ $ANSWER == "n" ]]; then
  exit
fi


#################################################### START vioses_cfgmgr_get_hdisk ##############################################

vioses_cfgmgr_get_hdisk()
{
echo 'do you want to discover devices on vioses? (yes/no/exit)'
read ANSWER
if [[ $ANSWER == "yes" ]]; then
        #1st vios
        //(customssh)// -w ${ARRAY_VIOSES[0]} "cfgmgr"
        #2nd vios
        //(customssh)// -w ${ARRAY_VIOSES[1]} "cfgmgr"
elif [[ $ANSWER == "no" ]]; then
        echo "Proceeding without scan"
elif [[ $ANSWER == "exit" ]]; then
        exit
fi

counter_hdisk=0
for j in ${ARRAY_LUNS[*]}; do
  echo "Checking for disks "
  //(customssh)// -w ${ARRAY_VIOSES[0]} "pcmpath query device | grep -p $j ; lspv -u | grep $j "

  # SAFE ADMIN CHECK
  echo "Checking if lun is closed state"
  //(customssh)// -w ${ARRAY_VIOSES[0]} "pcmpath query device | grep -p $j" | grep OPEN && echo "WARNING $j in open state !!!"  || echo "$j in closed state"
  echo "Checking if lun already has pvid"
  //(customssh)// -w ${ARRAY_VIOSES[0]} "lspv -u | grep $j" | grep none  && echo "OK, $j has no pvid" || echo "WARNING: $j already has pvid"

  ARRAY_HDISK_VIOS_0[$counter_hdisk]=`/work/ddsh_vios -w ${ARRAY_VIOSES[0]} "pcmpath query device | grep -p $j | grep hdisk "| awk '{print $6}'`
  echo "$j on ${ARRAY_VIOSES[0]} is ${ARRAY_HDISK_VIOS_0[$counter_hdisk]}"
  counter_hdisk=$(( $counter_hdisk + 1 ))
done

 
counter_hdisk=0
for j in ${ARRAY_LUNS[*]}; do
  //(customssh)// -w ${ARRAY_VIOSES[1]} "pcmpath query device | grep -p $j ; lspv -u | grep $j "
  # SAFE ADMIN CHECK
  echo "Checking if lun is closed state"
  //(customssh)// -w ${ARRAY_VIOSES[1]} "pcmpath query device | grep -p $j" | grep OPEN && echo "$j in open state !!!" && exit || echo "$j in closed state"
  echo "Checking if lun already has pvid"
  //(customssh)// -w ${ARRAY_VIOSES[1]} "lspv -u | grep $j" | grep none  && echo "OK, $j has no pvid" || echo "WARNING: $j already has pvid"
  ARRAY_HDISK_VIOS_1[$counter_hdisk]=`/work/ddsh_vios -w ${ARRAY_VIOSES[1]} "pcmpath query device | grep -p $j | grep hdisk "| awk '{print $6}'`
  echo "$j on ${ARRAY_VIOSES[1]} is ${ARRAY_HDISK_VIOS_1[$counter_hdisk]}"
  counter_hdisk=$(( $counter_hdisk + 1 ))
done

 

echo '####################################################'
echo "Summary"
echo '####################################################'
echo "Disks on ${ARRAY_VIOSES[0]} are ${ARRAY_HDISK_VIOS_0[*]}"
echo "Disks on ${ARRAY_VIOSES[1]} are ${ARRAY_HDISK_VIOS_1[*]}"
echo '####################################################'

}

 

 

#################################################### END vioses_cfgmgr_get_hdisk ##############################################

#################################################### START make_pvid ##############################################

 

make_pvid ()
{
echo "Let's make pvid on them. proceed? (y/n)"
read ANSWER_PVID
if [[ $ANSWER_PVID == "n" ]]; then
  exit
fi

echo "making pvid on ${ARRAY_VIOS[0]} for disks ${ARRAY_HDISK_VIOS_0[*]}"
  for i in ${ARRAY_HDISK_VIOS_0[*]}; do
  //(customssh)// -w ${ARRAY_VIOSES[0]} "chdev -l $i -a pv=yes"
done


echo "making pvid on ${ARRAY_VIOS[0]} for disks ${ARRAY_HDISK_VIOS_1[*]}"
  for i in ${ARRAY_HDISK_VIOS_1[*]}; do
  //(customssh)// -w ${ARRAY_VIOSES[1]} "chdev -l $i -a pv=yes"
done
}

#################################################### end function make_pvid ####################################################

#################################################### start function target_vios1 ####################################################

 

target_vios1()
{
##########################  target disk numbers may be  incremented by 1 or 2, check it

i=0
for j in ${ARRAY_HDISK_VIOS_0[*]}; do
  ARRAY_INCREMENT=( $( //(customssh)// -w ${ARRAY_VIOSES[$i]} "su - padmin -c ioscli lsmap -vadapter ${ARRAY_VHOSTS[$i]} | grep $LPAR | tail -2" | awk '{print $3}' ) )
  echo "one before last is ${ARRAY_INCREMENT[0]} and last is ${ARRAY_INCREMENT[1]}"
  CALCUL[0]=`echo ${ARRAY_INCREMENT[0]} | awk -F"_" '{print $3}'`
  CALCUL[1]=`echo ${ARRAY_INCREMENT[1]} | awk -F"_" '{print $3}'`
  DIFFERENCE=$(( ${CALCUL[1]} - ${CALCUL[0]} ))
  echo "DIFFERENCE is $DIFFERENCE"

  LATEST=`//(customssh)// -w ${ARRAY_VIOSES[$i]} "su - padmin -c ioscli lsmap -vadapter ${ARRAY_VHOSTS[$i]} | grep $LPAR | tail -1" | awk '{print $3}'`
  echo "LATEST target device on ${ARRAY_VIOSES[$i]} is $LATEST"
  DSK[0]=`echo $LATEST | awk -F"_" '{print $1"_"$2}'`
  DSK[1]=`echo $LATEST | awk -F"_" '{print $3}'`
  DSK[2]=$((${DSK[1]} + $DIFFERENCE))
  NEWEST=`echo ${DSK[0]}_${DSK[2]}`
  echo "new target device on vios ${ARRAY_VIOSES[$i]} will be named $NEWEST"

  echo 'proceed to make target device? (y/n)'
  read ANSWER
  if [[ $ANSWER == "n" ]] ; then
    exit
  fi

  echo "will connect to ${ARRAY_VIOSES[$i]} and make $NEWEST on device $j on adapter ${ARRAY_VHOSTS[$i]}"
  //(customssh)// -w ${ARRAY_VIOSES[$i]} "su - padmin -c ioscli mkvdev -vdev $j -dev $NEWEST -vadapter ${ARRAY_VHOSTS[$i]}"
  echo 'proceed with next disk?? (y/n)'
  read ANSWER
  if [[ $ANSWER == "n" ]] ; then
    exit
  fi
done
}

#################################################### end function target_vios1 ####################################################

 

#################################################### start function target_vios2 ####################################################

target_vios2()

{
i=1
##########################  target disk numbers may be  incremented by 1 or 2, check it

for j in ${ARRAY_HDISK_VIOS_1[*]}; do

  ARRAY_INCREMENT=( $( //(customssh)// -w ${ARRAY_VIOSES[$i]} "su - padmin -c ioscli lsmap -vadapter ${ARRAY_VHOSTS[$i]} | grep $LPAR | tail -2" | awk '{print $3}' ) )
  echo "one before last is ${ARRAY_INCREMENT[0]} and last is ${ARRAY_INCREMENT[1]}"
  CALCUL[0]=`echo ${ARRAY_INCREMENT[0]} | awk -F"_" '{print $3}'`
  CALCUL[1]=`echo ${ARRAY_INCREMENT[1]} | awk -F"_" '{print $3}'`
  DIFFERENCE=$(( ${CALCUL[1]} - ${CALCUL[0]} ))
  echo "DIFFERENCE is $DIFFERENCE"
  LATEST=`//(customssh)// -w ${ARRAY_VIOSES[$i]} "su - padmin -c ioscli lsmap -vadapter ${ARRAY_VHOSTS[$i]} | grep $LPAR | tail -1" | awk '{print $3}'`
  echo "LATEST target device on ${ARRAY_VIOSES[$i]} is $LATEST"
  DSK[0]=`echo $LATEST | awk -F"_" '{print $1"_"$2}'`
  DSK[1]=`echo $LATEST | awk -F"_" '{print $3}'`
  DSK[2]=$((${DSK[1]} + $DIFFERENCE))
  NEWEST=`echo ${DSK[0]}_${DSK[2]}`
  echo "new target device on vios ${ARRAY_VIOSES[$i]} will be named $NEWEST"
  echo 'proceed to make target device? (y/n)'
  read ANSWER
  if [[ $ANSWER == "n" ]] ; then
    exit
  fi
  echo "will connect to ${ARRAY_VIOSES[$i]} and make $NEWEST on device $j on adapter ${ARRAY_VHOSTS[$i]}"
  //(customssh)// -w ${ARRAY_VIOSES[$i]} "su - padmin -c ioscli mkvdev -vdev $j -dev $NEWEST -vadapter ${ARRAY_VHOSTS[$i]}"
  echo 'proceed with next disk?? (y/n)'
  read ANSWER
  if [[ $ANSWER == "n" ]] ; then
    exit
  fi
done
}

#################################################### START ! ##################################################
vioses_cfgmgr_get_hdisk
make_pvid
target_vios1
target_vios2

