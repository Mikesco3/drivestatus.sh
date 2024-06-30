# drivestatus.sh

# Hard Drive Health Check Script

This script checks the health status of hard drives connected to your system using the `smartctl` utility from the `smartmontools` package.

## Requirements

- `smartmontools` package installed on your system.

## Installation

1. Install `smartmontools` if you haven't already. You can use your package manager to install it. For example, on Debian-based systems:

  ```sh
   sudo apt-get update
   sudo apt-get install smartmontools
  ```

2. Clone this repository:
  ``` sh
   git clone git@github.com:Mikesco3/drivestatus.sh.git
   cd drivestatus
  ```

3. Make the script executable:
  ``` sh
   chmod +x drivestatus.sh
  ```
4. (Optional) Copy it to the system path
  ``` sh
   cp drivestatus.sh /usr/bin/
  ```

# Usage
Run the script using the following command:
  ``` sh
   drivestatus.sh 
  ```
The script will check the health status of all drives from `/dev/sda` to `/dev/sdz` and print their status.

## Script Details
The script performs the following steps:

1. Iterates over all possible drive letters from a to z.
2. Checks if the drive exists.
3. If the drive exists, it checks the health status using the smartctl command.
4. Prints the drive status:
  - **GOOD:** If the status is PASSED or SMART Health Status: OK.
  - **REPLACE:** If the status is FAILED.
  - **UNKNOWN STATUS:** If the status is neither PASSED nor FAILED.

## Example Output
```
sda  : GOOD
sdb  : GOOD
sdc  : REPLACE
sdd  : UNKNOWN STATUS
```

## License
<a href="https://github.com/Mikesco3/drivestatus.sh/blob/main/LICENSE" target="_blank">AGPL-3.0 license</a>.

# Acknowledgments
- <a href="https://www.youtube.com/@itssimplycomputing1814" target="_blank">@@itssimplycomputing1814 on Youtube</a>
- smartmontools - For providing the smartctl utility.
