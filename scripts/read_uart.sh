#!/bin/bash

# UART serial port
PORT="/dev/cu.usbserial-110"
BAUD=9600
DURATION=5

echo "Reading from $PORT at $BAUD baud for $DURATION seconds..."
echo "---"

# Configure serial port and read for 5 seconds
stty -f $PORT $BAUD cs8 -cstopb -parenb raw
cat $PORT &
CAT_PID=$!
sleep $DURATION
kill $CAT_PID 2>/dev/null

echo ""
echo "---"
echo "Done reading."
