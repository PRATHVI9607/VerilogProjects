`timescale 1ns/1ps

// LFSR Pattern Generator for Memory BIST
// Generates pseudo-random test patterns

module lfsr_generator #(
    parameter WIDTH = 32,
    parameter SEED = 32'hACE1_CAFE
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        load_seed,
    input  wire [WIDTH-1:0] seed_value,
    output wire [WIDTH-1:0] pattern,
    output wire [WIDTH-1:0] inv_pattern
);

    // LFSR register
    reg [WIDTH-1:0] lfsr_reg;
    
    // Feedback taps for 32-bit LFSR (maximal length: x^32 + x^22 + x^2 + x + 1)
    wire feedback = lfsr_reg[31] ^ lfsr_reg[21] ^ lfsr_reg[1] ^ lfsr_reg[0];
    
    // Pattern outputs
    assign pattern = lfsr_reg;
    assign inv_pattern = ~lfsr_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg <= SEED;
        end else if (load_seed) begin
            lfsr_reg <= seed_value;
        end else if (enable) begin
            lfsr_reg <= {lfsr_reg[WIDTH-2:0], feedback};
        end
    end

endmodule
