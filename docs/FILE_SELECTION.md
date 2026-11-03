# Uploaded file selection

This package contains the uploaded files needed to represent the **currently connected `m2` top-level design**, not every file from the development directory. Every selected `.v`, `.qip`, `.mif` and `.py` file has been copied **unchanged**.

## Included — design RTL (7)

| Source | Reason |
| --- | --- |
| `top_cnn2.v` | Instantiates all primary blocks; top-level module is `m2` |
| `arduino_mnist_capture.v` | Bit-serial pixel/frame capture |
| `act_buf_ram.v` | 784-byte activation RAM |
| `cnn_conv_5x5_core.v` | Sequential signed convolution MAC datapath |
| `cnn_predictor.v` | Accumulates 8 feature-map sums; also produces an unused 0–7 argmax |
| `cnn_fc_classifier.v` | 10-class FC classifier |
| `digit_to_hex0.v` | HEX0 output decoder (currently only 0–7) |

## Included — generated Quartus IP (6)

`rom_byte.v/.qip` (convolution weight ROM), `out_buf.v/.qip` (feature-map RAM), `fc_rom.v/.qip` (FC weight ROM). These are vendor-generated **source/configuration files**, not temporary build outputs; the active top-level references their modules. They depend on Intel `altsyncram` libraries.

## Included — memory images (2)

- `conv_weights.mif`: the **actual** initialization file named in `rom_byte.v` (`DEPTH=512`, `WIDTH=8`).
- `fc_weights.mif`: the **actual** initialization file named in `fc_rom.v` (`DEPTH=128`, `WIDTH=8`).

These files are part of the model representation in this snapshot; weights should be reviewed against any final trained/exported model.

## Included — PC interface (1)

`draw_and_send.py`: Tkinter image-drawing UI. It transmits a `0xAA` framing byte plus 784 pixels; the required Arduino bridge firmware was not supplied.

## Excluded — currently unused or ambiguous (3)

| Uploaded source | Reason to exclude from the main build |
| --- | --- |
| `kernel_offset5x5.v` | A 5×5 address helper, but not instantiated by the supplied convolution core or top-level |
| `ram196x32.v` | An Intel-generated RAM wrapper not instantiated by the current top-level; refers to `image.mif`, which was not supplied |
| `weights.mif` | A *different* convolution-weight snapshot than `conv_weights.mif`; `rom_byte.v` explicitly loads `conv_weights.mif`, so including both would be confusing without an explanation of their provenance |

The excluded files were not deleted or rewritten in the user's originals; they are simply omitted from the curated ZIP. If you later find that the final Quartus project uses them, add them back with the correct configuration and documentation.

## Not provided

A `.qpf/.qsf` project, timing constraints (`.sdc`), Arduino `.ino` bridge, testbenches, ModelSim simulation scripts, waveforms, Quartus timing/resource reports, and any final demo photos or recordings. None has been fabricated for this repository.
