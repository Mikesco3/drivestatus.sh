#!/bin/bash
# ssd_health.sh - Advanced SSD health checker
# Author: Michael Schmitz + ChatGPT
# Requires: smartmontools

DEVICE=${1:-/dev/sda}

# Check if smartctl exists
if ! command -v smartctl &>/dev/null; then
    echo "Error: smartctl not found. Install with: sudo pacman -S smartmontools"
    exit 1
fi

# Gather full SMART info
SMART=$(sudo smartctl -x "$DEVICE")

# Try to extract standardized "Percentage Used" (NVMe) or "Endurance Indicator" (SATA)
# This handles NVMe 'Percentage Used: X%' and SATA '...Endurance Indicator: X'
PERCENT_USED_LINE=$(echo "$SMART" | grep -E "^Percentage Used:|Percentage Used Endurance Indicator")
if [[ -n "$PERCENT_USED_LINE" ]]; then
    # Extract just the number, stripping '%' and whitespace
    ENDURANCE_USED=$(echo "$PERCENT_USED_LINE" | awk -F'[:%]' '{print $2}' | tr -d ' ')
fi


# Extract additional values if available
HOST_WRITES=$(echo "$SMART" | awk '/Total_Writes_GiB/ {print $NF}')
NAND_WRITES=$(echo "$SMART" | awk '/Total_NAND_Writes_GiB/ {print $NF}')
PERC_SPARE=$(echo "$SMART" | awk '/Perc_Avail_Resrvd_Space/ {print $NF}')
AVG_PE=$(echo "$SMART" | awk '/Avg_Write\/Erase_Count/ {print $NF}')
MAX_PE=$(echo "$SMART" | awk '/Maximum_Erase_Cycle/ {print $NF}')
POWER_HOURS=$(echo "$SMART" | awk '/Power_On_Hours/ {print $NF}')

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
echo "Power-On Hours       : ${POWER_HOURS:-N/A} hours (~$((POWER_HOURS/24)) days)"
echo "Host Writes          : ${HOST_WRITES:-N/A} GiB (~$(awk -v w=$HOST_WRITES 'BEGIN {printf "%.2f", w/1024}') TB)"
echo "NAND Writes          : ${NAND_WRITES:-N/A} GiB"
echo "Average P/E Cycles   : ${AVG_PE:-N/A}"
echo "Max P/E Cycles       : ${MAX_PE:-N/A}"
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

