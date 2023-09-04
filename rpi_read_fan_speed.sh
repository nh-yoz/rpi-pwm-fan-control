#!/bin/bash
GPIO=24 # The GPIO pin used to read tachymeter
PULSE=2 # The number of impulses per revolution of the fan
TIMEOUT=500000 # ms (if no state change whithin this timelap -> rpm = 0)

# Set GPIO to input mode
pigs M $GPIO "R"

# Set internal pull up/down to "pull-up" (3.3 V)
pigs PUD $GPIO "O"

ExitNull() {
    echo 0
    exit 0
}

GetNext() { # Loops until GPIO is in state given by $1 (exit 0) or TimeOut (exit 1) 
    T0=$(date +%s%N)
    T1=$T0
    while [ "$(echo "$T1-$T0<$TIMEOUT" | bc)" -eq 1 ]
    do
#        echo $T1 >> log.log
        T1=$(date +%s%6N)
        [ "$(pigs R $GPIO)" == "$1" ] && echo "$T1" && return 0
    done
    ExitNull
}

echo "Start" > log.log
GetNext 1
T_ZERO=$(GetNext 0)
GetNext 1
T_ONE=$(GetNext 0)
echo "$T_ONE-$T_ZERO)*60/2"
RESULT=$(echo "scale=9;1000000/($T_ONE-$T_ZERO)*60/$PULSE" | bc)
echo "Rpm: $RESULT"
cat log.log
