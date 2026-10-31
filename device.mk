#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# device.mk for Motorola racer (AERA Recovery).
# Adapted from the garnet tree's device.mk.
#

# include (not inherit-product) the common settings - works better with device-specific files
-include $(COMMON_PATH)/device-common.mk

AERA_DEFAULT_LANGUAGE     := en
AERA_USE_TOOLBOX          := true
AERA_INCLUDE_NTFS_3G      := true
AERA_INCLUDE_REPACKTOOLS  := true
AERA_INCLUDE_LIBRESETPROP := true
AERA_EXTRA_LANGUAGES      := true
AERA_EXCLUDE_APEX         := true
AERA_INCLUDE_FASTBOOTD    := true

# TODO: OEM otacert. Garnet uses vendor/recovery/security/miui (Xiaomi).
# For racer there is no OEM otacert in the tree yet; the sm7250-common
# tree carries security/otacert.x509.pem as a placeholder. Add the real
# one here if signed-OTA verification is needed, otherwise leave unset.
# PRODUCT_EXTRA_RECOVERY_KEYS += \
#     vendor/recovery/security/racer

# Enable updating of APEXes
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# NOTE: no virtual_ab_ota inherit — racer is regular A/B, not virtual A/B
# (see TODO-4). Garnet inherits virtual_ab_ota/launch_with_vendor_ramdisk.mk;
# racer must not.

# clear this, so that the device-specific recovery/root/ folder is included automatically by the build system
# requires including, rather than inheriting the common settings
TARGET_RECOVERY_DEVICE_DIRS :=

# copy recovery/root/ from the common directory
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(COMMON_PATH)/twrp/recovery/root/,$(TARGET_COPY_OUT_RECOVERY)/root/)

# copy recovery/root/ from the device directory (if it exists)
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/recovery/root/,$(TARGET_COPY_OUT_RECOVERY)/root/)

# AERA-specific settings
$(call inherit-product, $(DEVICE_PATH)/aera_racer.mk)

# modules (prebuilt vendor .ko files, pulled from the live LOS vendor
# 2026-10-31 — see prebuilt/README.md; load order is AERA_LOAD_VENDOR_MODULES
# in BoardConfig.mk, verified against modules.dep)
PRODUCT_PACKAGES += \
    racer_modules

# TODO: aera-audio-bridge is device-specific (garnet ships audio/
# with its own aera_audio_bridge.cpp for its audio HAL). Racer's audio
# stack is Moto/Cirrus (madera + cs35l41). Audio in recovery is
# non-essential for v1, so the package is disabled until someone ports
# the bridge; see audio/README.md. Re-enable when audio/ is ported.
# PRODUCT_PACKAGES += \
#     aera-audio-bridge
