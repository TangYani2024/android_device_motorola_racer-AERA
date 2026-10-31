#
# AERA-specific product configuration for Motorola racer.
# Adapted from aera_garnet.mk (AERA-Recovery/android_device_xiaomi_garnet-AERA).
# Values verified from the LOS 23.2 racer trees are noted; the rest is
# garnet's proven set, to be validated on first boot (see TODO.md).
#

# Screen settings. Racer is 1080x2340, 90 Hz OLED, density 420.
# AERA renders against an adaptive 2400-high canvas and scales it to the
# physical display (same as garnet).
AERA_MAINTAINER := TBD
AERA_UI2_ADAPTIVE_RESOLUTION := true
AERA_SCREEN_H := 2400
AERA_STATUS_H := 115
AERA_HIDE_NOTCH := 1
AERA_CLOCK_POS := 1
AERA_STATUS_INDENT_LEFT := 56
AERA_STATUS_INDENT_RIGHT := 48
AERA_ALLOW_DISABLE_NAVBAR := 0
AERA_USE_GREEN_LED := 0

# other stuff
AERA_QUICK_BACKUP_LIST := /boot;/data;
AERA_ENABLE_LPTOOLS := 1
AERA_NO_TREBLE_COMPATIBILITY_CHECK := 1
# Super partition size, LOS BoardConfigCommon.mk: BOARD_SUPER_PARTITION_SIZE
AERA_DYNAMIC_FULL_SIZE := 10736369664

# number of list options before scrollbar creation
AERA_OPTIONS_LIST_NUM := 11

# A/B with a dedicated recovery partition (racer has recovery_a/b,
# 100 MiB each; NOT virtual A/B, see TODO-4)
AERA_AB_DEVICE_WITH_RECOVERY_PARTITION := 1

# ----- data format stuff -----
# ensure that /sdcard is bind-unmounted before f2fs data repair or format
AERA_UNBIND_SDCARD_F2FS := 1

# automatically wipe /metadata after data format
AERA_WIPE_METADATA_AFTER_DATAFORMAT := 1

# avoid MTP issues after data format
AERA_BIND_MOUNT_SDCARD_ON_FORMAT := 1

# Unmount emulated storage cleanly before rebooting or formatting.
AERA_UNMOUNT_SDCARDS_BEFORE_REBOOT := 1

# don't spam the console with loop errors
AERA_LOOP_DEVICE_ERRORS_TO_LOG := 1

# lz4 compression
AERA_USE_LZ4_COMPRESSION := 1

# build all the partition tools
AERA_ENABLE_ALL_PARTITION_TOOLS := 1

# enable the FRP addon
AERA_ENABLE_FRP_WIPE := 1

# dmctl
AERA_USE_DMCTL := 1

# Racer ships a prebuilt kernel and f2fs userdata (LOS fstab.qcom).
AERA_FORCE_PREBUILT_KERNEL := 1
AERA_FORCE_DATA_FORMAT_F2FS := 1
# TODO-verify: casefolding. Garnet forces it; racer's stock/LOS userdata
# casefold state is unconfirmed. Leave disabled until checked on device:
#   adb shell "cat /proc/mounts | grep ' /data '"
#   (look for casefold in the mount options)
# AERA_FORCE_CASEFOLDING := 1
AERA_DISABLE_ORS_AUTO_REBOOT := 1
AERA_USE_LOCKSCREEN_BUTTON := 1
# TODO-7: WLAN in recovery needs the cnss modules (see TODO-1).
AERA_ENABLE_WLAN := 1
