#!/usr/bin/env python3
"""Basic snapshot integrity checks (NOT HDL compilation or simulation)."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    'rtl/top_cnn2.v', 'rtl/arduino_mnist_capture.v', 'rtl/act_buf_ram.v',
    'rtl/cnn_conv_5x5_core.v', 'rtl/cnn_predictor.v',
    'rtl/cnn_fc_classifier.v', 'rtl/digit_to_hex0.v',
    'ip/rom_byte.v', 'ip/rom_byte.qip', 'ip/out_buf.v', 'ip/out_buf.qip',
    'ip/fc_rom.v', 'ip/fc_rom.qip', 'conv_weights.mif',
    'fc_weights.mif', 'host/draw_and_send.py'
]


def check_mif(name, depth, width):
    text = (ROOT / name).read_text()
    d = re.search(r'\bDEPTH\s*=\s*(\d+)\s*;', text, re.I)
    w = re.search(r'\bWIDTH\s*=\s*(\d+)\s*;', text, re.I)
    if not d or not w or (int(d[1]), int(w[1])) != (depth, width):
        raise ValueError(f'{name}: expected DEPTH={depth}, WIDTH={width}')
    entries = {}
    for addr, val in re.findall(r'^\s*(\d+)\s*:\s*([0-9A-Fa-f]+)\s*;', text, re.M):
        a, v = int(addr), int(val, 16)
        if a in entries or a >= depth or v >= 2 ** width:
            raise ValueError(f'{name}: invalid or duplicate address {a}')
        entries[a] = v
    for lo, hi, val in re.findall(r'\[(\d+)\s*\.\.\s*(\d+)\]\s*:\s*([0-9A-Fa-f]+)\s*;', text):
        value = int(val, 16)
        for a in range(int(lo), int(hi) + 1):
            if a in entries or a >= depth or value >= 2 ** width:
                raise ValueError(f'{name}: invalid or duplicate range address {a}')
            entries[a] = value
    if len(entries) != depth:
        raise ValueError(f'{name}: {len(entries)} populated addresses, expected {depth}')
    print(f'PASS: {name}: {depth} addresses, {width}-bit data')


def main():
    missing = [p for p in REQUIRED if not (ROOT / p).is_file()]
    if missing:
        raise SystemExit(f'Missing files: {missing}')
    print(f'PASS: all {len(REQUIRED)} required files present')
    src = '\n'.join((ROOT / p).read_text() for p in REQUIRED if p.endswith('.v'))
    top = (ROOT / 'rtl/top_cnn2.v').read_text()
    defined = set(re.findall(r'\bmodule\s+(\w+)', src))
    for m in ['m2', 'arduino_mnist_capture', 'act_buf_ram', 'cnn_conv5x5_core',
              'rom_byte', 'out_buf', 'cnn_predictor', 'fc_rom',
              'cnn_fc_classifier', 'digit_to_hex0']:
        if m not in defined:
            raise SystemExit(f'Missing module declaration: {m}')
        if m != 'm2' and not re.search(r'\b' + m + r'\s+\w+\s*\(', top):
            raise SystemExit(f'Missing top-level instance: {m}')
    print('PASS: top-level module declarations/instantiations are present')
    check_mif('conv_weights.mif', 512, 8)
    check_mif('fc_weights.mif', 128, 8)
    compile((ROOT / 'host/draw_and_send.py').read_text(), 'draw_and_send.py', 'exec')
    print('PASS: host Python source parses')
    print('NOTE: this does not validate RTL syntax, timing, classification, or hardware')


if __name__ == '__main__':
    main()
