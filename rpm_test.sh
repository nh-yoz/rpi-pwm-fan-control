#!/bin/bash
GPIO=24
HANDLE=$(pigs no)
BIT=$((1 << $GPIO))
SAMPLE_TIME="0.2"

pigs nb $HANDLE $BIT && sleep $SAMPLE_TIME && pigs np $HANDLE

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

[ ${#LINES[@]} -eq 0 ] && echo "File is empty" && rm -f $TMP && exit 1

if [ $GPIO -le 25 ]
then
    GPIO_CHAR=$(printf "\\$(printf '%03o' $((65+$GPIO)))")
else
    GPIO_CHAR=$(printf "\\$(printf '%03o' $((65+6+$GPIO)))")
fi
echo $GPIO_CHAR

# while [ ! ${LINES[$I]} == "0$GPIO_CHAR" ] && [ $I -lt ${#LINES[@]} ]
#do
#    ((I+=1))
#done
echo "Lines in file: ${#LINES[@]}"

FindTimeDiff() {
    RES=0
    for VALUE in ${LINES[@]}
    do
        # echo $VALUE
        if [[ $VALUE =~ ^[0-9]+$ ]]
        then
            T=$VALUE
        else
            if [ $VALUE == "1$GPIO_CHAR" ]
            then
                if [ -v T0 ]
                then
                    echo $(($T-$T0))
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
echo "Result is: $RESULT"

if [ "$RESULT" == "0" ]
then 
    echo "0 RPM"
else 
    echo "1/($RESULT/1000000)*60/2"
    RES=$(echo "1/($RESULT/1000000)*60/2" | bc)
    echo $RES RPM
fi

# Cleaning up 
echo $TMP # rm -f $TMP

# cat $TMP

# Replace all spaces in file

# Read until 0Y is found in $TMP

# Read next #<number> followed by 1Y (remember <number> as T0)

# Read next #<number> followed by 1Y (remember <number> as T1)

# RPM=$(echo "1/(($T1-$T0)/1000000)*60/2" | bc)

