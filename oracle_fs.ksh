oracle_fs



#!/usr/bin/ksh93

 

### launched via oracle team with sudo (w permissions only for root on file!)

### this script checks if fs is striped or not

### not striped - give free space of vg

### striped - shows groups of disks and free space in every disk group. check minimum size!

### next version will allow dba admin to extend maximum LP on LV, resize fs (check hacmp also )

echo "============================================================================="

echo " ORACLE_FS.SH "

echo "============================================================================="

echo " all ORACLE filesystems:"

##df -g | grep -i syor  | sed 's: :\t:g'

#df -g | grep -i -e Filesystem -e ORACLE| awk '{printf("%+20s %+8s\t%+8s %+4s\t%+8s %+4s %.20s %s %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9)}'

df -g | grep -i -e Filesystem -e ORACLE

echo "=============================================================================

echo  "give fs to resize (ex. aixserver1: /MOUNT/ORACLE/db1_archive [non-striped] or /MOUNT/ORACLE/oracle [striped]) : "

read  inputfs

#echo "you choosen $inputfs"

fslv=`df | grep $inputfs | awk '{print $1}' | sed 's:/dev/::g'`

fsvg=`lslv $fslv | grep 'VOLUME GROUP'  | awk '{print $6}'`

 

echo "============================================================================="

echo "$inputfs  is on lv $fslv in $fsvg"

echo "============================================================================="

echo "\n"

echo "LV PARAMETERS"

echo "============================================================================="

lslv $fslv

echo "============================================================================="

echo "\n"

echo "LV DISKS"

echo "============================================================================="

lslv -l $fslv

echo "============================================================================="

 

 

### get some more variables

whatvg=`lslv $fslv |  grep 'VOLUME GROUP' | awk -F' ' '{print $6}'`

lvstripe=`lslv $fslv | grep 'STRIPE WIDTH' | awk -F':' '{print $2}'`

lvpp=`lslv $fslv | grep 'PP SIZE' | awk '{print $6}`

 

 

lslv $fslv | grep STRIPE > /dev/null && isstriped=0 || isstriped=1

 

 

if [[ $isstriped  = 1 ]]; then

############################################## START: NON-STRIPED FS  ##############################################

echo "\n"

size=`lsvg $whatvg | grep 'FREE PPs' | awk '{print $7}' | sed 's/(//g' | sed 's/)//g'`

echo "RESULT:"

echo "##########################"

echo "$inputfs is not striped - can use available space in vg - $size MB / $(( $size / 1024 )) GB"

echo "for more space, make wfg to order more disks"

echo "\n"

 

############################################## END: NON-STRIPED FS  ################################################

else

############################################## START: STRIPED FS  ################################################

 

echo "\n"

echo "RESULT: $fslv IS STRIPED "

echo "##########################"

 

arraydff=`lslv -l $fslv  |grep hdisk | awk '{print $1}'`

y=0

 

 

for i in `lslv -l $fslv  |grep hdisk | awk '{print $1}'`; do

        listofdisksarray["$y"]=$i

        y=$(( y + 1 ))

done

eval set -A listofdisksarray $arraydff

 

 

 

 

disksum=`lslv -l $fslv | grep hdisk | wc -l`

echo "disksum is $disksum"

lvstripe=`lslv $fslv | grep 'STRIPE WIDTH' | awk -F':' '{print $2}'`

echo "lvstripe is $lvstripe"

diskgroups=$(( $disksum / $lvstripe ))

echo "diskgroups is $diskgroups"

stripefactorforarray=$(( $lvstripe  -1 ))

echo "stripefactorforarray is $stripefactorforarray"

diskgroupsarray=$(( $diskgroups -1 ))

echo "diskgroupsarray is $diskgroupsarray"

 

 

 

#DEBUG no seq command found: for i in `seq 0 $diskgroupsarray`; do

for ((i=0; i<=$diskgroupsarray; i++)); do

        echo "\n"

        echo " === $(( $i + 1 )) DISK GROUP ==="

        firstdiskingroup=$(( $i * $lvstripe ))

        lastdiskingroup=$(( $firstdiskingroup + $stripefactorforarray ))

 

                #for diskingroup in `seq        $firstdiskingroup $lastdiskingroup`; do

                for ((diskingroup=$firstdiskingroup; diskingroup<=$lastdiskingroup; diskingroup++)); do

                        getfreepp=`lspv ${listofdisksarray[$diskingroup]} | grep 'FREE PPs:' | awk '{print $3}'`

                        getppsize=`lspv ${listofdisksarray[$diskingroup]} | grep 'PP SIZE:' | awk '{print $3}'`

                        canallocate=$(( $getfreepp * $getppsize ))

                        echo "can allocate $canallocate MB or $(( $canallocate / 1024 )) GB on ${listofdisksarray[$diskingroup]}" | paste - -

                done

 

 

# DEBUG: finding minimum space on disk

                smallestdisk=$(for ((diskingroup=$firstdiskingroup; diskingroup<=lastdiskingroup; diskingroup++)); do

                        getfreepp=`lspv ${listofdisksarray[$diskingroup]} | grep 'FREE PPs:' | awk '{print $3}'`

                        getppsize=`lspv ${listofdisksarray[$diskingroup]} | grep 'PP SIZE:' | awk '{print $3}'`

                        canallocate=$(( $getfreepp * $getppsize ))

                        echo "$canallocate"

                done | sort -n  | head -1)

#echo "smallestdisk is $smallestdisk MB"

possibleresizemega=$(( $smallestdisk * $lvstripe ))

#echo "possibleresizemega is $possibleresizemega MB / $(( $possibleresizemega / 1024 )) GB "

possibleresizegiga=$(( $possibleresizemega / 1024 ))

#echo "possibleresizegiga is $possibleresizegiga GB "

 

# create array of results

possibleresizetotal[$i]=$possibleresizemega

#echo "array value is"

#echo ${possibleresizetotal[$i]}

 

 

 

done

#eval set -A possibleresizetotal $possibleresizetotal

#echo "all indexes in array is ${possibleresizetotal[@]}"

grandefinale=`echo ${possibleresizetotal[@]}  | sed 's/ / + /g' `

#echo "sum of grandefinale is $(( $grandefinale )) MB or $(( $grandefinale / 1024 )) GB"

grandefinalemb=$(( $grandefinale ))

grandefinalegb=$(( $((grandefinale)) / 1024 ))

 

 

echo "\n"

echo "RESULT:"

echo "##########################"

echo "$inputfs is striped  - can use available space on disks  to add to FS - $grandefinalemb  MB  / $grandefinalegb  GB"

echo "if you need more space, unix team needs to extend lv on group of disks in vg, or order new disks"

echo "\n"

 

fi

