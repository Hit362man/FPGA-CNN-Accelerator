# RTL changes in this reconstructed snapshot

This package was edited from the supplied development snapshot, **not** recovered from a known-good final build. The fixes are reasoned source-level corrections. Vendor-IP ModelSim simulation, Quartus synthesis and board tests have **not** been run.

## Source-level fixes

1. `rtl/top_cnn2.v`: Removed the `remote_digit` latch (the first pixel is *not* the classifier output); drove HEX0 with `fc_digit` from the FPGA classifier.
2. `rtl/digit_to_hex0.v`: Expanded the decoder port from 3 to 4 bits and added 8 and 9 patterns.
3. `rtl/cnn_predictor.v`: Fixed the dropped final sample in each filter sum (`current_sum + q`). Added wait states for the registered address **and** registered data output in `out_buf`.
4. `rtl/cnn_fc_classifier.v`: Used the current final class's score when selecting the result, so class 9 can win. Reworked ROM request/consume timing and zero-extended nonnegative feature sums.
5. `rtl/cnn_conv_5x5_core.v`: Inserted a wait clock between issuing the synchronous input RAM/weight-ROM address and consuming their outputs.
6. `rtl/cnn_conv_5x5_core.v`, `rtl/cnn_predictor.v`, `rtl/cnn_fc_classifier.v`: Allow `S_DONE` to return to idle after pulsing `done`, so the engines can accept subsequent starts.
7. `rtl/top_cnn2.v`: Added `frame_pending` to avoid retriggering an already processed frame when `frame_ready` stays high.
8. `arduino/arduino_mnist_bridge.ino`: Added **new example firmware**, not supplied by the user, to bridge USB serial (`0xAA` + 784 bytes) to the expected 3-wire GPIO protocol.

## Verification included

`testbench/` contains self-checking Verilog testbenches for the seven-segment decoder, feature summation/argmax and repeated runs, FC classification with class 9 as the winner and repeated runs, and convolution datapath including registered memory-read behavior, ReLU/clamp, address sequencing and repeated runs. Run them with Icarus Verilog on your own machine:

```bash
bash testbench/run_iverilog.sh
```

These testbenches use **behavioral memory models**, not the actual Quartus-generated `altsyncram`. They check targeted logic, not the end-to-end image classification system. In the environment used to prepare this ZIP, Icarus Verilog and ModelSim were unavailable, so these simulations **have not been executed**. The `tools/check_files.py` static integrity test *was* run.

## Remaining gaps

- No final `.qpf` / `.qsf` / `.sdc` FPGA project or pin assignments; choose the actual device and resolve external port mappings. Arduino and FPGA must share ground and use compatible signal levels: a 5 V Arduino Uno output needs level shifting before connection to 3.3 V FPGA pins.
- No original Arduino sketch or hardware-proven timing for the replacement example sketch.
- No vendor-IP simulation of `out_buf` / `rom_byte` / `fc_rom`; verify registered read latency with ModelSim Intel libraries. The inserted waits are conservative but not hardware-proven.
- No end-to-end hardware digit classification result, test images with expected digits, final model-training pipeline, model accuracy, timing closure, power or resource measurements.
- Input RAM has one bank: transmitting a new image while convolution is reading the previous image can corrupt processing. Send frames sequentially; add a busy/ack protocol or ping-pong RAM for true streaming operation.
- Python GUI creates `digit_image.png` and opens an image preview when sending. It is an output artifact and is ignored by Git.
- The memory initialization files were preserved as provided; their origin and their relation to a correctly trained 10-class model are not verified.

Do not label this snapshot a fully validated accelerator or report measured throughput or classification accuracy without further tests.

## Follow-up parser fix

Restored missing `//` on the separator comment before `S_WAIT_TAP` in `rtl/cnn_conv_5x5_core.v`. This resolves the syntax error introduced during the earlier source patch. Simulation still needs to be run locally.
