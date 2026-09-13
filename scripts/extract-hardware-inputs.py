#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Recover pinned hardware inputs from an unpacked RE5465 community-test02 package.

Linux, Python 3.11+, simg2img, lpunpack and lz4 are required. Only the explicitly
selected new output directory is populated. No phone or network is accessed.
This recovers image-based inputs; it does not decompile proprietary software or
create a curated per-file vendor build.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path, PurePosixPath
import shutil
import stat
import struct
import subprocess
import sys
import tempfile

DEVICE = Path(__file__).resolve().parents[1]
PARTITIONS = ('vendor', 'odm', 'vendor_dlkm', 'odm_dlkm')


def staging_module():
    spec = importlib.util.spec_from_file_location('re5465_stage', DEVICE / 'scripts/prepare-prebuilts.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def tool_path(name, android_root, host_tools):
    roots = []
    if host_tools is not None:
        roots.append(host_tools)
    if android_root is not None:
        roots += [android_root / 'out/host/linux-x86/bin',
                  android_root / 'prebuilts/extract-tools/linux-x86/bin',
                  android_root / 'prebuilts/build-tools/linux-x86/bin']
    for root in roots:
        path = root / name
        if path.is_file() and os.access(path, os.X_OK):
            return path.resolve()
    found = shutil.which(name)
    if found:
        return Path(found).resolve()
    raise ValueError(f'Missing {name}: provide --host-tools or install the matching host tool.')


def align(size, page):
    return ((size + page - 1) // page) * page


def image_regions(boot, vendor):
    """Validate v4 bounds before extracting the kernel, DTB and vendor ramdisk."""
    with boot.open('rb') as stream:
        header = stream.read(4096)
    if len(header) != 4096 or header[:8] != b'ANDROID!' or struct.unpack_from('<I', header, 40)[0] != 4:
        raise ValueError('Expected boot header v4')
    kernel_size = struct.unpack_from('<I', header, 8)[0]
    if not kernel_size or 4096 + kernel_size > boot.stat().st_size:
        raise ValueError('Invalid kernel bounds')
    with vendor.open('rb') as stream:
        header = stream.read(4096)
    if len(header) != 4096 or header[:8] != b'VNDRBOOT' or struct.unpack_from('<I', header, 8)[0] != 4:
        raise ValueError('Expected vendor_boot header v4')
    page = struct.unpack_from('<I', header, 12)[0]
    ramdisk_size = struct.unpack_from('<I', header, 24)[0]
    header_size, dtb_size = struct.unpack_from('<II', header, 2096)
    table_size, table_entries, entry_size = struct.unpack_from('<III', header, 2112)
    if page != 4096 or header_size != 2128 or table_entries != 1 or entry_size != 108 or table_size != 108:
        raise ValueError('Expected the pinned single-fragment vendor_boot layout')
    ramdisk_offset = align(header_size, page)
    dtb_offset = ramdisk_offset + align(ramdisk_size, page)
    table_offset = dtb_offset + align(dtb_size, page)
    if not ramdisk_size or not dtb_size or table_offset + table_size > vendor.stat().st_size:
        raise ValueError('Invalid vendor ramdisk/DTB bounds')
    with vendor.open('rb') as stream:
        stream.seek(table_offset)
        fragment = stream.read(12)
    if struct.unpack('<III', fragment) != (ramdisk_size, 0, 1):
        raise ValueError('Expected one complete platform ramdisk')
    return (4096, kernel_size), (ramdisk_offset, ramdisk_size), (dtb_offset, dtb_size)


def copy_region(source, target, region):
    offset, remaining = region
    target.parent.mkdir(parents=True, exist_ok=True)
    with source.open('rb') as original, target.open('xb') as output:
        original.seek(offset)
        while remaining:
            data = original.read(min(1024 * 1024, remaining))
            if not data:
                raise ValueError('Truncated image region')
            output.write(data)
            remaining -= len(data)


def module_payloads(data, required):
    """Read newc CPIO in memory; never extract its paths or symlinks onto the host."""
    offset, seen, modules = 0, set(), {}
    while offset + 110 <= len(data):
        header = data[offset:offset + 110]
        if header[:6] not in (b'070701', b'070702'):
            raise ValueError('Invalid CPIO header')
        fields = [int(header[6 + i * 8:14 + i * 8], 16) for i in range(13)]
        name_size, size, mode = fields[11], fields[6], fields[1]
        start = offset + 110
        if not 1 <= name_size <= 4096 or start + name_size > len(data):
            raise ValueError('Invalid CPIO name bounds')
        raw_name = data[start:start + name_size]
        if not raw_name.endswith(b'\0'):
            raise ValueError('Unterminated CPIO name')
        name = raw_name[:-1].decode('utf-8').removeprefix('./')
        offset = align(start + name_size, 4)
        if offset + size > len(data):
            raise ValueError('Truncated CPIO entry')
        payload = data[offset:offset + size]
        offset = align(offset + size, 4)
        if header[:6] == b'070702' and sum(payload) & 0xffffffff != fields[12]:
            raise ValueError('Invalid CPIO CRC')
        if name == 'TRAILER!!!':
            if set(modules) != required:
                raise ValueError('Missing expected ramdisk modules')
            return modules
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name or name in seen:
            raise ValueError('Unsafe or duplicate CPIO path: ' + name)
        seen.add(name)
        if name in required:
            if not stat.S_ISREG(mode):
                raise ValueError('Expected a regular kernel module: ' + name)
            modules[name] = payload
    raise ValueError('CPIO trailer missing')


def run(command, log):
    with log.open('wb') as output:
        result = subprocess.run([str(value) for value in command], stdout=output,
                                stderr=subprocess.STDOUT, timeout=600)
    if result.returncode:
        raise ValueError('Host tool failed: ' + log.read_text(errors='replace')[-1600:])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--images-dir', required=True, type=Path)
    parser.add_argument('--output-dir', required=True, type=Path, help='New output directory, must not exist')
    parser.add_argument('--android-root', type=Path, help='Lineage/AOSP checkout containing host tools')
    parser.add_argument('--host-tools', type=Path, help='Optional directory containing simg2img/lpunpack/lz4')
    args = parser.parse_args()
    if sys.platform != 'linux':
        raise ValueError('Run this extraction tool on Linux; the Windows flasher is separate.')
    stage = staging_module()
    inputs = json.loads((DEVICE / 'metadata/hardware-extraction-sources.json').read_text())
    hardware = json.loads((DEVICE / 'metadata/prebuilt-inputs.json').read_text())['files']
    names = [row['name'] for row in inputs['images']]
    if inputs['schema_version'] != 1 or len(names) != 4 or set(names) != {'boot.img', 'vendor_boot.img', 'dtbo.img', 'super.img'}:
        raise ValueError('Invalid extraction source manifest')
    for row in inputs['images']:
        if not re.fullmatch(r'[0-9a-f]{64}', row['sha256']) or row['size'] <= 0:
            raise ValueError('Invalid container digest or size in manifest')
    images = args.images_dir.resolve(strict=True)
    output = args.output_dir.absolute()
    if output.exists() or output.is_symlink():
        raise ValueError('Output already exists; choose a new directory')
    parent = output.parent.resolve(strict=True)
    output = parent / output.name
    if output == images or output.is_relative_to(images):
        raise ValueError('Keep extracted inputs outside the source images directory')
    tools = {name: tool_path(name, args.android_root, args.host_tools)
             for name in ('simg2img', 'lpunpack', 'lz4')}
    for row in inputs['images']:
        if not stage.matching(stage.inside(images, row['name']), row):
            raise ValueError('Container is not from the pinned test02 set: ' + row['name'])
        print('Verified container:', row['name'], flush=True)
    needed_space = inputs['expanded_super_bytes'] + sum(row['size'] for row in hardware) + 1024**3
    if shutil.disk_usage(parent).free < needed_space:
        raise ValueError('Insufficient working space; allow at least 16 GiB free')
    rows = {row['path']: row for row in hardware}
    with tempfile.TemporaryDirectory(prefix='.re5465-extract-', dir=parent) as temporary:
        work = Path(temporary)
        result = work / 'hardware'
        result.mkdir()
        kernel_region, ramdisk_region, dtb_region = image_regions(images / 'boot.img', images / 'vendor_boot.img')
        copy_region(images / 'boot.img', result / 'kernel/Image', kernel_region)
        copy_region(images / 'vendor_boot.img', result / 'dtb/gt2master.dtb', dtb_region)
        copy_region(images / 'vendor_boot.img', work / 'vendor-ramdisk.lz4', ramdisk_region)
        cpio = work / 'vendor-ramdisk.cpio'
        run([tools['lz4'], '-d', str(work / 'vendor-ramdisk.lz4'), str(cpio)], work / 'lz4.log')
        if cpio.stat().st_size > 1024**3:
            raise ValueError('Unexpected ramdisk expansion size')
        required = {'lib/modules/' + Path(name).name for name in rows if name.startswith('ramdisk-modules/')}
        modules = module_payloads(cpio.read_bytes(), required)
        module_dir = result / 'ramdisk-modules'
        module_dir.mkdir()
        for name, payload in modules.items():
            (module_dir / Path(name).name).write_bytes(payload)
        shutil.copyfile(images / 'dtbo.img', result / 'dtbo.img')
        print('Extracted kernel, DTB, DTBO and', len(modules), 'modules', flush=True)
        raw = work / 'super.raw.img'
        run([tools['simg2img'], images / 'super.img', raw], work / 'simg2img.log')
        if raw.stat().st_size != inputs['expanded_super_bytes']:
            raise ValueError('Unexpected super geometry')
        unpacked = work / 'unpacked'
        unpacked.mkdir()
        command = [tools['lpunpack']]
        for partition in PARTITIONS:
            command += ['-p', partition + '_a']
        run([*command, raw, unpacked], work / 'lpunpack.log')
        (result / 'images').mkdir()
        for partition in PARTITIONS:
            (unpacked / (partition + '_a.img')).rename(result / 'images' / (partition + '.img'))
        actual = []
        for name, row in rows.items():
            path = stage.inside(result, name)
            if not stage.matching(path, row):
                raise ValueError('Recovered input failed verification: ' + name)
            digest = stage.digest(path)
            actual.append({'path': name, 'sha256': digest, 'canonical': digest == row['sha256']})
        report = {'source_package': inputs['package'], 'verified_files': len(actual),
                  'modules': len(modules), 'files': actual, 'device_accessed': False,
                  'note': 'Image-based hardware inputs recovered; per-file vendor curation is separate.'}
        (result / 'extraction-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        if output.exists() or output.is_symlink():
            raise ValueError('Output appeared during extraction; refusing to replace it')
        result.rename(output)
    print(json.dumps({'output_directory': str(output), 'verified_files': len(rows),
                      'known_alternate_files': sum(not row['canonical'] for row in actual),
                      'device_accessed': False}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print('Error: ' + str(error), file=sys.stderr)
        sys.exit(1)
