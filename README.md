# drivestatus

# Hard Drive Health Check Script
This script checks the health status of hard drives connected to your system using the `smartctl` utility from the `smartmontools` package.

## Requirements
- `smartmontools` package installed on your system for the `smartctl` command.
- `util-linux` package installed on your system for the `lsblk` command.

Consult your package manager to install these on your system. For example, on Debian-based systems:
  ```sh
   sudo apt-get update 
   sudo apt-get install smartmontools util-linux
  ```

## Installation

## short method
Run the following with root privileges command to download the script
``` sh
sudo wget -O /usr/bin/drivestatus https://raw.githubusercontent.com/Mikesco3/drivestatus.sh/main/drivestatus.sh && sudo chmod +x /usr/bin/drivestatus
```
## longer method
1. Clone this repository:
  ``` sh
   git clone https://github.com/Mikesco3/drivestatus.sh.git
   cd drivestatus
  ```

2. Make the script executable:
  ``` sh
   chmod +x drivestatus.sh
  ```
4. (Optional) Copy it to the system path
  ``` sh
   cp drivestatus.sh /usr/bin/drivestatus
  ```

# Usage
Run the script using the following command:
  ``` sh
   drivestatus 
  ```
The script will check the health status of all drives and print their status and details.

## Script Details
The script performs the following steps:

1. Detects the physical drives in the system
3. Checks the health status using the smartctl command.
4. Prints the drive status:
  - **GOOD:** If the status is PASSED or SMART Health Status: OK.
  - **REPLACE:** If the status is FAILED.
  - **UNKNOWN STATUS:** If the status is neither PASSED nor FAILED.

## Example Output
```
-------------------------------------------
Drive Health:
DEVICE       STATUS   AGE_DAYS  WEAR   PORT                          
/dev/sda     GOOD      2195             SATA-1                        
/dev/sdb     GOOD      2195             SATA-2                        
/dev/sdc     GOOD      315       1%     SATA-3                        
-------------------------------------------
Drive Details:
NAME     TYPE   SIZE    MODEL                    SERIAL    PORT                     
sda      HD      3.6T   ACME BlahBlahBlah        SN00001   SATA-1                   
sdb      HD      3.6T   HGST BlahBlahBlah        SN00002   SATA-2                   
sdc      SSD    931.5G  Samsung BlahBlahBlah     SN00003   SATA-3                   
-------------------------------------------
```

## Roadmap
- have it warn based on the wearlevel and age

## License
<a href="https://github.com/Mikesco3/drivestatus.sh/blob/main/LICENSE" target="_blank">AGPL-3.0 license</a>.

# Acknowledgments
- <a href="https://www.youtube.com/@itssimplycomputing1814" target="_blank">@itssimplycomputing1814 on Youtube</a>
- smartmontools - For providing the smartctl utility.
