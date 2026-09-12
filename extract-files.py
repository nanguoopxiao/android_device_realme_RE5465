#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
# SPDX-License-Identifier: Apache-2.0
"""Entry point for a reviewed per-file blob list once vendor audit is complete."""
from extract_utils.main import ExtractUtils, ExtractUtilsModule

module = ExtractUtilsModule('RE5465', 'realme', namespace_imports=['device/realme/RE5465'])

if __name__ == '__main__':
    ExtractUtils.device(module).run()
