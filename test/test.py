# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

# Helper to print matrices
def print_matrix(name, data):
    print(f"{name}:")
    print(f"[{data[0]}, {data[1]}]")
    print(f"[{data[2]}, {data[3]}]")

@cocotb.test()
async def test_tpu_matmul(dut):
    dut._log.info("Start TPU Test")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Test Vectors
    # Matrix A: [[1, 2], [3, 4]] -> [1, 2, 3, 4]
    # Matrix B: [[5, 6], [7, 8]] -> [5, 6, 7, 8]
    # Expected C = A @ B
    # C00 = 1*5 + 2*7 = 5 + 14 = 19
    # C01 = 1*6 + 2*8 = 6 + 16 = 22
    # C10 = 3*5 + 4*7 = 15 + 28 = 43
    # C11 = 3*6 + 4*8 = 18 + 32 = 50
    # Flattened C: [19, 22, 43, 50]
    
    A = [1, 2, 3, 4]
    B = [5, 6, 7, 8]
    # Expected C = A @ B
    # C00 = 19, C01 = 22, C10 = 43, C11 = 50
    # WITH CHAINING optimization (00->01->10->11->OUT):
    # Shift 1: Out=11 (50)
    # Shift 2: Out=10 (43)
    # Shift 3: Out=01 (22)
    # Shift 4: Out=00 (19)
    Expected = [50, 43, 22, 19]

    dut._log.info(f"Test A: {A}")
    dut._log.info(f"Test B: {B}")

    # --- Phase 1: Load A ---
    dut._log.info("Loading Matrix A...")
    dut.uio_in.value = 0b00 # Mode 00: Load A
    
    # We need to clock in 4 values.
    # The counter increments on every clock in this mode.
    # Note: Logic updates register on posedge.
    # Sequence:
    # 1. Apply A[0], Wait Clock (Counter 0 -> A[0] latched, Counter becomes 1)
    # 2. Apply A[1], Wait Clock (Counter 1 -> A[1] latched, Counter becomes 2)
    # ...
    
    for val in A:
        dut.ui_in.value = val
        await ClockCycles(dut.clk, 1) # Wait for edge to latch
        
    # --- Phase 2: Load B ---
    dut._log.info("Loading Matrix B...")
    dut.uio_in.value = 0b01 # Mode 01: Load B
    # Wait 1 cycle for mode change to reset counter?
    # Our RTL says "if (mode != last_mode) counter <= 0".
    # So the first clock edge after mode change will reset counter to 0.
    # It will NOT latch data on that same edge (or maybe it will if we are careful).
    # RTL:
    # if (mode != last_mode) counter <= 0;
    # else ... if (mode == LOAD_B) B[counter] <= ui_in;
    #
    # So on the edge where we detect mode change, we only reset counter. we do NOT write B[0].
    # We need to wait 1 cycle after applying mode change before sending data?
    # Let's see:
    # Edge 1: uio_in changed setup time before. RTL sees new mode != old mode. Resets counter. old mode updated.
    # Edge 2: mode == last_mode. Counter is 0. Writes B[0]. Counter increments.
    #
    # So yes, we need 1 "setup" cycle when switching modes.
    
    await ClockCycles(dut.clk, 1) # Cycle to reset counter
    
    for val in B:
        dut.ui_in.value = val
        await ClockCycles(dut.clk, 1)

    # --- Phase 3: Compute ---
    dut._log.info("Computing...")
    dut.uio_in.value = 0b10 # Mode 10: Compute
    await ClockCycles(dut.clk, 1) # Reset counter
    
    # Run for enough cycles for systolic wave to complete.
    # 2x2 array needs about 4-5 cycles active feeding + latency.
    # Let's give it 10 cycles.
    await ClockCycles(dut.clk, 10)

    # --- Phase 4: Read Output ---
    dut._log.info("Reading Result...")
    dut.uio_in.value = 0b11 # Mode 11: Read
    await ClockCycles(dut.clk, 1) # Reset counter
    
    # Now read 4 values.
    # Cycle 0: counter=0. Output should be C00.
    # Cycle 1: counter=1. Output should be C01.
    # and so on.
    
    received_data = []
    for i in range(4):
        # Data is valid AFTER the edge?
        # "assign uo_out = data_out;" where data_out depends on counter.
        # Counter updates on posedge.
        # So stable data for counter=0 is available AFTER the reset cycle?
        # Wait, inside RTL:
        # always @(posedge clk) ... if (mode!=last) counter<=0
        # always @(*) case(counter) ...
        #
        # So after the "Reset counter" cycle above, counter is 0.
        # Combinational logic `data_out` should immediately reflect C00.
        # So we can read immediately?
        # Cocotb `dut.uo_out.value` samples instantaneously (or at end of delta).
        
        # Let's wait a small delay to ensure combinational propagation?
        # Or just read before next clock edge.
        # We are currently right after a clock edge (await ClockCycles).
        
        # NOTE: In simulation, values update at edge.
        # So right now, counter is 0. uo_out should be C00.
        
        val = int(dut.uo_out.value)
        received_data.append(val)
        dut._log.info(f"Read index {i}: {val}")
        
        await ClockCycles(dut.clk, 1) # Increment counter to next
        
    dut._log.info(f"Received: {received_data}")
    dut._log.info(f"Expected: {Expected}")
    
    assert received_data == Expected, f"Mismatch! Got {received_data}, expected {Expected}"
    dut._log.info("Test Passed!")
