# Provenance

The Android device configuration was assembled from read-only hardware
observations, boot-image metadata, module loading lists, partition sizes and
fstab from the inspected RMX3551. It does not inherit a donor phone's identity.

## OEM kernel and DTS reference

The OEM repositories were inspected at these pinned commits:

- [Android T kernel source](https://github.com/realme-kernel-opensource/realme_GT2-master-exploratory-AndroidT-kernel-source/tree/092f3fa0aa3916032fc4aa2c0101352541ecbd8b)
- [Android T vendor/kernel-platform source](https://github.com/realme-kernel-opensource/realme_GT2-master-exploratory-AndroidT-vendor-source/tree/18834d222ca80f4899673773894ecd163538b374)

The key board sources are under `kernel_platform/qcom/proprietary/devicetree/oplus/`:

- [jennie-21605-cape-overlay.dts](https://github.com/realme-kernel-opensource/realme_GT2-master-exploratory-AndroidT-vendor-source/blob/18834d222ca80f4899673773894ecd163538b374/kernel_platform/qcom/proprietary/devicetree/oplus/jennie-21605-cape-overlay.dts)
- [jennie_21605_overlay_common.dtsi](https://github.com/realme-kernel-opensource/realme_GT2-master-exploratory-AndroidT-vendor-source/blob/18834d222ca80f4899673773894ecd163538b374/kernel_platform/qcom/proprietary/devicetree/oplus/jennie_21605_overlay_common.dtsi)

[`metadata/dts-sources.json`](../metadata/dts-sources.json) records the 151
retrieved reference files with URL, Git blob and SHA-256. The OEM tree is an
older kernel (5.10.101); the running baseline is 5.10.226. Exact source and KMI
reproduction remain unresolved.

## Android build references

- [LineageOS android_build, lineage-23.2](https://github.com/LineageOS/android_build/tree/lineage-23.2)
- [LineageOS android_bootable_recovery, lineage-23.2](https://github.com/LineageOS/android_bootable_recovery/tree/lineage-23.2)
- [LineageOS android_vendor_lineage, lineage-23.2](https://github.com/LineageOS/android_vendor_lineage/tree/lineage-23.2)

Comparable SM8475/SM8450 trees informed build-variable research; this product
does not directly inherit them. The inspected OnePlus common reference at
`8b8694732bf21cde0e1186cfe73da5f1526cdef3` contained merge-conflict markers, so
its BoardConfig was not copied wholesale.

## Hardware images

The known-working baseline came from the inspected device and matching hardware
files in an existing port package. Vendor, ODM and both DLKM partition hashes
were compared and matched. Component hashes are provided for local verification;
firmware and kernel/module binaries are not included here.

The donor's replacement `my_product` image is not an input to this source
product. Donor applications and OEM feature configurations require a separate
compatibility review.
