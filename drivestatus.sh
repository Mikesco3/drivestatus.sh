#!/usr/bin/bash

## Inspired from:  https://www.youtube.com/watch?v=1YGt5o35mo0

# Check if running with elevated privileges (root)
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run with elevated privileges (root)." >&2
    exit 1
fi

echo "-------------------------------------------"
echo Drive Health:

# Get the list of drives (skipping zfs, lvm, dvd and usb drives)
drives=$(lsblk -o NAME,SIZE,MODEL,WWN,TYPE| grep disk | grep -v zd | grep -v lvm |grep -v VirtualDisk | awk '{print "/dev/" $1}' )

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

## List the Details on the Drives Present
echo "-------------------------------------------"
echo Drive Details:
lsblk --nodeps -o NAME,MODEL,SERIAL,TYPE,SIZE,SUBSYSTEMS |grep -v zd | grep -v VirtualDisk
echo "-------------------------------------------"
## Get Drives Previous method
# drives=$(lsblk | grep disk | grep -v zd | awk '{print "/dev/" $1}')

### This is another method but it is causing a bug on usb enclosures that don't have the drives present
# Get the list of drives (skipping zfs, lvm, dvd and usb drives)
# drives=$( ls -la /dev/disk/by-id/  | grep -v part | grep -v lvm | grep -v dm | grep -v sr | awk '{print "/dev/disk/by-id/" $11}' | grep by-id/.. | sort | uniq | sed 's/\/disk\/by-id\/..\/..//g' )

