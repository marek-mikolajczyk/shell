#!/bin/ksh

 

# read lpar, vios1, vios2 from input

 

echo "give lpar"

read lpar

echo "give 1st vios"

read vios1

echo "give 2nd vios"

read vios2

 

echo "you choosen lpar $lpar and vioses $vios1 $vios2"

echo "gathering info, in progress..."

echo "" > reclaim_storage_"$lpar".log

 

 

# dump current config

//(customssh)// -w $vios1,$vios2 "su - padmin -c ioscli lsmap -all | grep -p $lpar" > "$lpar"_dump_before_action.log && echo "dump current config OK"

# dump vio1 target and backing devices

//(customssh)// -w $vios1 "su - padmin -c ioscli lsmap -all | grep $lpar" | awk '{print $3}' > reclaim_storage_"$lpar"_"$vios1"_target.log

//(customssh)// -w $vios1 "su - padmin -c ioscli lsmap -all | grep -p $lpar | grep Backing " |  awk '{print $4}' > reclaim_storage_"$lpar"_"$vios1"_backing.log && echo "dump 1st vios target and backing devices"

# dump vio2 target and backing devices

//(customssh)// -w $vios2 "su - padmin -c ioscli lsmap -all | grep $lpar" | awk '{print $3}' >  reclaim_storage_"$lpar"_"$vios2"_target.log

//(customssh)// -w $vios2 "su - padmin -c ioscli lsmap -all | grep -p $lpar | grep Backing " |  awk '{print $4}' > reclaim_storage_"$lpar"_"$vios2"_backing.log && echo "dump 2nd vios target and back

ing devices"

 

# prepare lun id list for storage team

echo "" > message_to_san_team_"$lpar".log

 

 

echo "showing dump info"

cat "$lpar"_dump_before_action.log

echo "==========================="

echo "===VIOS 1=================="

echo "==========================="

 

echo "will delete following target and backing devices on $vios1 :"

cat reclaim_storage_"$lpar"_"$vios1"_target.log

echo "==========================="

cat reclaim_storage_"$lpar"_"$vios1"_backing.log

echo "==========================="

 

echo "do you want to delete those target devices on $vios1? (yes/no)"

read answer1

 

if [ $answer1 = "yes" ] ; then

        echo "deleting target devices on $vios1" | tee -a reclaim_storage_"$lpar".log

                for i in `cat reclaim_storage_"$lpar"_"$vios1"_target.log` ; do

                        //(customssh)// -w "$vios1" "uname -L ; su - padmin -c ioscli rmvdev -vtd $i"

                        echo "target device $i deleted from $vios1"  | tee -a reclaim_storage_"$lpar".log

                done

else

        exit

fi

 

 

# 1. remove backing device from 1st vio

# 3. list of LUN created for storage team

 

 

echo "do you want to delete those hdisks from $vios1? (yes/no)"

read answer2

 

if [ $answer1 = "yes" ] ; then

        echo "deleting hdisk devices on $vios1" | tee -a reclaim_storage_"$lpar".log

        echo "$vios1" >> message_to_san_team_"$lpar".log

        for i in `cat reclaim_storage_"$lpar"_"$vios1"_backing.log` ; do

                //(customssh)// -w $vios1 "pcmpath query device | grep -p "$i[[:space:]]" | grep SERIAL " | awk -F": " '{print $3}' >> message_to_san_team_"$lpar".log

                //(customssh)// -w "$vios1" "uname -L ; rmdev -dl $i"

                echo "$i removed from $vios1" | tee -a reclaim_storage_"$lpar".log

        done

else

        exit

fi

 

echo "==========================="

echo "===VIOS 2=================="

echo "==========================="

 

echo "will delete following target and backing devices on $vios2 :"

cat reclaim_storage_"$lpar"_"$vios2"_target.log

echo "==========================="

cat reclaim_storage_"$lpar"_"$vios2"_backing.log

echo "==========================="

 

echo "do you want to delete those target devices on $vios2? (yes/no)"

read answer1

 

if [ $answer1 = "yes" ] ; then

        echo "deleting target devices on $vios2" | tee -a reclaim_storage_"$lpar".log

                for i in `cat reclaim_storage_"$lpar"_"$vios2"_target.log` ; do

                        //(customssh)// -w "$vios2" "uname -L ; su - padmin -c ioscli rmvdev -vtd $i"

                        echo "target device $i deleted from $vios2"  | tee -a reclaim_storage_"$lpar".log

                done

else

        exit

fi

 

 

# 1. remove backing device from 1st vio

# 2. list of LUN created for storage team

 
 

echo "do you want to delete those hdisks from $vios2? (yes/no)"

read answer2

 

if [ $answer1 = "yes" ] ; then

        echo "deleting hdisk devices on $vios2" | tee -a reclaim_storage_"$lpar".log

        echo "$vios2" >> message_to_san_team_"$lpar".log

        for i in `cat reclaim_storage_"$lpar"_"$vios2"_backing.log` ; do

                //(customssh)// -w $vios2 "pcmpath query device | grep -p "$i[[:space:]] " | grep SERIAL " | awk -F": " '{print $3}' >> message_to_san_team_"$lpar".log

               //(customssh)// -w "$vios2" "uname -L ; rmdev -dl $i"

                echo "$i removed from $vios2" | tee -a reclaim_storage_"$lpar".log

        done

else

        exit

fi

