# Prebuilt kernel files for racer (already in this directory)
#
# kernel   — stock 14-13 kernel, 4.19.125-perf+, 37,376,016 bytes, raw ARM64
#            Image. Extracted from the user's own verified boot_b dump
#            (~/workspace/firmware_racer/user_boot_b/boot_b.img); its AVB
#            hash was verified against vbmeta_b on 2026-10-23. Stock was
#            chosen because it matches the Android 11-era vendor blobs.
#            Alternative: the LOS kernel (4.19.325-cip136-st20) — extract
#            it from the LOS boot.img the same way if modules refuse to
#            load against the stock kernel.
# dtb      — device tree blob from the same boot_b (399,502 bytes).
# dtbo.img — the user's own dtbo_b dump (2,097,152 bytes =
#            BOARD_DTBOIMG_PARTITION_SIZE).
#
# How kernel/dtb were extracted (reproducible, no magiskboot needed):
#   python3: parse the Android boot image v2 header (page_size 4096),
#   kernel at offset page_size, dtb after kernel+ramdisk (page-aligned).
#
# MISSING: nothing — vendor kernel modules are now in this tree.
# prebuilt/vendor/lib/modules/ holds the 79 .ko files pulled from the
# live LOS 23.2 phone on 2026-10-31 (23 MB, incl. modules.dep /
# modules.alias / modules.softdep from the device). Load order is
# AERA_LOAD_VENDOR_MODULES in BoardConfig.mk (71 modules), verified
# topologically against modules.dep; post-decrypt WLAN/rmnet set is
# AERA_POST_DECRYPT_MODULES. Notes from the pull:
# - /vendor/lib/modules/modules.load is an EMPTY file (0 bytes) and
#   /vendor/etc/modules.load does not exist — there is no modules.load
#   load order on this device; order came from modules.dep.
# - /vendor_dlkm/lib/modules/ is identical content — pull once.
# - Pull method that worked: tar to /data/local/tmp, then adb pull.
#   Do NOT cp to /sdcard (fails with Function not implemented) and do
#   NOT adb pull the directory directly as shell user (Permission
#   denied — module files are not world-readable; needs root).
# - racer_modules (prebuilt/Android.mk) copies this dir into the
#   recovery ramdisk at build time.
