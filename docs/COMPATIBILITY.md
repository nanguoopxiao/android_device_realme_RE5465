# Vendor compatibility preflight

The preserved vendor baseline uses VNDK 32 and FCM level 6. The device keeps
`PRODUCT_EXTRA_VNDK_VERSIONS := 32`; this branch installs its compatibility APEX
under `system_ext/apex/` and declares the version through `system_ext_manifest.xml`.

On 2026-09-12 the built VNDK APEX contained all 146 VNDK library groups required
by the inspected CPU binaries, with payload hashes matching the snapshot. Another
28 LLNDK groups must be checked against the complete target system runtime.
LLNDK snapshot stubs were excluded from runtime-provider accounting. DSP/Xtensa
objects are classified separately from ARM/AArch64 binaries.

## Device-specific framework matrix

[`configs/framework_compatibility_matrix.xml`](../configs/framework_compatibility_matrix.xml)
declares the retained vendor extensions. It was generated with AOSP
`assemble_vintf -m -l` from the selected cape vendor manifest, manifest fragments,
ODM fragments and the captured dynamic manifests, then restricted to vendor
namespaces. [Input hashes](../metadata/vendor-matrix-provenance.json) record its
provenance.

The 139 entries (95 HIDL, 44 AIDL) use explicit instance names. There are no
`android.*` overrides, wildcard instances or changes to upstream kernel checks.
Optional declarations acknowledge those retained interfaces; they do not
implement Oplus/Qualcomm features in LineageOS or prove that a HAL runs.

The matrix was serialized by the LineageOS 23.2 tool with schema version 9.0.
For another Android branch, regenerate and validate it using that branch's
VINTF tools; schema compatibility is part of the porting work.

## Kernel-generated manifests

Two ODM XML links refer to runtime proc files:

- `/proc/oplusVersion/manifest`: secure-element interfaces.
- `/proc/oplusManifest/network_manifest`: radio and vendor communication interfaces.

The inspected profile was vendor SKU `cape`, hardware SKU `0`, radio mode `dsds`.
The offline check materialized the real contents captured from that hardware.
Keep the dependency when replacing the kernel, or provide equivalent explicit
device manifest fragments after reviewing the selected hardware/SIM profile.
Do not silently drop the links because they cannot be resolved on a build host.

## Validation scope

The vendor metadata check and the framework/vendor compatibility preflight both
returned exit code 0; the latter reported `COMPATIBLE` with the captured 5.10.226
kernel configuration. The view contained the currently built framework metadata
and VNDK APEX, not every component of a completed ROM. The check must be repeated
against the final images, alongside symbol/namespace, SELinux and device tests.

The original AIDL NFC declaration produces an ignored legacy transport-tag
warning. Neither the original hardware images nor the phone were modified by
these checks.
