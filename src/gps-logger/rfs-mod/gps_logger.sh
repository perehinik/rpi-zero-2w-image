#!/bin/bash

# Set baud rate to 9600
stty -F /dev/ttyS0 9600

# Create timestamp
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Output file
LOGFILE="/root/gps_log_${TIMESTAMP}.txt"

# Read from serial port into file
cat /dev/ttyS0 > "$LOGFILE"

