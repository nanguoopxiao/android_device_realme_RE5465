#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Parser rejection and input-pinning tests; no phone, images or host tools needed."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import unittest


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


extract = load('extract_hardware', 'extract-hardware-inputs.py')
stage = load('prepare_hardware', 'prepare-prebuilts.py')


def entry(name, payload=b'', mode=stat.S_IFREG | 0o644):
    raw = name.encode() + b'\0'
    fields = [1, mode, 0, 0, 1, 0, len(payload), 0, 0, 0, 0, len(raw), 0]
    result = b'070701' + b''.join(f'{value:08x}'.encode() for value in fields) + raw
    result += b'\0' * (-len(result) % 4)
    result += payload
    return result + b'\0' * (-len(result) % 4)


class MemoryFile:
    def __init__(self, data):
        self.data = data

    def is_file(self):
        return True

    def stat(self):
        return type('Stat', (), {'st_size': len(self.data)})()

    def open(self, _mode):
        return io.BytesIO(self.data)


class ExtractionTests(unittest.TestCase):
    def test_published_pin_format_and_dtbo_agreement(self):
        sources = json.loads((extract.DEVICE / 'metadata/hardware-extraction-sources.json').read_text())
        rows = json.loads((extract.DEVICE / 'metadata/prebuilt-inputs.json').read_text())['files']
        for row in sources['images']:
            self.assertRegex(row['sha256'], r'^[0-9a-f]{64}$')
            self.assertGreater(row['size'], 0)
        source = next(row for row in sources['images'] if row['name'] == 'dtbo.img')
        target = next(row for row in rows if row['path'] == 'dtbo.img')
        self.assertIn(source['sha256'], [target['sha256'], *target.get('accepted_alternate_sha256', [])])

    def test_extracts_only_required_regular_modules(self):
        data = entry('unused', b'skip') + entry('lib/modules/test.ko', b'payload') + entry('TRAILER!!!')
        self.assertEqual(extract.module_payloads(data, {'lib/modules/test.ko'}),
                         {'lib/modules/test.ko': b'payload'})

    def test_rejects_path_traversal(self):
        for path in ('../escape', '/absolute', 'lib/../../escape', 'C:\\escape'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                extract.module_payloads(entry(path) + entry('TRAILER!!!'), set())

    def test_rejects_symlink_instead_of_module(self):
        data = entry('lib/modules/test.ko', b'../../outside', stat.S_IFLNK | 0o777) + entry('TRAILER!!!')
        with self.assertRaises(ValueError):
            extract.module_payloads(data, {'lib/modules/test.ko'})

    def test_rejects_duplicate_module(self):
        data = entry('lib/modules/test.ko', b'a') * 2 + entry('TRAILER!!!')
        with self.assertRaises(ValueError):
            extract.module_payloads(data, {'lib/modules/test.ko'})

    def test_requires_all_requested_modules(self):
        with self.assertRaises(ValueError):
            extract.module_payloads(entry('TRAILER!!!'), {'lib/modules/missing.ko'})

    def test_rejects_truncated_cpio(self):
        with self.assertRaises(ValueError):
            extract.module_payloads(entry('lib/modules/test.ko', b'payload')[:-5], {'lib/modules/test.ko'})

    def test_accepts_only_explicitly_pinned_alternates(self):
        row = {'size': 3, 'sha256': hashlib.sha256(b'old').hexdigest(),
               'accepted_alternate_sha256': [hashlib.sha256(b'new').hexdigest()]}
        self.assertTrue(stage.matching(MemoryFile(b'old'), row))
        self.assertTrue(stage.matching(MemoryFile(b'new'), row))
        self.assertFalse(stage.matching(MemoryFile(b'bad'), row))
        self.assertFalse(stage.matching(MemoryFile(b'new!'), row))

    def test_legacy_single_hash_stays_strict(self):
        row = {'size': 3, 'sha256': hashlib.sha256(b'old').hexdigest()}
        self.assertTrue(stage.matching(MemoryFile(b'old'), row))
        self.assertFalse(stage.matching(MemoryFile(b'new'), row))


if __name__ == '__main__':
    unittest.main()
