# FPGA CNN Accelerator for Handwritten Digit Recognition

A 5×5 convolution datapath written in **Verilog** for the **DE1-SoC / Intel Cyclone V FPGA**. It accepts a 28×28 grayscale input via a serial capture module, processes it through eight convolution filters and a 10-class fully connected stage, then drives a seven-segment display with the classifier result.


## Architecture

```text
PC: draw_and_send.py   (28 x 28 GUI, 784 pixel bytes)
           |
           | USB serial 115200: 0xAA + 784 bytes
           v
Arduino bridge sketch (new example; not hardware-verified)
           |
           | frame_start / serial_data / bit_clk (LSB-first)
           v
arduino_mnist_capture --> act_buf_ram (784 x 8)
                                  |
conv_weights.mif --> rom_byte --> cnn_conv5x5_core
                                  |
                             out_buf (8 x 24 x 24)
                                  |
                             cnn_predictor
                             (8 filter sums)
                                  |
fc_weights.mif --> fc_rom --> cnn_fc_classifier (10 classes)
                                  |
                               fc_digit --> digit_to_hex0 --> HEX0
```

### Design summary

| Component | Implementation |
| --- | --- |
| Input | 28 × 28 grayscale (784 pixels, 8 bits each) |
| Convolution | Eight 5 × 5 filters with 200 total kernel-weight positions |
| Convolution outputs | Eight 24 × 24 maps (4,608 positions) |
| Nominal work | 115,200 MAC steps/image (8 × 24 × 24 × 25), **not measured performance** |
| Arithmetic | Signed 8-bit kernel weights, 24-bit accumulator; ReLU and saturating to 8-bit output |
| Storage | Input RAM, Intel ROM wrappers, output RAM, FC weight/bias ROM |
| Classifier | Per-filter activation sums followed by a 10-class weighted-sum argmax |
| Control | FSM sequencing, KEY[0] active-low reset, SW[0] start, CLOCK_50 |
| Display | Active-low seven-segment HEX0 decoder for digits 0–9 |

## Files

```text
FPGA-CNN-Accelerator/
├── rtl/            top, capture, convolution, predictor, FC, display RTL
├── ip/             Quartus-generated altsyncram .v/.qip wrappers
├── arduino/        newly written example USB-to-GPIO bridge (UNTESTED)
├── host/           Python Tkinter drawing and USB serial sender
├── testbench/      targeted self-checking behavioral simulations (UNRUN HERE)
├── conv_weights.mif
├── fc_weights.mif
├── tools/          snapshot integrity checker
├── docs/           audit, changes and remaining limitations
└── .gitignore
```

The `.mif` files are in the repository root to match the `init_file` paths inside the Quartus IP wrappers.

## Running the drawing application

On a computer with Python 3 and Tkinter:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r host/requirements.txt
python3 host/draw_and_send.py
```

The app sends `0xAA` and 784 pixels at 115200 baud. To try the Arduino bridge, upload `arduino/arduino_mnist_bridge.ino` to a suitable Arduino and wire **data D2**, **clock D3**, **frame D4**, and **common ground** to the FPGA inputs. **Important: many Arduino Uno boards drive 5 V logic, while DE1-SoC FPGA GPIO is typically 3.3 V; use a 3.3 V Arduino or an appropriate logic-level shifter, verify board specifications, and never connect 5 V GPIO directly to 3.3 V FPGA inputs.** Check board pin constraints before wiring. The bridge and physical connections remain unverified.

## Testing

Run static file/ROM-image presence checks:

```bash
python3 tools/check_files.py
```

Run the targeted RTL testbenches after installing Icarus Verilog (`iverilog` and `vvp`):

```bash
bash testbench/run_iverilog.sh
```

The tests use small behavioral memories matching the intended synchronous-read contract. They do not instantiate Quartus `altsyncram`. The original Quartus FPGA project (`.qpf`, `.qsf`, timing/pin constraints) and any original ModelSim testbenches were not supplied, so there is no reproducible board bitstream in this repository.

## Validation and project claims

This snapshot includes specific source-level fixes for the display path, 0–9 decoder, last-pixel accumulation, class-9 comparison, SRAM/ROM read scheduling and multi-frame rearming. However, final model accuracy, timing closure, device utilization, and end-to-end FPGA classification have **not** been verified from the available files.

For a completed portfolio demo: restore the original Quartus project and actual Arduino firmware if available, run vendor-memory simulations, validate known digit inputs against expected results, and add measured waveforms/hardware photos.

If any of these files came from course-provided material, verify redistribution permission before publishing them publicly; generated Intel IP wrappers may carry vendor notices.

## November 2026 syntax correction

The earlier corrected ZIP accidentally omitted the `//` prefix on a separator comment immediately before `S_WAIT_TAP:` in `rtl/cnn_conv_5x5_core.v`. This made the file invalid Verilog and caused Icarus Verilog syntax/case-expression errors. The missing comment prefix has been restored. **The `testbench/run_iverilog.sh` suite still needs to be run on a machine with Icarus Verilog installed; it was not executed in this environment.**
