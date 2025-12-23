`timescale 1ns/1ps

// Superscalar Dual-Issue CPU - Dual ALU Execute Unit

module dual_alu (
    input  wire        clk,
    input  wire        rst_n,
    
    // ALU 0 inputs
    input  wire        valid_0,
    input  wire [3:0]  alu_op_0,
    input  wire [31:0] operand_a_0,
    input  wire [31:0] operand_b_0,
    input  wire [4:0]  rd_0,
    
    // ALU 1 inputs
    input  wire        valid_1,
    input  wire [3:0]  alu_op_1,
    input  wire [31:0] operand_a_1,
    input  wire [31:0] operand_b_1,
    input  wire [4:0]  rd_1,
    
    // Outputs
    output reg  [31:0] result_0,
    output reg  [4:0]  result_rd_0,
    output reg         result_valid_0,
    
    output reg  [31:0] result_1,
    output reg  [4:0]  result_rd_1,
    output reg         result_valid_1
);

    // ALU function
    function [31:0] alu_compute;
        input [3:0]  op;
        input [31:0] a;
        input [31:0] b;
        begin
            case (op)
                4'b0000: alu_compute = a + b;                    // ADD
                4'b1000: alu_compute = a - b;                    // SUB
                4'b0001: alu_compute = a << b[4:0];              // SLL
                4'b0010: alu_compute = ($signed(a) < $signed(b)) ? 1 : 0; // SLT
                4'b0011: alu_compute = (a < b) ? 1 : 0;          // SLTU
                4'b0100: alu_compute = a ^ b;                    // XOR
                4'b0101: alu_compute = a >> b[4:0];              // SRL
                4'b1101: alu_compute = $signed(a) >>> b[4:0];    // SRA
                4'b0110: alu_compute = a | b;                    // OR
                4'b0111: alu_compute = a & b;                    // AND
                default: alu_compute = 32'b0;
            endcase
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_0 <= 32'b0;
            result_rd_0 <= 5'b0;
            result_valid_0 <= 1'b0;
            result_1 <= 32'b0;
            result_rd_1 <= 5'b0;
            result_valid_1 <= 1'b0;
        end else begin
            // ALU 0
            result_valid_0 <= valid_0;
            result_rd_0 <= rd_0;
            result_0 <= alu_compute(alu_op_0, operand_a_0, operand_b_0);
            
            // ALU 1
            result_valid_1 <= valid_1;
            result_rd_1 <= rd_1;
            result_1 <= alu_compute(alu_op_1, operand_a_1, operand_b_1);
        end
    end

endmodule
