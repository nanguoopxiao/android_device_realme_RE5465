# SPDX-License-Identifier: Apache-2.0
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/realme/RE5465/device.mk)
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Initial userdebug builds need automatic authenticated recovery ADB even when
# the bootloader's verified-boot property is unavailable. Keep ro.adb.secure=1.
ifeq ($(TARGET_BUILD_VARIANT),userdebug)
# This branch serializes any nonempty value (including "false") as true.
PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG :=
endif

PRODUCT_NAME := lineage_RE5465
PRODUCT_DEVICE := RE5465
PRODUCT_MANUFACTURER := realme
PRODUCT_BRAND := realme
PRODUCT_MODEL := realme GT2 Master Explorer Edition
