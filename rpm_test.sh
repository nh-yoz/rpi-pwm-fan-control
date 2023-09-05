#!/bin/bash

GPIO=24

HANDLE=$(pigs no)

BIT=$((1 << $GPIO))

pigs nb $HANDLE $BIT && sleep 0.2 && pigs np $HANDLE

TMP=$(mktemp)
echo $TMP
timeout 0.2 cat /dev/pigpio$HANDLE | pig2vcd > $TMP

pigs nc $HANDLE

# Remove all spaces and "#" in file
sed -i 's/[ #]//g' $TMP

# Read the content to array
LINES=()
while IFS= read -r LINE; do
    LINES+=("$LINE")
done < $TMP

if [ $GPIO -le 25 ]
then
    GPIO_CHAR=$(printf "\\$(printf '%03o' $((65+$GPIO)))")
else
    GPIO_CHAR=$(printf "\\$(printf '%03o' $((65+6+$GPIO)))")
fi
echo $GPIO_CHAR
I=0
while [ ! ${LINES[$I]} == "0$GPIO_CHAR" ] && [ $I -lt ${#LINES[@]} ]
do
    ((I+=1))
done

[ $I -eq ${#LINES[@]} ] && echo "0 rpm" && exit

STOP=0
while [ $I -lt ${#LINES[@]} ] && [ STOP -eq 0 ]
do
    VAL=${LINES[$I]}
    if [[ $VAL =~ ^[0-9]+$ ]]
    then
        T=$VAL
    else
        if [ $VAL == "1$GPIO_CHAR" ]
        then
           if [ -v T0 ]
           then
               T1=$T
echo $T1
               STOP=1
           else
               T0=$T
echo $T0
           fi
       fi
    fi
done
if [ -v T0 ] && [ -v T1 ]
then
   RESULT=$(echo "1/(($T1-$T0)/1000000)*60/2" | bc)
   echo "$RESULT RPM"
else
   echo "0 RPM" && exit
fi
cat $TMP

# Replace all spaces in file

# Read until 0Y is found in $TMP

# Read next #<number> followed by 1Y (remember <number> as T0)

# Read next #<number> followed by 1Y (remember <number> as T1)

# RPM=$(echo "1/(($T1-$T0)/1000000)*60/2" | bc)

rm -rf $TMP
