#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
# SPDX-License-Identifier: Apache-2.0
"""Entry point for a reviewed per-file blob list once vendor audit is complete."""
from pathlib import Path

if __name__ == '__main__':
    entries = (Path(__file__).parent / 'proprietary-files.txt').read_text().splitlines()
    if not any(line.strip() and not line.lstrip().startswith('#') for line in entries):
        raise SystemExit('Per-file vendor extraction is not enabled yet. Use '
                         'scripts/extract-hardware-inputs.py for the verified image-based baseline; '
                         'see docs/VENDOR_PLAN.md. No vendor directory was modified.')
    from extract_utils.main import ExtractUtils, ExtractUtilsModule

    module = ExtractUtilsModule('RE5465', 'realme', namespace_imports=['device/realme/RE5465'])
    ExtractUtils.device(module).run()
