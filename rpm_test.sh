#!/bin/bash
GPIO=24
HANDLE=$(pigs no)
BIT=$((1 << $GPIO))
SAMPLE_TIME="0.2"

if [ $GPIO -le 25 ]
then
    GPIO_CHAR=$(printf "\\$(printf '%03o' $((65+$GPIO)))")
else
    GPIO_CHAR=$(printf "\\$(printf '%03o' $((65+6+$GPIO)))")
fi

pigs nb $HANDLE $BIT && sleep $SAMPLE_TIME && pigs np $HANDLE

TMP=$(mktemp)
# timeout 0.2 cat /dev/pigpio$HANDLE | pig2vcd > $TMP
timeout 0.2 cat /dev/pigpio$HANDLE | pig2vcd > $TMP
sed -i "1,/.*1$GPIO_CHAR/{s/.*1$GPIO_CHAR//;}" $TMP
sed -i 's/[ #]//' $TMP
pigs nc $HANDLE

# Remove all spaces and "#" in file
# echo "BEFORE REPLACING"
cat $TMP
# sed -i 's/[ #]//' $TMP
# echo "After substitution"
#cat $TMP
#sed -i '0,/1Y/d' $TMP
#echo "After deleting first part"
#cat $TMP

# Read the content to array
LINES=()
while IFS= read -r LINE; do
    LINES+=("$LINE")
done < $TMP

[ ${#LINES[@]} -eq 0 ] && echo "File is empty" && rm -f $TMP && exit 1


FindTimeDiff() {
    RES=0
    for VALUE in ${LINES[@]}
    do
        if [[ $VALUE =~ ^[0-9]+$ ]]
        then
            T=$VALUE
        else
            if [ $VALUE == "1$GPIO_CHAR" ]
            then
                if [ -v T0 ]
                then
                    RES=$(($T-$T0))
                    break
                else
                    T0=$T
               fi
           fi
        fi
    done
    echo $RES
}
RESULT=$(FindTimeDiff)

if [ "$RESULT" == "0" ]
then 
    echo "0 RPM"
else 
    echo "$(echo "scale=10;1/(${RESULT}/1000000)*60/2" | bc) RPM"
fi

# Cleaning up 
echo $TMP # rm -f $TMP

# cat $TMP

# Replace all spaces in file

# Read until 0Y is found in $TMP

# Read next #<number> followed by 1Y (remember <number> as T0)

# Read next #<number> followed by 1Y (remember <number> as T1)

# RPM=$(echo "1/(($T1-$T0)/1000000)*60/2" | bc)

