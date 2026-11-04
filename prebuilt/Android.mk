LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
    LOCAL_MODULE := racer_modules
    LOCAL_MODULE_TAGS := optional
    LOCAL_MODULE_CLASS := ETC
    LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)
    LOCAL_POST_INSTALL_CMD += \
        mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/aera-device-runtime/modules; \
        cp -rf $(LOCAL_PATH)/vendor/lib/modules/. $(TARGET_RECOVERY_ROOT_OUT)/aera-device-runtime/modules/;
# NOTE (differs from garnet's garnet_modules):
# - No depmod step. Racer's modules are a flat layout
#   (prebuilt/vendor/lib/modules/*.ko, no <version>/ subdir) and the
#   modules.dep / modules.alias / modules.softdep files pulled from the
#   stock RPDS31 vendor are already in the tree and correct - depmod
#   would need a versioned subdir that does not exist on this device.
# - No camera.ko removal (racer has no such module).
# - Packaged install (2026-11-04): modules land in
#   /aera-device-runtime/modules and ro.aera.packaged_modules=true makes
#   the AERA loader (kernel_module_loader.cpp) use ONLY that directory.
#   The default flow loaded 0 modules on racer: it copies the mounted
#   device /vendor, whose modules.dep points into /vendor_dlkm where
#   only the 3 WLAN modules live. The packaged dir keeps module loading
#   independent of the installed ROM's vendor layout. modules.dep paths
#   in the tree are rewritten to /aera-device-runtime/modules/ to match.
include $(BUILD_PHONY_PACKAGE)
