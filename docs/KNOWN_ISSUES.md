# Remaining limitations (after source-level fixes)

The corrected source edits are described in [FIXES_APPLIED.md](FIXES_APPLIED.md).

- **Not hardware-verified:** No board test, Intel-IP ModelSim simulation, Quartus synthesis or timing analysis was performed.
- **Board project files missing:** The original `.qpf`, `.qsf`, `.sdc`, pin assignments and build configuration were not supplied.
- **Arduino bridge reconstructed:** The `arduino/arduino_mnist_bridge.ino` file is example firmware added for this package, not the original sketch or a tested replacement. It assumes an Arduino with pins D2/D3/D4, USB serial at 115200, and suitable voltage levels (level shifting is required for 5 V Arduino output driving 3.3 V FPGA inputs).
- **Unknown final weights:** The provided `conv_weights.mif` and `fc_weights.mif` are preserved as supplied, but classifier accuracy and model-export provenance are unknown.
- **No concurrent capture/compute protection:** Input RAM is not double-buffered; sending another frame during convolution can overwrite an image still being read.
- **Latency needs vendor simulation:** Wait states were added to accommodate clocked Intel memory interfaces; confirm them under the actual IP simulation library and hardware configuration.
- **Testbenches unexecuted here:** Targeted Icarus Verilog tests were authored, but the HDL simulator was unavailable in the preparation environment. They should be executed locally before using this as a verified demonstration.

Recommended steps: run provided testbenches, restore your final Quartus pin/project files, simulate with the Intel libraries, run a known digit input end-to-end, and capture a real board demonstration.
