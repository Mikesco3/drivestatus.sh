#!/usr/bin/bash
for i in {a..z}
  do
  smartctl -H /dev/sd$i > /tmp/asdasd
  if grep -q "No such device" /tmp/asdasd; then
    rm -f /tmp/asdasd
  else
    rm -f /tmp/asdasd
    smartctl -H /dev/sd$i > /tmp/assessmentstatus
    if grep -q -i passed /tmp/assessmentstatus; then
      echo "sd$i  : GOOD"
    elif grep -q -i failed /tmp/assessmentstatus; then
      echo "sd$i  : $(tput setaf 1)REPLACE$(tput sgr 0)"
    else
      echo "sd$i  : UNKOWN STATUS"
    fi
    rm -f /tmp/assessmentstatus
  fi
done

## source https://www.youtube.com/watch?v=1YGt5o35mo0
