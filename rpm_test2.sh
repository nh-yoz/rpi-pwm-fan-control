#!/bin/bash
#
########################################################################
# FILENAME: ****.sh
#
# AUTHOR: Niklas HOOK
#
# DESCRIPTION: Script reading a fan's tachymeter connected to a raspberry GPIO and outputs the fan's speed in RPM
#              The script uses the pigpio library (commands pigs and pig2vcd)
#
# OPTIONS:
# - [value] : setting value will repeat the poll at this interval (value may be in decimal but must be at least 2 * $SAMPLE_TIME
#
# Modifications (version | date | author | what):
# 0 | 2023-09-06 | Niklas Hook | Creation
########################################################################

# Define constants
GPIO=24 # The GPIO on which the fan's tachymeter is connected
SAMPLE_TIME="0.2" # The time to acquire information from the tachymeter
PULSES_PER_REVOLUTION=2 # The number of pulses that are emitted per revolution of the fan

# Check options
[ $# -gt 1 ] && echo "Zero or one parameter is allowed" && exit 1
if [ $# -eq 1 ]
then
    $(echo "scale=4;$1>2*$SAMPLE_TIME" | bc)
    [ $? -ne 0 ] && echo "Parameter must be a valid number" && exit 2
    [ $(echo "scale=4;$1>2*$SAMPLE_TIME" | bc) -ne 1 ] && echo "Parameter must be greater than $SAMPLE_TIME*2" && exit 3
fi

# Get the caracter used by pig2vcd for the gpio (gpio 0-25 is A-Z, 26-51 is a-z
if [ $GPIO -le 25 ]
then
    GPIO_CHAR=$(printf "\\$(printf '%03o' $((65+$GPIO)))")
else
    GPIO_CHAR=$(printf "\\$(printf '%03o' $((65+6+$GPIO)))")
fi

BIT=$((1 << $GPIO)) # Create the bit-mask for the gpio. Gpio 5 -> 100000

FindTimeDiff() { # Read the file and print to stdout the timediff between two occurences of "1$GPIO_CHAR". If none, print 0.
    RES=0
    for VALUE in ${LINES[@]}
    do
        if [[ $VALUE =~ ^[0-9]+$ ]] # If it's a value (i.e. timestamp in microseconds)
        then
            T=$VALUE
        else
            if [ $VALUE == "1$GPIO_CHAR" ] # Found a raising edge (state change from 0 to 1
            then
                if [ -v T0 ] # If T0 exists
                then
                    # Get the time diff and exit loop
                    RES=$(($T-$T0))
                    break
                else
                    # Get the timestamp of the first raising edge
                    T0=$T
               fi
           fi
        fi
    done
    echo $RES
}

while :
do
    HANDLE=$(pigs no) # Get a handle for a new notification from pigs

    # Start notification, keep running for $SAMPLE_TIME seconds then pause de notification
    pigs nb $HANDLE $BIT && sleep $SAMPLE_TIME && pigs np $HANDLE

    # Get a temporary file name
    TMP=$(mktemp)

    # Convert notification to readable using the command "pig2vcd", remove header and "#" in front of microseconds and write to temp-file
    # The notification file is a pipe -> put a timeout
    timeout 0.2 cat /dev/pigpio$HANDLE | pig2vcd | sed "0,/0$GPIO_CHAR/d" | sed 's/[ #]//' > $TMP 

    # Close the notification
    pigs nc $HANDLE

    # Read the content of the temp-file to an array
    LINES=()
    while IFS= read -r LINE; do
        LINES+=("$LINE")
    done < $TMP

    RESULT=$(FindTimeDiff)
    if [ "$RESULT" == "0" ]
    then 
        # No state change -> problem or fan stalled
        echo "0 RPM"
    else 
        RESULT=$(echo "scale=10;1/($RESULT/1000000)*60/$PULSES_PER_REVOLUTION" | bc) # get the rpm (with decimals)
        RESULT=$(echo "$RESULT/1" | bc) # Truncate value
        echo "$RESULT RPM"
    fi

    # Delete temp-file
    rm -f $TMP
    [ $# -eq 0 ] && exit 0
    sleep $1
done
