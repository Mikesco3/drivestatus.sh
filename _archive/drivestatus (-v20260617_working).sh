#!/usr/bin/env bash
## Inspired from:  https://www.youtube.com/watch?v=1YGt5o35mo0
## 20250614 _ added age, wear level and port numbers
## 20250617 _ fixed SAS detection and consistent grep patterns

# Must run as root
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

printf -- "-------------------------------------------\n"
printf "Drive Health:\n"
printf "%-12s %-8s %-9s %-6s %-10s\n" "DEVICE" "STATUS" "AGE_DAYS" "WEAR" "PORT"

# Get all real disks, skip zfs/lvm/virtual
drives=$(lsblk -ndo NAME,TYPE,SIZE |grep -v zd |grep -v lvm |grep -v " 0B" |grep -i -v virtual | awk '{print $1}')

for dev in $drives; do
    path="/dev/$dev"
    health="UNKNOWN"
    age=" "
    wear=" "
    port="?"

    # Health check
    output=$(smartctl -H "$path" 2>&1)
    if echo "$output" | grep -qi "SMART overall-health.*PASSED"; then
        health="GOOD"
    elif echo "$output" | grep -qi "SMART overall-health.*FAILED"; then
        health="REPLACE"
    fi

    # Get port from by-path symlink (skip irrelevant types)
    bypath=$(ls -l /dev/disk/by-path 2>/dev/null | grep "$dev" | awk '{print $9}' | head -n1)
    if [[ "$bypath" =~ ata-([0-9]+) ]]; then
        port="SATA-${BASH_REMATCH[1]}"
    elif [[ "$bypath" =~ sas-phy([0-9]+) ]]; then
        port="SAS-PHY${BASH_REMATCH[1]}"
    elif [[ "$bypath" =~ usb.* ]]; then
        port="USB-${bypath}"
    elif [[ "$bypath" =~ scsi-([0-9:]+) ]]; then
        port="SCSI-${BASH_REMATCH[1]}"
    elif [[ "$bypath" =~ pci.* ]]; then
        port="PCI"
    else
        port="?"
    fi

    # Get SMART attributes
    smartctl_all=$(smartctl -A "$path" 2>/dev/null)

    # Drive age
    power_on_hours=$(echo "$smartctl_all" | awk '/Power_On_Hours|Power on Hours/ {print $NF}')
    if [[ "$power_on_hours" =~ ^[0-9]+$ ]]; then
        age=$(( power_on_hours / 24 ))
    fi

    # Wear level (best guess)
    wear_val=$(echo "$smartctl_all" | awk '/Wear_Leveling_Count|Media_Wearout_Indicator|Percentage Used|SSD_Life_Left/ {print $(NF)}' | grep -o '[0-9]\+' | head -n1)
    if [[ -n "$wear_val" && "$wear_val" -le 100 ]]; then
        wear="${wear_val}%"
    fi

    printf "%-12s %-8s %-9s %-6s %-10s\n" "$path" "$health" "$age" "$wear" "$port"
done

printf -- "-------------------------------------------\n"
printf "Drive Details:\n"
printf "%-8s %-25s %-15s %-6s %-7s %-10s\n" "NAME" "MODEL" "SERIAL" "TYPE" "SIZE" "PORT"

for dev in $drives; do
    path="/dev/$dev"
    model=$(lsblk -ndo MODEL "$path")
    serial=$(lsblk -ndo SERIAL "$path")
    size=$(lsblk -ndo SIZE "$path")

    # Detect real type: HD, SSD, NVME
    if [[ "$dev" == nvme* ]]; then
        dtype="NVME"
    else
        rotation=$(smartctl -i "$path" 2>/dev/null | awk -F: '/Rotation Rate/ {gsub(/^[ \t]+/, "", $2); print $2}')
        if [[ "$rotation" =~ ^0|Solid.State.Device$ ]]; then
            dtype="SSD"
        else
            dtype="HD"
        fi
    fi

    # Get port info again
        bypath=$(ls -l /dev/disk/by-path 2>/dev/null | grep "$dev" | awk '{print $9}' | head -n1)
    if [[ "$bypath" =~ ata-([0-9]+) ]]; then
        port="SATA-${BASH_REMATCH[1]}"
    elif [[ "$bypath" =~ sas-phy([0-9]+) ]]; then
        port="SAS-PHY${BASH_REMATCH[1]}"
    elif [[ "$bypath" =~ usb.* ]]; then
        port="USB-${bypath}"
    elif [[ "$bypath" =~ scsi-([0-9:]+) ]]; then
        port="SCSI-${BASH_REMATCH[1]}"
    elif [[ "$bypath" =~ pci.* ]]; then
        port="PCI"
    else
        port="?"
    fi

    printf "%-8s %-25s %-15s %-6s %-7s %-10s\n" "$dev" "$model" "$serial" "$dtype" "$size" "$port"
done

printf -- "-------------------------------------------\n"
