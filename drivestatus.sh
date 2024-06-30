#!/usr/bin/bash

## Inspired from:  https://www.youtube.com/watch?v=1YGt5o35mo0

# Get the list of drives, ommiting zfs datasets
drives=$(lsblk | grep disk | grep -v zd | awk '{print "/dev/" $1}')

for drive in $drives
do
  smartctl -H $drive > /tmp/asdasd
  if grep -q "No such device" /tmp/asdasd; then
    rm -f /tmp/asdasd
  else
    rm -f /tmp/asdasd
    smartctl -H $drive > /tmp/assessmentstatus
    if grep -q -i -e passed -e "SMART Health Status: OK" /tmp/assessmentstatus; then
      echo "$drive  : GOOD"
    elif grep -q -i failed /tmp/assessmentstatus; then
      echo "$drive  : $(tput setaf 1)REPLACE$(tput sgr 0)"
    else
      echo "$drive  : UNKNOWN STATUS"
    fi
    rm -f /tmp/assessmentstatus
  fi
done

