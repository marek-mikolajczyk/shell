#!/usr/bin/ksh93

echo "\n"

 

usesummarymode () {

        if [[ "$summarymode" = "1" ]]; then

                exit

        elif [[ "$summarymode" = "0"  ]]; then

                continue

        fi

        }

 

checkclusterlv () {

        isvgconcurrent=`echo $fsvg | grep 'VG Mode'  | awk '{print $3}'`

        if [[ "$isvgconcurrent" = "Concurrent" ]]; then

                vgconcurrent=1

                echo "WARNING: this is node of HACMP cluster"

                echo "WARNING: script not yet adjusted for HACMP cluster - contact UNIX team to resize"

                exit

        else

                echo "FS not in cluster"

                vgconcurrent=0

                continue

        fi

        }

 

checkmirrorlv () {

 

        islvmirrored=`lslv $fslv | grep COPIES  |awk '{print $2}'`

        if [[ "$islvmirrored" > 1 ]]; then

                lvmirrored=1

                echo "WARNING: script not yet adjusted for mirrored LV - contact UNIX team to resize"

                exit

        else

                echo "FS not mirrored"

                lvmirrored=0

                continue

        fi

        }

 

sendemailtounix ()  {

        echo "$inputfs resized via oracle_fs.ksh on `hostname` - $dbaanswer GB added" | mailx -s "[oracle_fs] `hostname` $inputfs" user1@mail1 user2@mail2

        }

 

usageinfotounix ()  {

        echo "script used on `hostname` $* "  | mailx -s "[oracle_fs] `hostname` $inputfs" user1@mail1 user2@mail2

        }

 

extendthelv () {

        currentlplimit=`lslv $fslv | grep 'MAX LPs:'  | awk '{print $3}'`

        lptoadd=$(( $dbaanswer * 1024 / $lvpp +50 ))

        currentlps=`lslv $fslv | grep '^LPs:' | awk '{print $2}'`

        newlplimit=$(( $currentlps + $lptoadd ))

 

        echo '============================================================================='

        echo "Checking MAX LP for LV:"

        echo '============================================================================='

        if [[ $currentlplimit < $newlplimit ]]; then

                echo "Current MAX LP limit too low, must be increased before resizing the FS"

                echo "when script ready, will execute following command:"

                echo "chlv -x $newlplimit $fslv"

                chlv -x $newlplimit $fslv

        else

                echo "MAX LP limit is enough to resize LV, proceeding with FS resize"

        fi

        }

 

 

resizethefs ()  {

 

        checkclusterlv

 

        checkmirrorlv

 

        if  [[ "$allow" = 1 ]]; then

                echo "$inputfs is `df -gP | grep $inputfs | awk '{print $2}'` GB, available space is $freesizeingb GB"

                echo "\n"

                echo "EXTEND FS - type 'value' to add in GB ; SHRINK FS - type '-value' to shrink in GB; EXIT - type 'exit'"

                read dbaanswer

                        if [[ $dbaanswer = "exit" ]]; then

                                exit

                        elif [[ "$dbaanswer" < 0 ]]; then

                                echo "dbaanswer is $dbaanswer and smaller than 0, will shrink fs"

                                # chfs -a size="$dbaanswer"G $inputfs

                        elif [[  "$dbaanswer" > 0 ]]; then

                                if  [[ "$dbaanswer" -gt "$freesizeingb" ]]; then

                                        echo "you want to add more space than available"

                                        exit

                                else

                                        if  [[ "$dbaanswer -le $freesizeingb" ]]; then

                                                        echo "DEBUG: you can extend the FS"

                                                        #extendthelv

                                                        echo '============================================================================='

                                                        echo "Resize FS:"

                                                        echo '============================================================================='

                                                        echo "when script ready, will execute following command:"

                                                       echo " chfs -a size=+"$dbaanswer"G $inputfs"

                                                        #chfs -a size=+"$dbaanswer"G $inputfs

                                                        sendemailtounix

                                        fi

                                fi

                        else

                                echo "try again"

                                exit

                        fi

        fi

        }

 

usageinfotounix

 

if  [ $# = 0 ]; then

 

        echo "usage:"

        echo '============================================================================='

        echo 'oracle_fs.ksh [ -h|-fs /PATH/ORACLE/mountpoint |-sid ABCD ] [ -s ]'

        echo '-h        display help'

        echo '-fs       point the filesystem'

        echo '-sid      point the sid'

        echo '-s        summary, display info only'

        echo "\n"

        exit

 

        exit

elif [ $1 = "-fs" ]; then

        fsorsid=fs

        inputfs=$2

elif [ $1 = "-sid" ]; then

        fsorsid=sid

        sid=$2

elif [ $1 = "-h" ]; then

        echo "usage:"

        echo '============================================================================='

        echo 'oracle_fs.ksh [ -h|-fs /PATH/ORACLE/mountpoint |-sid ABCD ] [ -s ]'

        echo '-h        display help'

        echo '-fs       point the filesystem'

        echo '-sid      point the sid'

        echo '-s        summary, display info only'

        echo "\n"

        exit

else

        exit

fi

 

 

if [ "$3" = "-s" ]; then

        summarymode=1

elif [[ -z $3 ]]; then

        summarymode=0

fi

 

 

echo "\n"

echo "version 1.0"

echo "- dba can query how much space can be added to fs - main functionality"

echo "- striped and non-striped filesystems"

echo "- mechanism for striped fs disk groups"

echo "\n"

echo "version 1.1"

echo "- dba admin can add space to filesystem up to available space (for now only shows command, still testing"

echo "- added allowed environments for resize"

echo "- added $1 parameters ( [-fs ] or [-sid] )"

echo "- added sendemail info to unix team ( after dba admin adds space, for now mail to mikolm )"

echo "- more clean df output with -sid"

echo "\n"

echo "version 1.2"

echo "- more testing with dba team"

echo "- added -s for summary only"

echo "- added to -sid to show main oracle fs by default"

echo "- fixed heared of df"

echo "- added modify MAX LPs if needed"

echo "- add functionality to shrink filesystem"

echo "- add check for cluster fs and mirro fs (this tool doesn't support it yet)"

echo "\n"

echo "to do:"

echo "more testing of 1.2 with dba team"

echo "\n"

echo "\n"

sleep 1

 

 

argresponse=$2

 

testenv=`df -g | grep "$argresponse" | grep -v Filesystem | awk '{print $7}' | head -1 | awk -F'/' '{print $2}'`

showfs=`df -g | grep -e Free -e "$argresponse"`

case $testenv in

        DEV)

                allow=1

                ;;

        TST)

                allow=1

                ;;

        TGT)

                allow=1

                ;;

        GTU)

                allow=1

                ;;

        UAT)

                allow=1

                ;;

        PTP)

                allow=1

                ;;

        PRD)

                allow=0

                ;;

esac

 

echo "============================================================================="

 

if [[ $allow = 1 ]]; then

        echo "INFO: $testenv - query and resize allowed"

        #sendemailtounix

else

        echo "INFO: $testenv not allowed - you may only query"

        #sendemailtounix

        exit

fi

 

 

if  [[ $fsorsid = sid ]]; then

        echo "============================================================================="

        # AA04"

        df -gP | grep Available |  awk '{printf("%+40s \t%+8s \t%+8s \t%+4s %+11s \t%+4s %+2s \n",$1,$2,$4,$5,$6,$7,$8)}'

        df -gP | grep  $sid | awk '{printf("%+40s \t%+8s\t%+8s \t%+4s\t%+8s \t%+4s \n",$1,$2,$3,$4,$5,$6)}'

        #df -gP | grep -e Free -e $sid |  awk '{printf("%+20s %+8s\t%+8s %+4s\t%+8s %+4s %.20s %s %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9)}'

        echo "\n"

        df -gP  |grep -i '/PATH/ORACLE/mountpoint ' | awk '{printf("%+40s \t%+8s\t%+8s \t%+4s\t%+8s \t%+4s \n",$1,$2,$3,$4,$5,$6)}'

        echo "\n"

        usesummarymode

        echo "\n"

        echo  "give fs to resize (ex. aix1: /PATH/ORACLE/mountpoint [non-striped] or /PATH/ORACLE/mountpoint [striped]) : "

        read  inputfs

        echo "\n"

fi

 

#echo "you choosen $inputfs"

fslv=`df | grep $inputfs | awk '{print $1}' | sed 's:/dev/::g'`

fsvg=`lslv $fslv | grep 'VOLUME GROUP'  | awk '{print $6}'`

fslvlp=`lslv $fslv | grep LPs | grep -v MAX | awk '{print $2}'`

 

echo "============================================================================="

echo "$inputfs  is on lv $fslv in $fsvg"

echo "============================================================================="

echo "LV PARAMETERS"

echo "============================================================================="

lslv $fslv

echo "============================================================================="

echo "LV DISKS"

echo "============================================================================="

lslv -l $fslv

echo "============================================================================="

 

 

### get some more variables

whatvg=`lslv $fslv |  grep 'VOLUME GROUP' | awk -F' ' '{print $6}'`

lvstripe=`lslv $fslv | grep 'STRIPE WIDTH' | awk -F':' '{print $2}'`

lvpp=`lslv $fslv | grep 'PP SIZE' | awk '{print $6}`

 

 

checkstripe=`lslv $fslv | grep STRIPE`

if [ -z $checkstripe ]; then

        isstriped=0

else

        isstriped=1

fi

 

 

 

if [[ "$isstriped" = 0 ]]; then

############################################## START: NON-STRIPED FS  ##############################################

        echo "\n"

        freesize=`lsvg $whatvg | grep 'FREE PPs' | awk '{print $7}' | sed 's/(//g' | sed 's/)//g'`

        freesizeingb=$(( $freesize / 1024 ))

        echo "\n"

        echo "\n"

        echo "============================================================================="

        echo "RESULT:"

        echo "============================================================================="

        echo "$inputfs is not striped - can use available space in vg - $freesize MB ( $freesizeingb GB )"

        echo "For more space, create WFG to UNIX Team"

        echo "\n"

        usesummarymode

        resizethefs

 

############################################## END: NON-STRIPED FS  ################################################

else

############################################## START: STRIPED FS  ################################################

 

        echo "INFO: $fslv IS STRIPED "

        echo "============================================================================="

 

 

        arraydff=`lslv -l $fslv  |grep hdisk | awk '{print $1}'`

        y=0

        for i in `lslv -l $fslv  |grep hdisk | awk '{print $1}'`; do

                listofdisksarray["$y"]=$i

                y=$(( y + 1 ))

        done

        eval set -A listofdisksarray $arraydff

 

 

        disksum=`lslv -l $fslv | grep hdisk | wc -l`

        lvstripe=`lslv $fslv | grep 'STRIPE WIDTH' | awk -F':' '{print $2}'`

        diskgroups=$(( $disksum / $lvstripe ))

        stripefactorforarray=$(( $lvstripe  -1 ))

        diskgroupsarray=$(( $diskgroups -1 ))

 

        echo "INFO: STRIPE DISK GROUPS "

        echo "============================================================================="

        for ((i=0; i<=$diskgroupsarray; i++)); do

                echo " === $(( $i + 1 )) DISK GROUP ==="

                firstdiskingroup=$(( $i * $lvstripe ))

                lastdiskingroup=$(( $firstdiskingroup + $stripefactorforarray ))

 

                for ((diskingroup=$firstdiskingroup; diskingroup<=$lastdiskingroup; diskingroup++)); do

                        getfreepp=`lspv ${listofdisksarray[$diskingroup]} | grep 'FREE PPs:' | awk '{print $3}'`

                        getppsize=`lspv ${listofdisksarray[$diskingroup]} | grep 'PP SIZE:' | awk '{print $3}'`

                        canallocate=$(( $getfreepp * $getppsize ))

                        echo "can allocate $canallocate MB or ( $(( $canallocate / 1024 )) ) GB on ${listofdisksarray[$diskingroup]}" | paste - -

                done

 

 

                smallestdisk=$(for ((diskingroup=$firstdiskingroup; diskingroup<=lastdiskingroup; diskingroup++)); do

                                getfreepp=`lspv ${listofdisksarray[$diskingroup]} | grep 'FREE PPs:' | awk '{print $3}'`

                                getppsize=`lspv ${listofdisksarray[$diskingroup]} | grep 'PP SIZE:' | awk '{print $3}'`

                                canallocate=$(( $getfreepp * $getppsize ))

                                echo "$canallocate"

                              done | sort -n  | head -1)

 

                possibleresizemega=$(( $smallestdisk * $lvstripe ))

                possibleresizegiga=$(( $possibleresizemega / 1024 ))

                possibleresizetotal[$i]=$possibleresizemega

 

 

 

        done

        grandefinale=`echo ${possibleresizetotal[@]}  | sed 's/ / + /g' `

        freesize=$(( $grandefinale ))

        freesizeingb=$(( $freesize  / 1024 ))

 

 

        echo "\n"

        echo "\n"

        echo "\n"

        echo "============================================================================="

        echo "RESULT:"

        echo "============================================================================="

        echo "$inputfs is striped  - can use available space on disks  to add to FS - $freesize MB  ( $freesizeingb GB )"

        echo "If you need more space, create WFG to UNIX Team -  to extend FS on another group of disks in vg or order new disks"

        echo "\n"

 

        usesummarymode

        resizethefs

 

fi

