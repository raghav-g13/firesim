#!/bin/bash
# PCIe remove and rescan for Xilinx Alveo V80 (device 10ee:903f)
set -euo pipefail

BDF=${1:-$(lspci -d 10ee:903f 2>/dev/null | awk '{print $1}' | head -1)}

if [ -n "$BDF" ]; then
    echo "Removing 10ee:903f at $BDF ..."
    echo 1 | sudo tee /sys/bus/pci/devices/0000:${BDF}/remove > /dev/null
    sleep 1
    echo "Removed."
else
    echo "No 10ee:903f device found (already removed or not present)."
fi

echo "Rescanning PCIe bus ..."
echo 1 | sudo tee /sys/bus/pci/rescan > /dev/null
sleep 2

NEW=$(lspci -d 10ee:903f 2>/dev/null | awk '{print $1}' | head -1)
if [ -n "$NEW" ]; then
    echo "Device back at $NEW"
    lspci -s "$NEW" -vvv 2>/dev/null | grep -E "LnkSta:|Region" | head -5
else
    echo "Device did not re-enumerate."
    exit 1
fi
