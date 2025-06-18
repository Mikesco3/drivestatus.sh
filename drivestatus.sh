#!/usr/bin/env bash
## Inspired from:  https://www.youtube.com/watch?v=1YGt5o35mo0
## 20250614 _ added age, wear level and port numbers
## 20250618 _ fixed drive detection to include SAS and SCSI


# Must run as root
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

get_port_label() {
    local dev=$1
    local bypath
    bypath=$(ls -l /dev/disk/by-path 2>/dev/null | grep "$dev" | awk '{print $9}' | head -n1)

    if [[ "$bypath" =~ ata-([0-9]+) ]]; then
        echo "SATA-${BASH_REMATCH[1]}"
    elif [[ "$bypath" =~ sas-phy([0-9]+) ]]; then
        echo "SAS-PHY${BASH_REMATCH[1]}"
    elif [[ "$bypath" =~ usb.* ]]; then
        echo "USB-${bypath}"
    elif [[ "$bypath" =~ scsi-([0-9:]+) ]]; then
        echo "SCSI-${BASH_REMATCH[1]}"
    elif [[ "$bypath" =~ pci.* ]]; then
        echo "PCI"
    else
        echo "?"
    fi
}

printf -- "-------------------------------------------\n"
printf "Drive Health:\n"
printf "%-12s %-8s %-9s %-6s %-30s\n" "DEVICE" "STATUS" "AGE_DAYS" "WEAR" "PORT"

# Get all real disks, skip zfs/lvm/virtual
drives=$(lsblk -ndo NAME,TYPE,SIZE | grep -v zd | grep -v lvm | grep -v " 0B" | grep -i -v virtual |grep -v "sr" | awk '{print $1}')

for dev in $drives; do
    path="/dev/$dev"
    health="UNKNOWN"
    age=" "
    wear=" "

    # Health check
    output=$(smartctl -H "$path" 2>&1)
    if echo "$output" | grep -qi "SMART overall-health.*PASSED"; then
        health="GOOD"
    elif echo "$output" | grep -qi "SMART overall-health.*FAILED"; then
        health="REPLACE"
    fi

    # Port detection using function
    port=$(get_port_label "$dev")

    # Get SMART attributes
    smartctl_all=$(smartctl -A "$path" 2>/dev/null)

    # Drive age
    power_on_hours=$(echo "$smartctl_all" | awk '/Power_On_Hours|Power on Hours/ {print $NF}')
    if [[ "$power_on_hours" =~ ^[0-9]+$ ]]; then
        age=$(( power_on_hours / 24 ))
    fi

    # Wear level detection
    if echo "$smartctl_all" | grep -q 'Wear_Leveling_Count'; then
        raw_val=$(echo "$smartctl_all" | awk '/Wear_Leveling_Count/ {print $4}')
        if [[ "$raw_val" =~ ^[0-9]+$ ]]; then
            raw_val=$((10#$raw_val))  # Strip leading zeros (force base 10)
            if [[ "$raw_val" -le 100 ]]; then
                wear="$((100 - raw_val))%"
            fi
        fi
    else
        alt_val=$(echo "$smartctl_all" | awk '/Media_Wearout_Indicator|Percentage Used|SSD_Life_Left/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+%?$/) print $i}' | grep -o '[0-9]\+' | head -n1)
        if [[ "$alt_val" =~ ^[0-9]+$ && "$alt_val" -le 100 ]]; then
            wear="${alt_val}%"
        fi
    fi
    
    printf "%-12s %-8s  %-9s %-6s %-30s\n"        "$path" "$health" "$age" "$wear" "$port"
done

printf -- "-------------------------------------------\n"
printf "Drive Details:\n"
printf "%-8s %-6s %-7s %-30s %-18s %-25s\n" "NAME" "TYPE" "SIZE" "MODEL" "SERIAL" "PORT"

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

    # Port detection using function
    port=$(get_port_label "$dev")

    printf "%-8s %-6s %-7s %-30s %-18s %-25s\n" "$dev" "$dtype" "$size" "$model" "$serial" "$port"
done

printf -- "-------------------------------------------\n"
