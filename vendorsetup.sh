#
# vendorsetup.sh for Motorola racer (AERA Recovery).
# Adapted from the garnet tree's vendorsetup.sh.
#

FDEVICE="racer"

aera_get_target_device() {
	local script_path
	script_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
	if echo "$script_path" | grep -q "/$FDEVICE$"; then
		AERA_BUILD_DEVICE="$FDEVICE"
	elif echo "$0" | grep -q "$FDEVICE"; then
		AERA_BUILD_DEVICE="$FDEVICE"
	fi
}

if [ -z "$AERA_BUILD_DEVICE" ]; then
	aera_get_target_device
fi

if [ "$1" = "$FDEVICE" ] || [ "$AERA_BUILD_DEVICE" = "$FDEVICE" ]; then
	export LC_ALL="C"
	export AERA_AB_DEVICE=1
	# NOTE: no AERA_VIRTUAL_AB_DEVICE — racer is regular A/B (see TODO-4).
	export AERA_VANILLA_BUILD=1
	export AERA_PRODUCT_PREFIX=AERA
	export AERA_BUILD_STATUS=Unofficial
	export AERA_BUILD_TYPE=Alpha
	export AERA_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
	export AERA_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"

	export AERA_USE_BASH_SHELL=1
	export AERA_USE_TAR_BINARY=1
	export AERA_USE_SED_BINARY=1
	export AERA_USE_LZ4_BINARY=1
	export AERA_USE_ZSTD_BINARY=1
	export AERA_USE_DATE_BINARY=1
	export AERA_USE_GREP_BINARY=1
	export AERA_USE_BUSYBOX_BINARY=1
	export AERA_USE_XZ_UTILS=1
	export AERA_USE_NANO_EDITOR=1
	export AERA_DELETE_AROMAFM=1
	export AERA_DELETE_MAGISK_ADDON=1
	export AERA_USE_UPDATED_MAGISKBOOT=1
	export AERA_USE_FSCK_EROFS_BINARY=1
	export AERA_USE_PATCHELF_BINARY=1

	export AERA_SETTINGS_ROOT_DIRECTORY=/data/recovery
	export AERA_MISCELLANEOUS_ROOT_DIRECTORY=/sdcard
	export AERA_ALLOW_EARLY_SETTINGS_LOAD=1

	# TODO-8: only XT2063-2 is confirmed so far.
	export TARGET_DEVICE_ALT="XT2063-2"
	export AERA_TARGET_DEVICES="$TARGET_DEVICE_ALT"
	export AERA_ENABLE_ROOT_MANAGER=1

	# AERA begins at R1.0; do not append legacy variant or patch suffixes.
	unset AERA_VARIANT
	unset AERA_MAINTAINER_PATCH_VERSION
fi
