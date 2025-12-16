<!---
This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements an optimized **8-bit 2x2 Systolic Array TPU** for matrix multiplication (2x2 Matrix A * 2x2 Matrix B).

### Architecture
*   **Controller (`tpu_top.v`)**: Handles I/O serialization using compact shift registers instead of MUX-based buffers to check area.
*   **Processing Element (`pe.v`)**: Performs 8-bit Multiply-Accumulate (MAC) operations. It uses an **Output Stationary** architecture where results accumulate in relevant registers.
*   **Systolic Array (`systolic_array.v`)**: A 2x2 grid of PEs.

### Optimizations
1.  **Shift-Register Loading**: Data is loaded serially into shift registers, saving significant gate count compared to addressable buffers.
2.  **Daisy-Chained Readout**: Results are read out by shifting the accumulators of the PEs in a chain (`00 -> 01 -> 10 -> 11 -> OUT`), eliminating the need for a large output multiplexer.
3.  **Reset Pruning**: Data path resets reduced to minimize routing congestion.

## How to test

The TPU is controlled via the Bidirectional I/O pins (`uio`) which set the operation mode.

### Pinout
*   `ui[7:0]`: Data Input (for Matrix A and B).
*   `uo[7:0]`: Data Output (Result Chain).
*   `uio[1:0]`: Mode Select.
    *   `00`: **Load Weight (Matrix A)**.
    *   `01`: **Load Matrix B**.
    *   `10`: **Compute**.
    *   `11`: **Read Output**.

### Protocol
1.  **Reset**: Pulse `rst_n` low.
2.  **Load Matrix A** (`uio=00`):
    *   Clock in 4 bytes of A sequentially. Order: `A00` -> `A01` -> `A10` -> `A11`.
3.  **Load Matrix B** (`uio=01`):
    *   Clock in 4 bytes of B sequentially. Order: `B00` -> `B01` -> `B10` -> `B11`.
4.  **Compute** (`uio=10`):
    *   Clock for ~10 cycles. The controller automatically feeds the data into the systolic array.
5.  **Read Result** (`uio=11`):
    *   Clock 4 times to read `uo_out`.
    *   The results appear in reverse chain order: `C11`, `C10`, `C01`, `C00`.

## External hardware

None required. The design can be verified using the standard Tiny Tapeout testbench or by driving the pins with a microcontroller/FPGA.
