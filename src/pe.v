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
    input  wire       chain_in_en, // Enable chain shift (for Output Reading)
    input  wire [7:0] chain_in,    // Data from previous PE (for Output Reading)
    
    input  wire       load_weight, // Enable weight loading
    input  wire [7:0] weight_in,   // Weight input (Vertical shift?) or reuse in_a?
                                   // Let's reuse in_a as the weight load port.
    
    output reg  [7:0] out_b,       // B passes through
    output reg  [7:0] out_c,       // C accumulates
    output wire [7:0] weight_out   // Pass weight to neighbor (for loading chain)
);

    reg [7:0] weight;
    assign weight_out = weight; // Combinational pass-through or reg? 
                                // Standard shift register: out = reg. 
                                // So PE(i) weight feeds PE(i+1).

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_c <= 0;
            // distinct optimization: weight and out_b do not need reset
        end else begin
            if (load_weight) begin
                // Weight Loading Mode: Shift Register
                weight <= weight_in;
            end 
            else if (chain_in_en) begin
                // Output Reading Mode
                out_c <= chain_in;
            end 
            else begin
                // Compute Mode
                // Systolic flow: Pass B to neighbor
                out_b <= in_b;

                // Compute: MAC with Stored Weight
                out_c <= out_c + (weight * in_b);
            end
        end
    end

endmodule
