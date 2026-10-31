#!/bin/bash
# Pull racer's vendor kernel modules from the LOS-running phone (root)
# and record their load order. Run from the root of this tree.
#
# Prereqs: phone booted into LOS 23.2, adb root available, USB connected.
# Usage: ./extract-modules.sh [output-dir]
#   default output-dir: device/motorola/racer/prebuilt/vendor/lib/modules
set -e
OUT="${1:-device/motorola/racer/prebuilt/vendor/lib/modules}"
mkdir -p "$OUT"

echo "== module files =="
adb shell "ls /vendor/lib/modules/" > /tmp/racer_modules_list.txt
adb shell "ls /vendor_dlkm/lib/modules/ 2>/dev/null" >> /tmp/racer_modules_list.txt || true
echo "Modules on device:"
cat /tmp/racer_modules_list.txt

echo "== load order files =="
adb shell "cat /vendor/etc/modules.load 2>/dev/null" > /tmp/racer_modules_load.txt || true
adb shell "cat /vendor/etc/modules.load.recovery 2>/dev/null" >> /tmp/racer_modules_load.txt || true
adb shell "ls /vendor/etc/modules.load* 2>/dev/null" || true
echo "Load order:"
cat /tmp/racer_modules_load.txt

echo "== pulling modules to $OUT =="
adb pull /vendor/lib/modules/ "$OUT/"
if adb shell "ls /vendor_dlkm/lib/modules/ >/dev/null 2>&1"; then
  adb pull /vendor_dlkm/lib/modules/ "$OUT/"
fi
cp /tmp/racer_modules_list.txt /tmp/racer_modules_load.txt "$OUT/../" 2>/dev/null || true
echo "Done. Count: $(ls "$OUT"/*.ko 2>/dev/null | wc -l) .ko files."
echo "Next: compare against LOS BOARD_RECOVERY_KERNEL_MODULES_LOAD and"
echo "fill AERA_LOAD_VENDOR_MODULES in device/motorola/racer/BoardConfig.mk"
echo "in modules.load order (audio sequence first, then touch/WLAN)."
