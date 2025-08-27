#!/bin/bash
# ssd_health.sh - Advanced SSD health checker
# Author: Michael Schmitz + ChatGPT
# Requires: smartmontools

DEVICE_ARG=${1:-/dev/sda}
# Prepend /dev/ if it's not there
if [[ ! "$DEVICE_ARG" == /dev/* ]]; then
    DEVICE="/dev/$DEVICE_ARG"
else
    DEVICE="$DEVICE_ARG"
fi

# Check if smartctl exists
if ! command -v smartctl &>/dev/null; then
    echo "Error: smartctl not found. Install with: sudo pacman -S smartmontools"
    exit 1
fi

# Gather full SMART info
SMART=$(sudo smartctl -x "$DEVICE")

# Extract model and serial
MODEL=$(echo "$SMART" | grep -m1 "Model Number:" | awk -F: '{print $2}' | xargs)
if [[ -z "$MODEL" ]]; then
    MODEL=$(echo "$SMART" | grep -m1 "Device Model:" | awk -F: '{print $2}' | xargs)
fi
SERIAL=$(echo "$SMART" | grep "Serial Number:" | awk -F: '{print $2}' | xargs)

# Try to extract standardized "Percentage Used" (NVMe) or "Endurance Indicator" (SATA)
# This handles NVMe 'Percentage Used: X%' and SATA '...Endurance Indicator: X'
PERCENT_USED_LINE=$(echo "$SMART" | grep -E "^Percentage Used:|Percentage Used Endurance Indicator")
if [[ -n "$PERCENT_USED_LINE" ]]; then
    # Handle SATA '... Endurance Indicator' which is formatted differently
    if [[ $PERCENT_USED_LINE == *"Endurance Indicator"* ]]; then
        ENDURANCE_USED=$(echo "$PERCENT_USED_LINE" | awk '{print $4}')
    else
        # Handle NVMe 'Percentage Used: X%'
        ENDURANCE_USED=$(echo "$PERCENT_USED_LINE" | awk -F'[:%]' '{print $2}' | tr -d ' ')
    fi
fi


# Extract additional values if available, trying NVMe conventions first.
POWER_HOURS=$(echo "$SMART" | awk '/^Power On Hours:/ {print $4}' | tr -d ',')
DATA_UNITS_WRITTEN=$(echo "$SMART" | awk '/^Data Units Written:/ {print $4}' | tr -d ',')
PERC_SPARE=$(echo "$SMART" | awk '/^Available Spare:/ {print $3}' | tr -d '%')

# Fallback to SATA / other vendor-specific attributes if NVMe fields were not found.
if [[ -z "$POWER_HOURS" ]]; then
    POWER_HOURS=$(echo "$SMART" | awk '/Power_On_Hours/ {print $NF}')
fi

if [[ -n "$DATA_UNITS_WRITTEN" ]]; then
    # NVMe "Data Units Written" are in 1000s of 512-byte units. Convert to GiB.
    HOST_WRITES=$(awk -v u="$DATA_UNITS_WRITTEN" 'BEGIN {printf "%.0f", u * 1000 * 512 / 1024^3}')
else
    # Fallback for SATA drives using Logical Sectors Written
    LOGICAL_SECTORS_WRITTEN=$(echo "$SMART" | awk '/Logical Sectors Written/ {print $NF}')
    if [[ -n "$LOGICAL_SECTORS_WRITTEN" ]]; then
        SECTOR_SIZE=$(echo "$SMART" | awk '/Sector Size:/ {print $3}')
        [[ ! "$SECTOR_SIZE" =~ ^[0-9]+$ ]] && SECTOR_SIZE=512
        HOST_WRITES=$(awk -v sectors="$LOGICAL_SECTORS_WRITTEN" -v size="$SECTOR_SIZE" 'BEGIN {printf "%.0f", sectors * size / 1024^3}')
    else
        # Fallback to vendor-specific attribute
        HOST_WRITES=$(echo "$SMART" | awk '/Total_Writes_GiB/ {print $NF}')
    fi
fi

if [[ -z "$PERC_SPARE" ]]; then
    PERC_SPARE=$(echo "$SMART" | awk '/Perc_Avail_Resrvd_Space/ {print $NF}')
fi

# Continue trying to find other common vendor-specific attributes
NAND_WRITES=$(echo "$SMART" | awk '/Total_NAND_Writes_GiB/ {print $NF}')
AVG_PE=$(echo "$SMART" | awk '/Wear_Leveling_Count/ {print $NF}')
# If Wear_Leveling_Count wasn't found, try Avg_Write/Erase_Count
if [[ -z "$AVG_PE" ]]; then
    AVG_PE=$(echo "$SMART" | awk '/Avg_Write\/Erase_Count/ {print $NF}')
fi
MAX_PE=$(echo "$SMART" | awk '/Maximum_Erase_Cycle/ {print $NF}')

# Assume TLC endurance ~1000 cycles
ENDURANCE_CYCLES=1000

# Calculate wear %
if [[ -n "$ENDURANCE_USED" && "$ENDURANCE_USED" =~ ^[0-9]+$ ]]; then
    WEAR_USED=$ENDURANCE_USED
    LIFE_LEFT=$((100 - ENDURANCE_USED))
    METHOD="(Using standardized endurance indicator)"
elif [[ -n "$AVG_PE" ]]; then
    WEAR_USED=$(awk -v pe="$AVG_PE" -v limit="$ENDURANCE_CYCLES" 'BEGIN {printf "%.2f", (pe/limit)*100}')
    LIFE_LEFT=$(awk -v pe="$AVG_PE" -v limit="$ENDURANCE_CYCLES" 'BEGIN {printf "%.2f", (1 - pe/limit)*100}')
    METHOD="(Using average P/E cycles)"
elif [[ -n "$HOST_WRITES" ]]; then
    DRIVE_SIZE_TB=$(lsblk -bno SIZE "$DEVICE" | awk '{printf "%.2f", $1/1024/1024/1024/1024}')
    TBW_LIMIT=600 # Conservative default for 2TB TLC drives
    WEAR_USED=$(awk -v writes="$HOST_WRITES" -v limit="$TBW_LIMIT" 'BEGIN {printf "%.2f", (writes/1024)/limit*100}')
    LIFE_LEFT=$(awk -v writes="$HOST_WRITES" -v limit="$TBW_LIMIT" 'BEGIN {printf "%.2f", 100 - ((writes/1024)/limit*100)}')
    METHOD="(Using host writes vs estimated TBW)"
else
    echo "Error: Could not determine SSD wear level for $DEVICE"
    exit 1
fi

# Output report
echo "=============================================="
echo "        SSD Health Report - $DEVICE"
echo "=============================================="
echo "Model                : ${MODEL:-N/A}"
echo "Serial Number        : ${SERIAL:-N/A}"
if [[ -n "$POWER_HOURS" && "$POWER_HOURS" -gt 0 ]]; then
    echo "Power-On Hours       : ${POWER_HOURS} hours (~$((POWER_HOURS/24)) days)"
else
    echo "Power-On Hours       : N/A hours"
fi
if [[ -n "$HOST_WRITES" && "$HOST_WRITES" =~ ^[0-9]+$ ]]; then
    echo "Host Writes          : ${HOST_WRITES} GiB (~$(awk -v w=$HOST_WRITES 'BEGIN {printf "%.2f", w/1024}') TB)"
else
    echo "Host Writes          : N/A GiB"
fi
if [[ -n "$NAND_WRITES" ]]; then
    echo "NAND Writes          : ${NAND_WRITES} GiB"
fi
if [[ -n "$AVG_PE" ]]; then
    echo "Average P/E Cycles   : ${AVG_PE}"
fi
if [[ -n "$MAX_PE" ]]; then
    echo "Max P/E Cycles       : ${MAX_PE}"
fi
echo "Spare Blocks Left    : ${PERC_SPARE:-N/A}%"
echo "----------------------------------------------"
echo "Estimated Wear Used  : $WEAR_USED % $METHOD"
echo "Estimated Life Left  : $LIFE_LEFT %"
echo "=============================================="

# Color-coded health indicator
if (( $(echo "$LIFE_LEFT < 20" | bc -l) )); then
    echo "⚠️  WARNING: Drive nearing wear-out limits!"
elif (( $(echo "$LIFE_LEFT < 50" | bc -l) )); then
    echo "🔸 Moderate wear detected. Monitor regularly."
else
    echo "✅ Drive health is excellent."
fi


