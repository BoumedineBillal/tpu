/*
 * systolic_array.v
 *
 * 2x2 Array of Processing Elements.
 *
 * Arrangement:
 *      | B0 | B1 |
 *      v    v
 * -- A0 -> [0,0] -> [0,1]
 *          |      |
 * -- A1 -> [1,0] -> [1,1]
 *          |      |
 */

`default_nettype none

module systolic_array (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] in_a0, // Row 0 input
    input  wire [7:0] in_a1, // Row 1 input
    input  wire [7:0] in_b0, // Col 0 input
    input  wire [7:0] in_b1, // Col 1 input
    
    input wire chain_en,
    output wire [7:0] chain_out
);

    // Wires for internal connections
    wire [7:0] a00_to_01, a10_to_11;
    wire [7:0] b00_to_10, b01_to_11;
    wire [7:0] a_dummy_01, a_dummy_11; 
    wire [7:0] b_dummy_10, b_dummy_11; 

    // Internal wires for the Accumulator Chain
    // 00 -> 01 -> 10 -> 11
    
    // PE 0,0
    wire [7:0] c00_val;
    pe pe00 (
        .clk(clk), .rst_n(rst_n),
        .in_a(in_a0), .in_b(in_b0),
        .chain_in_en(chain_en), .chain_in(8'd0), 
        .out_a(a00_to_01), .out_b(b00_to_10), .out_c(c00_val)
    );

    // PE 0,1
    wire [7:0] c01_val;
    pe pe01 (
        .clk(clk), .rst_n(rst_n),
        .in_a(a00_to_01), .in_b(in_b1),
        .chain_in_en(chain_en), .chain_in(c00_val),
        .out_a(a_dummy_01), .out_b(b01_to_11), .out_c(c01_val)
    );

    // PE 1,0
    wire [7:0] c10_val;
    pe pe10 (
        .clk(clk), .rst_n(rst_n),
        .in_a(in_a1), .in_b(b00_to_10),
        .chain_in_en(chain_en), .chain_in(c10_val),
        .out_a(a10_to_11), .out_b(b_dummy_10), .out_c(c10_val)
    );

    // PE 1,1
    wire [7:0] c11_val;
    pe pe11 (
        .clk(clk), .rst_n(rst_n),
        .in_a(a10_to_11), .in_b(b01_to_11),
        .chain_in_en(chain_en), .chain_in(c10_val),
        .out_a(a_dummy_11), .out_b(b_dummy_11), .out_c(c11_val)
    );

    assign chain_out = c11_val;

endmodule
