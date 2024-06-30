#!/usr/bin/bash

## Inspired from:  https://www.youtube.com/watch?v=1YGt5o35mo0

# Get the list of drives
drives=$(lsblk | grep disk | grep -v zd | awk '{print "/dev/" $1}')

for drive in $drives
do
  # Run smartctl command and capture the output
  output=$(smartctl -H $drive 2>&1)
  
  if echo "$output" | grep -q "No such device"; then
    continue
  fi

  if echo "$output" | grep -qi -e passed -e "SMART Health Status: OK"; then
    echo "$drive  : GOOD"
  elif echo "$output" | grep -qi failed; then
    echo "$drive  : $(tput setaf 1)REPLACE$(tput sgr 0)"
  else
    echo "$drive  : UNKNOWN STATUS"
  fi

done

