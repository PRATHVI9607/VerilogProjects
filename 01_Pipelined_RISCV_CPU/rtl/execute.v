`timescale 1ns/1ps

// Execute Stage (EX)
// Performs ALU operations and branch resolution

`include "riscv_pkg.v"

module execute (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flush,
    
    // From ID stage
    input  wire [31:0] pc_in,
    input  wire [31:0] rs1_data_in,
    input  wire [31:0] rs2_data_in,
    input  wire [31:0] imm_in,
    input  wire [4:0]  rd_in,
    input  wire [4:0]  rs1_addr_in,
    input  wire [4:0]  rs2_addr_in,
    input  wire [3:0]  alu_op_in,
    input  wire        alu_src_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,
    input  wire        branch_in,
    input  wire        jump_in,
    input  wire [2:0]  funct3_in,
    input  wire        valid_in,
    
    // Forwarding inputs
    input  wire [1:0]  forward_a,
    input  wire [1:0]  forward_b,
    input  wire [31:0] ex_mem_result,
    input  wire [31:0] mem_wb_result,
    
    // Outputs to MEM stage
    output reg  [31:0] alu_result,
    output reg  [31:0] rs2_data_out,
    output reg  [4:0]  rd_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg  [2:0]  funct3_out,
    output reg         valid_out,
    
    // Branch control outputs
    output wire        branch_taken,
    output wire [31:0] branch_target,
    
    // Forwarding mux select outputs (for waveform visualization)
    output wire [1:0]  fwd_a_sel,
    output wire [1:0]  fwd_b_sel,
    
    // Flag register outputs
    output reg  [3:0]  flags_out,      // {V, C, N, Z}
    output reg         flags_valid     // Flag update valid signal
);

    // Forwarding mux outputs
    reg [31:0] alu_operand_a;
    reg [31:0] alu_operand_b;
    reg [31:0] rs2_forwarded;
    
    // ALU result wire
    reg [31:0] alu_out;
    
    // Extended ALU result for carry detection
    reg [32:0] alu_out_extended;
    
    // Flag computation wires
    wire flag_zero;
    wire flag_negative;
    wire flag_carry;
    wire flag_overflow;
    wire [3:0] flags_computed;
    
    // Branch comparison result
    reg branch_cmp;
    
    // Forward selection visibility
    assign fwd_a_sel = forward_a;
    assign fwd_b_sel = forward_b;
    
    // Forwarding MUX for operand A
    always @(*) begin
        case (forward_a)
            `FWD_NONE:   alu_operand_a = rs1_data_in;
            `FWD_EX_MEM: alu_operand_a = ex_mem_result;
            `FWD_MEM_WB: alu_operand_a = mem_wb_result;
            default:     alu_operand_a = rs1_data_in;
        endcase
    end
    
    // Forwarding MUX for operand B (pre-ALU src mux)
    always @(*) begin
        case (forward_b)
            `FWD_NONE:   rs2_forwarded = rs2_data_in;
            `FWD_EX_MEM: rs2_forwarded = ex_mem_result;
            `FWD_MEM_WB: rs2_forwarded = mem_wb_result;
            default:     rs2_forwarded = rs2_data_in;
        endcase
    end
    
    // ALU source mux (register or immediate)
    always @(*) begin
        alu_operand_b = alu_src_in ? imm_in : rs2_forwarded;
    end
    
    // ALU Operation
    always @(*) begin
        case (alu_op_in)
            `ALU_ADD: begin
                alu_out = alu_operand_a + alu_operand_b;
                alu_out_extended = {1'b0, alu_operand_a} + {1'b0, alu_operand_b};
            end
            `ALU_SUB: begin
                alu_out = alu_operand_a - alu_operand_b;
                alu_out_extended = {1'b0, alu_operand_a} - {1'b0, alu_operand_b};
            end
            `ALU_SLL: begin
                alu_out = alu_operand_a << alu_operand_b[4:0];
                alu_out_extended = {1'b0, alu_out};
            end
            `ALU_SLT: begin
                alu_out = ($signed(alu_operand_a) < $signed(alu_operand_b)) ? 32'd1 : 32'd0;
                alu_out_extended = {1'b0, alu_out};
            end
            `ALU_SLTU: begin
                alu_out = (alu_operand_a < alu_operand_b) ? 32'd1 : 32'd0;
                alu_out_extended = {1'b0, alu_out};
            end
            `ALU_XOR: begin
                alu_out = alu_operand_a ^ alu_operand_b;
                alu_out_extended = {1'b0, alu_out};
            end
            `ALU_SRL: begin
                alu_out = alu_operand_a >> alu_operand_b[4:0];
                alu_out_extended = {1'b0, alu_out};
            end
            `ALU_SRA: begin
                alu_out = $signed(alu_operand_a) >>> alu_operand_b[4:0];
                alu_out_extended = {1'b0, alu_out};
            end
            `ALU_OR: begin
                alu_out = alu_operand_a | alu_operand_b;
                alu_out_extended = {1'b0, alu_out};
            end
            `ALU_AND: begin
                alu_out = alu_operand_a & alu_operand_b;
                alu_out_extended = {1'b0, alu_out};
            end
            `ALU_PASS_B: begin
                alu_out = alu_operand_b;
                alu_out_extended = {1'b0, alu_out};
            end
            default: begin
                alu_out = 32'b0;
                alu_out_extended = 33'b0;
            end
        endcase
    end
    
    // Flag computation
    // Zero Flag: Result is zero
    assign flag_zero = (alu_out == 32'b0);
    
    // Negative Flag: MSB of result is set
    assign flag_negative = alu_out[31];
    
    // Carry Flag: For ADD = carry out; For SUB = borrow (inverted carry)
    // SUB uses A + ~B + 1, so carry=1 means no borrow (A >= B)
    // We use borrow convention: carry=1 means borrow occurred (A < B for unsigned)
    assign flag_carry = (alu_op_in == `ALU_SUB) ? 
                        (alu_operand_a < alu_operand_b) :  // Borrow for SUB
                        alu_out_extended[32];              // Carry out for ADD
    
    // Overflow Flag: Signed overflow detection
    // For ADD: overflow if operands have same sign but result has different sign
    // For SUB: overflow if operands have different signs and result has different sign from A
    assign flag_overflow = (alu_op_in == `ALU_ADD) ? 
                           ((alu_operand_a[31] == alu_operand_b[31]) && (alu_out[31] != alu_operand_a[31])) :
                           (alu_op_in == `ALU_SUB) ?
                           ((alu_operand_a[31] != alu_operand_b[31]) && (alu_out[31] != alu_operand_a[31])) :
                           1'b0;
    
    // Combine flags: {V, C, N, Z}
    assign flags_computed = {flag_overflow, flag_carry, flag_negative, flag_zero};
    
    // Branch comparison
    always @(*) begin
        case (funct3_in)
            `BR_BEQ:  branch_cmp = (alu_operand_a == rs2_forwarded);
            `BR_BNE:  branch_cmp = (alu_operand_a != rs2_forwarded);
            `BR_BLT:  branch_cmp = ($signed(alu_operand_a) < $signed(rs2_forwarded));
            `BR_BGE:  branch_cmp = ($signed(alu_operand_a) >= $signed(rs2_forwarded));
            `BR_BLTU: branch_cmp = (alu_operand_a < rs2_forwarded);
            `BR_BGEU: branch_cmp = (alu_operand_a >= rs2_forwarded);
            default:  branch_cmp = 1'b0;
        endcase
    end
    
    // Branch/Jump resolution
    assign branch_taken = valid_in && (jump_in || (branch_in && branch_cmp));
    // JALR clears LSB per RISC-V spec; branches use PC-relative offset
    assign branch_target = jump_in ? {alu_out[31:1], 1'b0} : (pc_in + imm_in);
    
    // Pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            alu_result <= 32'b0;
            rs2_data_out <= 32'b0;
            rd_out <= 5'b0;
            mem_read_out <= 1'b0;
            mem_write_out <= 1'b0;
            reg_write_out <= 1'b0;
            mem_to_reg_out <= 1'b0;
            funct3_out <= 3'b0;
            valid_out <= 1'b0;
            flags_out <= 4'b0;
            flags_valid <= 1'b0;
        end else begin
            alu_result <= jump_in ? (pc_in + 4) : alu_out;  // JAL/JALR stores return address
            rs2_data_out <= rs2_forwarded;
            rd_out <= rd_in;
            mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in;
            reg_write_out <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            funct3_out <= funct3_in;
            // For JAL/JALR: keep valid so return address is written to rd
            // For branches: invalidate if branch is taken (flush wrong-path)
            valid_out <= valid_in && !(branch_in && branch_cmp);
            // Update flags only for ALU operations (not branches, loads, stores)
            flags_out <= flags_computed;
            flags_valid <= valid_in && !jump_in && !branch_in && !mem_read_in && !mem_write_in;
        end
    end

endmodule
