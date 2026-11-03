#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo 'Install Icarus Verilog (iverilog/vvp) first.' >&2; exit 1; }
for name in hex predictor fc convolution; do
  iverilog -g2012 -s "tb_${name}" -o "/tmp/tb_${name}.vvp" \
    "testbench/tb_${name}.v" \
    rtl/digit_to_hex0.v rtl/cnn_predictor.v rtl/cnn_fc_classifier.v \
    rtl/cnn_conv_5x5_core.v
  vvp "/tmp/tb_${name}.vvp"
done
