# SPDX-License-Identifier: Apache-2.0
LOCAL_PATH := device/realme/RE5465

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_ramdisk.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)

PRODUCT_SHIPPING_API_LEVEL := 31
PRODUCT_EXTRA_VNDK_VERSIONS := 32
PRODUCT_USE_DYNAMIC_PARTITIONS := true
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += boot vendor_boot recovery dtbo system system_ext product vendor odm vendor_dlkm odm_dlkm vbmeta vbmeta_system vbmeta_vendor

TARGET_SCREEN_WIDTH := 1080
TARGET_SCREEN_HEIGHT := 2412
TARGET_SCREEN_DENSITY := 480
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxhdpi

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/fstab.qcom:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.qcom \
    $(LOCAL_PATH)/rootdir/fstab.vendor.qcom:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/fstab.re5465 \
    $(LOCAL_PATH)/rootdir/init.re5465.rc:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/init/init.re5465.rc \
    $(LOCAL_PATH)/recovery/init.recovery.qcom.rc:recovery/root/init.recovery.qcom.rc

# Let upstream Lineage recovery select ADB or fastbootd without a touchscreen.
# Private lab builds may explicitly pre-authorize a locally staged public key.
# Shared builds must leave this option unset, even when using userdebug.
ifeq ($(RE5465_INCLUDE_PRIVATE_ADB_KEY),true)
ifneq ($(filter eng userdebug,$(TARGET_BUILD_VARIANT)),)
PRODUCT_ADB_KEYS := $(LOCAL_PATH)/recovery/adb_keys
# The root /adb_keys link points here. Recovery must carry its own copy so
# authentication never depends on mounting the installed product or userdata.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/adb_keys:recovery/root/product/etc/security/adb_keys
else
$(error RE5465_INCLUDE_PRIVATE_ADB_KEY is only supported for eng/userdebug)
endif
endif

PRODUCT_PACKAGES += \
    android.hardware.fastboot-service.example_recovery \
    fastbootd

PRODUCT_SYSTEM_PROPERTIES += ro.sf.lcd_density=480
# Both slots otherwise fall back to WCDMA-preferred (2G/3G only). This NR/LTE
# multimode selection matches the network mask verified on both local SIM slots.
# Phone.getAllowedNetworkTypes(CARRIER) also uses this fallback; without NR in
# that fallback, Settings hides 5G even while the modem is registered on NR-SA.
PRODUCT_SYSTEM_PROPERTIES += ro.telephony.default_network=27,27
PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)
