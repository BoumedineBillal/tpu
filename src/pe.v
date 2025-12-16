/*
 * processing_element.v
 *
 * A simple Processing Element (PE) for a systolic array.
 * Performs a multiply-accumulate operation:
 *   out_c = in_c + (in_a * in_b)
 *
 * For a systolic flow:
 *   out_a = in_a (after register)
 *   out_b = in_b (after register)
 */

`default_nettype none

module pe (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] in_a,
    input  wire [7:0] in_b,
    input  wire       chain_in_en, // Enable chain shift (for Output Reading)
    input  wire [7:0] chain_in,    // Data from previous PE (for Output Reading)
    
    output reg  [7:0] out_a,       // A passes through
    output reg  [7:0] out_b,       // B passes through
    output reg  [7:0] out_c        // C accumulates
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_c <= 0;
            // distinct optimization: out_a and out_b do not need reset
        end else begin
            if (chain_in_en) begin
                // Chain Mode: Shift data from neighbor
                out_c <= chain_in;
            end 
            else begin
                // Compute Mode
                // Systolic flow: Pass inputs to neighbors
                out_a <= in_a;
                out_b <= in_b;

                // Compute: MAC (Output Stationary)
                out_c <= out_c + (in_a * in_b);
            end
        end
    end

endmodule
