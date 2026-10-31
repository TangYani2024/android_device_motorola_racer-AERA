LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
    LOCAL_MODULE := racer_modules
    LOCAL_MODULE_TAGS := optional
    LOCAL_MODULE_CLASS := ETC
    LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)
    LOCAL_POST_INSTALL_CMD += \
        mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/vendor; \
        cp -rf $(LOCAL_PATH)/vendor $(TARGET_RECOVERY_ROOT_OUT)/;
# NOTE (differs from garnet's garnet_modules):
# - No depmod step. Racer's modules are a flat layout
#   (prebuilt/vendor/lib/modules/*.ko, no <version>/ subdir) and the
#   modules.dep / modules.alias / modules.softdep files pulled from the
#   live LOS vendor are already in the tree and correct — depmod would
#   need a versioned subdir that does not exist on this device.
# - No camera.ko removal (racer has no such module).
# The AERA loader (kernel_module_loader.cpp) loads modules by name in
# the AERA_LOAD_VENDOR_MODULES order from BoardConfig.mk; that order was
# verified topologically against modules.dep on 2026-10-31.
include $(BUILD_PHONY_PACKAGE)
