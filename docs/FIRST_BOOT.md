# First full-system bring-up

The source-built community-test02 image set booted LineageOS 23.2 / Android 16
and then booted again without changing images or clearing userdata. The Android
boot counter advanced from 2 to 3. Both boots retained the selected data SIM and
test-panel refresh settings, with SELinux enforcing. This is initial bring-up
evidence, not complete hardware qualification. An earlier private integration
trial reported first boot completion in about 34 seconds.

## Runtime fstab

The first-stage fstab in the vendor ramdisk already describes the seven Android
logical partition types used by this product. The retained vendor filesystem
also contains a second-stage fstab, invoked by its init scripts. That file still
referenced the ten omitted `my_*` partitions and corresponding bind-mount paths.
The unadapted combination did not complete normal startup in the device trial.

[`fstab.vendor.qcom`](../rootdir/fstab.vendor.qcom) preserves the vendor table's
other hardware entries while removing those 30 legacy rows. Its original license
notice is retained. The source configuration installs this table in system_ext;
[`init.re5465.rc`](../rootdir/init.re5465.rc) copies it into a labeled file in
`/dev` and binds that boot-local copy over the runtime vendor fstab before normal
filesystem mounting begins. Init creates the copy and mounts it; the necessary
storage services receive read access to that configuration.
The preserved vendor image itself remains byte-identical to the staged input.

The earlier trial used an equivalent table through a private debug helper. The
current source-native runtime-copy and bind implementation passed both boots
without that helper. Private helpers, kernel logs and diagnostic images are not
distributed with this repository.

## Early storage HAL ordering

A follow-up build completed the early filesystem mount but blocked in the late
mount. A bounded kernel trace showed vold repeatedly waiting for
`android.hardware.boot@1.0::IBootControl/default`, while init accumulated the
corresponding lazy-service start requests. The retained Boot Control 1.2 service
belongs to `early_hal`. Storage operations must not wait for a service whose
start or restart can only be handled after the blocked init action returns.

The device init configuration starts `early_hal` during `early-fs`, after the
bootstrap APEX phase and before filesystem/checkpoint operations can block init.
The exported runtime table has its own `re5465_fstab_file` label and scoped read
permissions for init, vold, vendor_init and Boot Control. Vendor Boot Control
uses `ReadDefaultFstab()` to find misc. Android's Treble policy forbids opening
generic system files to vendor HALs, so the source remains an immutable system
file and init exports only this specific configuration through tmpfs. No write
or execute access to system files is granted, and neverallow checks stay enabled.
The combined startup and configuration-access changes passed normal startup and
a repeat boot with existing userdata. Boot Control and vold processes were
present on both boots. These tests do not isolate the contribution of each change;
the failed candidate remains blocked from distribution.

## Dual-SIM network default

Without an explicit network default, both slots started in WCDMA-preferred mode
(mode 0), allowing GSM/WCDMA technologies but excluding LTE and NR. Both SIMs
were loaded and the vendor radio processes were running, yet network registration
was unavailable in the observed environment.

Selecting NR/LTE multimode through Android's supported telephony command restored
registration on both slots. `ro.telephony.default_network=27,27` reproduces that
default for fresh installations. Both slots reported NR-SA registration; the
user-selected data subscription established a cellular connection that Android
marked as internet-validated. Selecting the data SIM remains a user preference.

### Why Settings could show LTE while connected to 5G

Both slots reported a supported radio mask of `0x89004`, including NR. The
carrier configuration allowed NSA and SA (`carrier_nr_availabilities_int_array`
contained 1 and 2). However, `getAllowedNetworkTypesForReason(CARRIER)` returned
`0xc387`, without NR or LTE, while the user reason included both technologies.

`Phone.getAllowedNetworkTypes()` falls back to `RILConstants.PREFERRED_NETWORK_MODE`
when the requested reason has no stored entry. With `ro.telephony.default_network`
absent, that constant is WCDMA-preferred. The modem's effective mask calculation
intersects only stored entries, explaining why the UI query and the actual radio
could disagree. Settings requires NR in both the supported mask and carrier
query, and reduces NR modes to LTE for display when that check fails.

The same `27,27` property corrects the fresh-install default and this fallback.
It does not force 5G-only operation or override an explicit carrier restriction.
The source-built image was checked on-device twice: the menu offered 5G
(recommended), LTE and 3G, with 5G selected; both carrier queries contained NR/LTE
(`0xcfbff`) and both radios registered on NR-SA. The selection persisted across
reboot. A single test phone's data subscription ID is never baked into the ROM.

Calls, SMS, IMS framework integration, emergency calling, camera, fingerprint,
power management and sustained stability still need separate testing. Network
registration alone does not establish that these functions work.

## Replacement screen

The inspected replacement panel is reported to support only 60 Hz, although the
retained kernel advertises 60/90/120 Hz modes. The running-system test used a
60 Hz limit. This is a condition of the test unit, not a claim that every RE5465
has this limitation.

Recovery menu refresh remains a known issue; further Recovery UI debugging was
deferred. Initial system testing used computer-controlled bootloader flashing
without depending on that menu.

## USB debugging and installer validation scope

Shared builds no longer pre-authorize a development computer. On the tested unit,
USB debugging needed an off/on toggle after reboot before ADB connected. This
USB initialization issue is recorded separately from Android boot completion.

The exact test02 eight-image set was written through the Windows flashing core
with existing userdata retained, followed by the repeat boot above. The public
entry point performs a clean installation. Its erase/format command sequence and
failure handling have static and simulated checks; an end-to-end clean install
through this exact public entry point remains a separate qualification step.
