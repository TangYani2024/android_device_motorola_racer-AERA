#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# BoardConfig for Motorola racer (AERA Recovery).
# Platform values come from LineageOS 23.2
# (device/motorola/sm7250-common/BoardConfigCommon.mk and
# device/motorola/racer/BoardConfig.mk); AERA flags mirror the garnet tree.
#

# Inherit from sm7250-common
include device/motorola/sm7250-common/BoardConfigCommon.mk

DEVICE_PATH := device/motorola/racer

# Display (LOS: TARGET_SCREEN_DENSITY := 420; panel 1080x2340, 90 Hz)
TARGET_SCREEN_DENSITY := 420

# Recovery
TARGET_OTA_ASSERT_DEVICE := racer

# AERA UI
# 90 Hz panel (garnet uses 120 for its 120 Hz panel)
AERA_FRAMERATE := 90
AERA_UI_ADAPTIVE_RESOLUTION := true

# Vibrator: no AIDL vibrator HAL known in recovery for racer (see TODO-6)
AERA_NO_HAPTICS := true

# default brightness (TODO-3: guess, half of max; adjust after first boot)
AERA_DEFAULT_BRIGHTNESS := 1023

# max brightness: kernel panel DTS, all four racer panels
# (dsi-panel-mot-*-racer-cmd-common.dtsi):
#   qcom,mdss-dsi-bl-max-level = <2047>
AERA_MAX_BRIGHTNESS := 2047

# enable screen blanking (disable this if some touch panels misbehave)
AERA_NO_SCREEN_BLANK := true

# device-specific system/vendor props
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# device-specific fstab
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab

# kernel: prebuilt stock 14-13 kernel, extracted from the user's own
# verified boot_b dump (4.19.125-perf+, 37,376,016 bytes, raw ARM64 Image).
# DTB and DTBO alongside it are from the same dump set.
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img

# -------- from lineage DT -------------
# we're qcom
BOARD_USES_QCOM_HARDWARE := true

AERA_USE_LEGACY_BATTERY_SERVICES := true

# Keymint HAL for decryption (garnet pattern).
# VERIFIED 2026-10-31 from the live LOS 23.2 vendor:
#   /vendor/lib64/android.hardware.security.keymint-V1-ndk.so exists,
#   keymaster service is android.hardware.keymaster@4.0-service-qti
#   (binary /vendor/bin/hw/android.hardware.keymaster@4.0-service-qti,
#   class early_hal, user system, group system drmrpc),
#   gatekeeper impl /vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl-qti.so
#   exists, qseecomd is in /vendor/bin. The 18 binaries are now in
#   sm7250-common/twrp/recovery/root/ (TODO-2 done).
#   Two findings from the agent's 2026-10-31 check:
#   - android.hardware.security.secureclock-V1-ndk.so EXISTS on the
#     device and keymint-V1-ndk.so links against it (readelf NEEDED),
#     so it is packed below alongside keymint.
#   - android.hardware.security.sharedsecret-V1-ndk.so does NOT exist
#     on this device (and nothing links against it), so NO sharedsecret
#     _platform symlink is created — garnet's three-symlink block
#     would leave a dangling link here.
TARGET_RECOVERY_DEVICE_MODULES += android.hardware.security.keymint-V1-ndk android.hardware.security.secureclock-V1-ndk
RECOVERY_LIBRARY_SOURCE_FILES += $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.security.keymint-V1-ndk.so $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.security.secureclock-V1-ndk.so
BOARD_RECOVERY_IMAGE_PREPARE += mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/system/lib64; ln -sf android.hardware.security.keymint-V1-ndk.so $(TARGET_RECOVERY_ROOT_OUT)/system/lib64/android.hardware.security.keymint-V1-ndk_platform.so; ln -sf android.hardware.security.secureclock-V1-ndk.so $(TARGET_RECOVERY_ROOT_OUT)/system/lib64/android.hardware.security.secureclock-V1-ndk_platform.so;

# Modules to load after /data is decrypted (WLAN + rmnet data path).
# VERIFIED 2026-10-31: racer has no cnss_* modules at all — its WLAN is a
# single qca_cld3_wlan.ko (no deps) and the data path is rmnet_perf.ko /
# rmnet_shs.ko (no deps). The AERA loader stages these from the mounted
# /vendor_dlkm at boot and loads them after decryption, skipping any that
# are already loaded (kernel_module_loader.cpp: Load_Post_Decrypt_Modules),
# so qca_cld3_wlan.ko also appearing in AERA_LOAD_VENDOR_MODULES below
# is harmless — same overlap garnet uses for its cnss stack.
AERA_POST_DECRYPT_MODULES := "qca_cld3_wlan.ko rmnet_perf.ko rmnet_shs.ko"

# Kernel modules to load in recovery.
# VERIFIED 2026-10-31 from the live LOS 23.2 vendor (79 .ko files pulled
# to prebuilt/vendor/lib/modules/): /vendor/lib/modules/modules.load is
# an EMPTY file (0 bytes) - there is no modules.load load order on this
# device, so the order below was derived from /vendor/lib/modules/
# modules.dep instead (topological sort, deps first) and checked against
# the LOS tree's BOARD_RECOVERY_KERNEL_MODULES_LOAD: the set is
# self-contained (no dep outside the set) and topologically valid.
# 2026-11-03 size cut (recovery.img exceeded the boot partition): the
# audio sequence (42 modules, ~10.5 MB) was removed - the AERA audio
# bridge is not ported for racer, so recovery has no audio path anyway;
# aw8695 haptics was removed (AERA_NO_HAPTICS is set); and six modules
# that were packaged but never loaded (gspca_main, st21nfc, stmvl53l1,
# watchdog_cpu_ctx, watchdogtest, synaptics_zeroflash) were dropped.
# The .ko files were deleted in the same commit; restore from git
# history if ever needed. WLAN (qca_cld3_wlan.ko) is kept on purpose.
AERA_LOAD_VENDOR_MODULES := "utags.ko mmi_annotate.ko mmi_info.ko tzlog_dump.ko mmi_sys_temp.ko qpnp-power-on-mmi.ko qpnp-smbcharger-mmi.ko slg5bm43670.ko sensors_class.ko sx933x_sar.ko mmi_relay.ko touchscreen_mmi.ko goodix_v1430_mmi.ko goodix_v1430_update_mmi.ko goodix_v1430_ts_tools_mmi.ko goodix_fod_mmi.ko sec_mmi.ko synaptics_i2c.ko synaptics_core_module.ko synaptics_device.ko synaptics_diagnostics.ko synaptics_recovery.ko synaptics_reflash.ko synaptics_testing.ko aov_trigger.ko cci_intf.ko moto_f_usbnet.ko qca_cld3_wlan.ko"
AERA_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true

# Partitions
BOARD_DTBOIMG_PARTITION_SIZE := 2097152
