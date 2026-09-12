#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify and stage locally supplied RE5465 hardware inputs and an ADB public key.

No network access, device access or firmware extraction is performed. Every
source and existing destination is checked before copying. Conflicts are errors.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import struct
import sys

DEVICE = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def inside(root, relative):
    parts = PurePosixPath(relative)
    if parts.is_absolute() or '..' in parts.parts or '\\' in relative or ':' in relative:
        raise ValueError('Unsafe manifest path: ' + relative)
    target = (root / relative).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError('Path escapes the selected directory: ' + relative)
    return target


def matching(path, row):
    return path.is_file() and path.stat().st_size == row['size'] and digest(path) == row['sha256']


def public_key(path):
    data = path.read_bytes().strip()
    if b'PRIVATE KEY' in data or b'-----BEGIN' in data:
        raise ValueError('Supply an Android ADB public key (.pub), never a private key.')
    lines = [line for line in data.splitlines() if line.strip()]
    if len(lines) != 1:
        raise ValueError('Expected one ADB public key.')
    token = lines[0].split()[0]
    decoded = base64.b64decode(token, validate=True)
    # Android RSAPublicKey: len, n0inv, modulus[64], rr[64], exponent.
    if len(decoded) != 524 or struct.unpack_from('<I', decoded)[0] != 64:
        raise ValueError('The file is not an Android ADB RSA public key.')
    if struct.unpack_from('<I', decoded, 520)[0] not in (3, 65537):
        raise ValueError('Unexpected ADB RSA exponent.')
    return data + b'\n', token


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, help='Private vendor/realme/RE5465-shaped directory')
    parser.add_argument('--android-root', type=Path, help='Destination Android source checkout')
    parser.add_argument('--verify-only', action='store_true', help='Check inputs without writing')
    parser.add_argument('--adb-public-key', type=Path, help='Development computer Android adbkey.pub')
    args = parser.parse_args()
    if args.source_dir is None and args.adb_public_key is None:
        parser.error('Provide --source-dir or --adb-public-key.')
    if args.source_dir is not None and not args.verify_only and args.android_root is None:
        parser.error('Staging hardware files requires --android-root; use --verify-only to check.')
    if args.android_root is not None and args.source_dir is None:
        parser.error('--android-root is used with --source-dir.')

    copy_plan = []
    verified = 0
    if args.source_dir is not None:
        source = args.source_dir.resolve(strict=True)
        if not source.is_dir():
            raise ValueError('The source directory does not exist.')
        manifest = json.loads((DEVICE / 'metadata/prebuilt-inputs.json').read_text())
        rows = manifest['files']
        if not rows or len({row['path'] for row in rows}) != len(rows):
            raise ValueError('The input manifest is empty or contains duplicate paths.')
        destination = None
        if args.android_root is not None:
            android = args.android_root.resolve(strict=True)
            if not (android / 'build/envsetup.sh').is_file():
                raise ValueError('Destination is not an Android source checkout.')
            if not args.verify_only and (android / 'device/realme/RE5465').resolve() != DEVICE:
                raise ValueError('Run the device script installed in the destination Android checkout.')
            destination = inside(android, 'vendor/realme/RE5465')

        failures = []
        for row in rows:
            path = inside(source, row['path'])
            if not matching(path, row):
                failures.append('Input missing or mismatched: ' + row['path'])
                continue
            verified += 1
            if destination is not None:
                target = inside(destination, row['path'])
                if target.exists():
                    if not matching(target, row):
                        failures.append('Conflicting destination: ' + row['path'])
                else:
                    copy_plan.append((path, target, row))
        if failures:
            raise ValueError('\n'.join(failures[:20]) + ('\nAdditional errors omitted.' if len(failures) > 20 else ''))

    key_plan = None
    if args.adb_public_key is not None:
        content, token = public_key(args.adb_public_key.resolve(strict=True))
        target = DEVICE / 'recovery/adb_keys'
        if target.is_symlink():
            raise ValueError('Refusing to write an ADB key through a symlink.')
        if target.exists():
            _, existing = public_key(target)
            if existing != token:
                raise ValueError('recovery/adb_keys already contains a different key; review it manually.')
        else:
            key_plan = (target, content)

    if not args.verify_only:
        for source, target, row in copy_plan:
            target.parent.mkdir(parents=True, exist_ok=True)
            # Exclusive creation prevents silently overwriting a concurrent file.
            with source.open('rb') as original, target.open('xb') as output:
                shutil.copyfileobj(original, output, length=1024 * 1024)
            if not matching(target, row):
                raise ValueError('Copied file failed verification: ' + row['path'])
        if key_plan is not None:
            target, content = key_plan
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as output:
                output.write(content)
            target.chmod(0o600)

    print(json.dumps({'verified_hardware_files': verified,
                      'copied_hardware_files': 0 if args.verify_only else len(copy_plan),
                      'adb_public_key_validated': args.adb_public_key is not None,
                      'verify_only': args.verify_only, 'device_modified': False}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print('Error: ' + str(error), file=sys.stderr)
        sys.exit(1)
