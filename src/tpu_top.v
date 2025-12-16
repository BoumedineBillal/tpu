/*
 * tpu_top.v
 *
 * Top-level control logic for the Tiny Tapeout TPU.
 * Handles I/O serialization, buffering, and state machine control.
 */

`default_nettype none

module tpu_top (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] ui_in,    // Data Input
    output wire [7:0] uo_out,   // Data Output
    input  wire [7:0] uio_in,   // Control Input
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe
);

    // Control Signals
    // uio_in[1:0] defines the operation mode:
    // 00: LOAD A (sequentially load 4 bytes)
    // 01: LOAD B (sequentially load 4 bytes)
    // 10: COMPUTE (run systolic array)
    // 11: READ OUTPUT (sequentially read 4 bytes)
    wire [1:0] mode = uio_in[1:0];

    // Internal Registers for Matrix A and B (Shift Chains)
    reg [7:0] A [0:3];
    reg [7:0] B [0:3];
    reg [2:0] counter;
    reg [1:0] last_mode;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            last_mode <= 0;
            A[0]<=0; A[1]<=0; A[2]<=0; A[3]<=0;
            B[0]<=0; B[1]<=0; B[2]<=0; B[3]<=0;
        end else begin
            if (mode != last_mode) counter <= 0;
            else if (mode != 2'b10 && counter < 4) counter <= counter + 1; // Load/Read count
            else if (mode == 2'b10 && counter < 7) counter <= counter + 1; // Compute count
            last_mode <= mode;

            // LOAD A - Shift Register
            if (mode == 2'b00) begin
                A[3] <= A[2]; A[2] <= A[1]; A[1] <= A[0]; A[0] <= ui_in;
            end
            
            // LOAD B - Shift Register
            if (mode == 2'b01) begin
                B[3] <= B[2]; B[2] <= B[1]; B[1] <= B[0]; B[0] <= ui_in;
            end
        end
    end
    
    // Compute Schedule (Systolic Feed)
    reg [7:0] sys_in_a0, sys_in_a1;
    reg [7:0] sys_in_b0, sys_in_b1;
    always @(*) begin
        sys_in_a0 = 0; sys_in_a1 = 0;
        sys_in_b0 = 0; sys_in_b1 = 0;
        
        if (mode == 2'b10) begin
            case (counter)
                3'd0: begin
                    sys_in_a0 = A[3]; // A00 (First loaded)
                    sys_in_b0 = B[3]; // B00 (First loaded)
                end
                3'd1: begin
                    sys_in_a0 = A[2]; // A01
                    sys_in_a1 = A[1]; // A10
                    sys_in_b0 = B[1]; // B10 
                    sys_in_b1 = B[2]; // B01
                end
                3'd2: begin
                    sys_in_a1 = A[0]; // A11 (Last loaded)
                    sys_in_b1 = B[0]; // B11 (Last loaded)
                end
            endcase
        end
    end

    // Instantiate Output
    wire [7:0] chain_out;
    systolic_array array (
        .clk(clk),
        .rst_n(rst_n && (mode != 2'b00)), 
        
        .in_a0(sys_in_a0), .in_a1(sys_in_a1),
        .in_b0(sys_in_b0), .in_b1(sys_in_b1),
        
        .chain_en(mode == 2'b11), 
        .chain_out(chain_out)
    );

    assign uo_out = chain_out;
    assign uio_out = 0;
    assign uio_oe = 0;

endmodule
