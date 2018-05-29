## this script removes mksysb images from local directory if image was backed up by tsm
## transform 'ls -l' date format to match 'dsmc' date format
## check if image was backed up:
##  file date next day
##  file date same day but later hour
## script works in manual mode or auto mode





# syntax: check_backup.ksh <object> [-m]

 
 
#!/bin/ksh

# check_backup.ksh MKSYSBaix1 -m

# file date:      03/17/18 19:19:19

# backup date:    03/18/18 12:47:18

# tsm made copy next day(s) - can be removed

# QUESTION is -m

# delete ?

# y

# WILL remove after confirmation

# check_backup.ksh MKSYSBaix1 -a

# file date:      03/17/18 19:19:19

# backup date:    03/18/18 12:47:18

# tsm made copy next day(s) - can be removed

# QUESTION is -a

# WILL remove automatically

 

 

 

 

# some variables defs

dir='/mksysb/images'

CURRENTMONTH=`date | awk '{print $2}'`

IMAGE="$1"

QUESTION="$2"

 

# some date format converting

case "$CURRENTMONTH" in

  "Mar" ) CURRENTMONTHDIGIT="03"

  "Apr" ) CURRENTMONTHDIGIT="04"

  ;;

esac

DATETRANSFORMED=`istat "$dir"/"$IMAGE" | grep 'Last modified:' | awk '{print $4"\/"$5"\/"$8" "$6}' |sed 's/2018/18/'`

DATETRANSFORMEDTOOUTOUT=`echo $DATETRANSFORMED | sed "s:"$CURRENTMONTH":"$CURRENTMONTHDIGIT":"`

 

remove() {

rm  "$dir/$IMAGE" && echo ""$IMAGE" deleted "

}

 

ask() {

echo "QUESTION is $QUESTION"

if [ "$QUESTION" ==  '-m' ]; then

        echo "delete ?"

        read ANSWER

        if [ "$ANSWER" = "y" ]; then

                echo "manual remove"

        fi

elif [ "$QUESTION" ==  '-a' ]; then

        echo "auto remove"

fi

}

 

 

 

 

### display to stdout comparision of file date and tsm date ###

 

FILEDATE=`echo $DATETRANSFORMEDTOOUTOUT| sed "s/"$CURRENTMONTH"/"$CURRENTMONTHDIGIT"/"`

echo "file date:\t$FILEDATE"

TSMDATE=`dsmc q ba "$dir"/"$IMAGE" | grep $IMAGE |  awk '{print $3" "$4}'`

echo "backup date:\t$TSMDATE"

 

 

 

### get some more variables for comparing dates ###

 

HOURFILEDATE=`echo $FILEDATE | awk '{print $2}' | awk -F":" '{print $1}'`

HOURTSMDATE=`echo $TSMDATE | awk '{print $2}' | awk -F':' '{print $1}'`

DAYFILEDATE=`echo $FILEDATE | awk '{print $1}' | awk -F'/' '{print $2}'`

DAYTSMDATE=`echo $TSMDATE | awk '{print $1}' | awk -F'/' '{print $2}'`

 

if [ "$DAYFILEDATE" >  "$DAYTSMDATE" ]; then

        echo "tsm made copy next day(s) - can be removed"

         ask

elif [ "$DAYFILEDATE" =  "$DAYTSMDATE" ]; then

        echo "tsm made copy same day"

                if [ $HOURTSMDATE > $HOURFILEDATE ]; then

                        echo "tsm copy same day but later hour - can be removed"

                        ask

                fi

fi

