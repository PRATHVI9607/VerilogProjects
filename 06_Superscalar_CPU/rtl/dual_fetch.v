`timescale 1ns/1ps

// Superscalar Dual-Issue CPU - Dual Fetch Unit
// Fetches two instructions per cycle

module dual_fetch (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        flush,
    input  wire [31:0] branch_target,
    input  wire        branch_taken,
    
    output reg  [31:0] pc_0,
    output reg  [31:0] pc_1,
    output reg  [31:0] inst_0,
    output reg  [31:0] inst_1,
    output reg         valid_0,
    output reg         valid_1
);

    reg [31:0] pc;
    
    // Instruction memory (simplified)
    reg [31:0] imem [0:255];
    
    initial begin
        // Test program with independent and dependent instructions
        integer i;
        imem[0]  = 32'h00500093;  // addi x1, x0, 5
        imem[1]  = 32'h00A00113;  // addi x2, x0, 10
        imem[2]  = 32'h00F00193;  // addi x3, x0, 15
        imem[3]  = 32'h01400213;  // addi x4, x0, 20
        imem[4]  = 32'h002081B3;  // add x3, x1, x2  (can dual issue with next)
        imem[5]  = 32'h004202B3;  // add x5, x4, x4  (independent)
        imem[6]  = 32'h00308333;  // add x6, x1, x3  (RAW on x3)
        imem[7]  = 32'h005303B3;  // add x7, x6, x5  (RAW on x6)
        imem[8]  = 32'h00000013;  // nop
        imem[9]  = 32'h00000013;  // nop
        // Fill rest with NOPs
        for (i = 10; i < 256; i = i + 1) imem[i] = 32'h00000013;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0;
            pc_0 <= 32'h0;
            pc_1 <= 32'h4;
            inst_0 <= 32'h00000013;
            inst_1 <= 32'h00000013;
            valid_0 <= 1'b0;
            valid_1 <= 1'b0;
        end else if (flush) begin
            pc <= branch_target;
            valid_0 <= 1'b0;
            valid_1 <= 1'b0;
        end else if (!stall) begin
            pc <= branch_taken ? branch_target : pc + 8;
            pc_0 <= pc;
            pc_1 <= pc + 4;
            inst_0 <= imem[pc[9:2]];
            inst_1 <= imem[(pc[9:2]) + 1];
            valid_0 <= 1'b1;
            valid_1 <= 1'b1;
        end
    end

endmodule
