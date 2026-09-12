# Hardware observations

These notes describe the inspected RMX3551 / RE5465 unit and matching hardware
images. Observed identities are distinguished from untested functionality.

## Identity and boot layout

- Project: `21605`; board: `Jennie-a`, `CAPE`; SoC: `SM8475`; Android platform: `taro`.
- The installed donor system reported `PJD110 / OP5929L1`. Those donor properties
  are not the physical identity and are not used as this product's model.
- Launch API 31, baseline VNDK 32; captured kernel
  `5.10.226-android12-9-o-g11c6e37b2a8e`.
- A/B boot components, virtual A/B and dynamic logical partitions.
- Boot header v4. Dedicated recovery has no kernel and depends on the matching
  boot/vendor_boot/DTBO combination.

| Physical partition | Bytes |
|---|---:|
| boot (each slot) | 201326592 |
| vendor_boot (each slot) | 201326592 |
| recovery (each slot) | 104857600 |
| dtbo (each slot) | 25165824 |
| super | 11274289152 |
| Configured dynamic group maximum | 11270094848 |

The new source product's dynamic group contains `system`, `system_ext`,
`product`, `vendor`, `odm`, `vendor_dlkm`, `odm_dlkm`. OEM `my_*` partitions are
not added to this new product layout. An untested flash script cannot be assumed
to convert the installed layout safely.

`vendor` and `odm` are EROFS; both DLKM images are **ext4**. System, system_ext and
product are configured as ext4 for the initial source build.

## Display and touch

- Display geometry: 1080 × 2412; initial density: 480.
- The inspected unit has an aftermarket replacement screen which works under
  its existing OS. BOE/Synaptics strings do not authenticate its manufacturer.
- Observed identifiers: BOE BF092_AB241, Synaptics S3910 / SY_BOE.
- Bound touch driver: `synaptics-s3910`, SPI device `spi0.0` under `soc/990000.spi`.
- Raw input capture received 429 position events and 260 SYN_REPORT events.
- ABS ranges: X = 0..8639, Y = 0..19295. These are not pixel dimensions. Recovery
  reads input-axis ranges; do not hardcode a 1080 × 2412 touch coordinate space.
- The baseline contains 456 ramdisk modules; the recovery load list references
  455 unique module filenames. It includes `oplus_bsp_tp_tcm_S3910.ko` and the
  associated common/custom modules.

Preserve the matched kernel, modules, DTB/DTBO and firmware during initial
bring-up. Runtime loading, display and touch under the new recovery are untested.

## Other hardware observations

- Fingerprint properties include `G_OPTICAL_JV0301` and `1011.10_BOE`.
  The observed process is the Oplus UFF fingerprint service. Enrollment,
  authentication and panel high-brightness coordination are untested.
- The camera provider exposes four normal cameras and five HAL devices.
  ODM configurations include `imx766.21605`, `s5kjn1sq03`, `s5k3p9` and `gc02m1b`.
  A complete physical-sensor-to-logical-camera-ID mapping is pending.
- The captured fstab uses FBE v2, wrapped keys and metadata encryption. The
  configuration does not prove a new recovery can decrypt existing data.
- A baseline audit indexed 3691 ELF files. 175 library names were outside the
  vendor/odm index; many may be provided by system/APEX/VNDK. They are not 175
  confirmed missing dependencies.
