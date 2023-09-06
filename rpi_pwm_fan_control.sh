#!/bin/bash
#
########################################################################
# FILENAME: ****.sh
#
# AUTHOR: Niklas HOOK
#
# DESCRIPTION: Script controlling a raspberry PWM-fan using hardware PWM
#
# OPTIONS: N/A
#
# Modifications (version | date | author | what):
# 0 | 2023-08-30 | Niklas Hook | Creation
########################################################################

# Setting hardware constants (ONLY INTEGERS)
FREQ=25000 # Frequency in Hz (check out fan data-sheet to find the appropriate frequency)
GPIO=18 # GPIO number: one of 18 (pin 12), 12 (pin 32), 13 (pin 33) and 19 (pin 35)
TEMP_SENSOR=1 # Where to get the temperature from (0: GPU temperature; <>0: CPU temperature). Remark: the CPU and GPU is in the same chip, the value are almost the same.

# Setting soft constants (ONLY INTEGERS)
REFRESH_RATE=5 # In seconds (how often should the speed be set)
MIN_TEMP=45 # Minumum temperature (°C) at which the fan starts running at MIN_DUTY
MAX_TEMP=80 # Maximum temperature (°C) at which the fan starts running at MAX_DUTY
MIN_DUTY=20 # Minimum speed of the fan (%). Value between 0 and 100. Must be lower or equal to MAX_DUTY. If the value is too low (ie < 10) the fan may not spin.
MAX_DUTY=100 # Maximum speed of the fan (%). Value between 0 and 100.Must be higher or equal to MIN_DUTY.
DO_STOP=1 # If temperature is below $MIN_TEMP, should fan be stopped (0: false, <>0: true)? This has no effect if the MIN_DUTY=0.
HYSTERESIS=10 # If fan is stopped because DO_STOP=1 and temperature<MIN_TEMP, don't restart fan until temperature>(MIN_TEMP+HYSTERESIS)
DUTY_ON_EXIT=50 # When script is terminated (SIGINT), set the speed of the fan to this value (%). Value must at most be 100. If negative (<0), the gpio pin will be set to mode "INPUT" which will release the hardware PWM control.

GetTemp() { # Prints to stdout the temperature in °C with decimals
    if [ $TEMP_SENSOR -eq 0 ]
    then
        TEMP=$(vcgencmd measure_temp) # Returns value as xx.x'C
        TEMP=${TEMP/"'C"/""} # Removes the ending 'C
    else
        TEMP=$(cat /sys/class/thermal/thermal_zone0/temp) # Returns value as xxxxx (m°C)
        TEMP=$(echo "scale=3;$TEMP/1000" | bc) # Scale to °C
    fi
    echo "$TEMP"
}

GetDuty() { # Prints to stdout the calculated duty (value between 0 and 1 000 000). Requires two arguments: the temperature (may be decimal) and the previous duty
    MULTIPLIER=10000 # To get value between 0 and 1000000 for MIN_DUTY and MAX_DUTY given in range 0-100
    TEMP=$1
    OLD_DUTY=$2
    DUTY=$(echo "scale=7;(($TEMP-$MIN_TEMP)/($MAX_TEMP-$MIN_TEMP)*($MAX_DUTY-$MIN_DUTY)+$MIN_DUTY)*$MULTIPLIER" | bc)
    DUTY=$(echo "$DUTY/1" | bc) # Truncate
    DUTY=$((DUTY > MAX_DUTY*MULTIPLIER ? MAX_DUTY*MULTIPLIER : DUTY < MIN_DUTY*MULTIPLIER ? MIN_DUTY*MULTIPLIER : DUTY))
    [ $OLD_DUTY -eq 0 ] && [ $DUTY -gt 0 ] && [ $DO_STOP -eq 1 ] && [ $(echo "$TEMP<$MIN_TEMP+$HYSTERESIS" | bc) -eq 1 ] && DUTY=0
    echo $DUTY
}

DoExit() {
    if [ $DUTY_ON_EXIT -lt 0 ]
    then
        pigs M $GPIO R
    else
        pigs HP $GPIO $FREQ $(($DUTY_ON_EXIT*10000))
    fi
}

trap "DoExit" EXIT

DUTY=0

while :
do
    TEMP=$(GetTemp)
    DUTY="$(GetDuty $TEMP $DUTY)"
    echo "$(date): pigs HP $GPIO $FREQ $DUTY | Temperature = ${TEMP}°C"> "$(realpath $0).log"
    pigs HP $GPIO $FREQ $DUTY
    sleep $REFRESH_RATE
done

