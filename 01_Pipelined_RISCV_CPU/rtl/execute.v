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
    output wire [1:0]  fwd_b_sel
);

    // Forwarding mux outputs
    reg [31:0] alu_operand_a;
    reg [31:0] alu_operand_b;
    reg [31:0] rs2_forwarded;
    
    // ALU result wire
    reg [31:0] alu_out;
    
    // Branch comparison result
    reg branch_cmp;
    
    // Forward selection visibility
    assign fwd_a_sel = forward_a;
    assign fwd_b_sel = forward_b;
    
    // Forwarding MUX for operand A
    always @(*) begin
        case (forward_a)
            `FWD_EX_MEM: alu_operand_a = ex_mem_result;
            `FWD_MEM_WB: alu_operand_a = mem_wb_result;
            default:     alu_operand_a = rs1_data_in;
        endcase
    end
    
    // Forwarding MUX for operand B (pre-ALU src mux)
    always @(*) begin
        case (forward_b)
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
            `ALU_ADD:    alu_out = alu_operand_a + alu_operand_b;
            `ALU_SUB:    alu_out = alu_operand_a - alu_operand_b;
            `ALU_SLL:    alu_out = alu_operand_a << alu_operand_b[4:0];
            `ALU_SLT:    alu_out = ($signed(alu_operand_a) < $signed(alu_operand_b)) ? 32'd1 : 32'd0;
            `ALU_SLTU:   alu_out = (alu_operand_a < alu_operand_b) ? 32'd1 : 32'd0;
            `ALU_XOR:    alu_out = alu_operand_a ^ alu_operand_b;
            `ALU_SRL:    alu_out = alu_operand_a >> alu_operand_b[4:0];
            `ALU_SRA:    alu_out = $signed(alu_operand_a) >>> alu_operand_b[4:0];
            `ALU_OR:     alu_out = alu_operand_a | alu_operand_b;
            `ALU_AND:    alu_out = alu_operand_a & alu_operand_b;
            `ALU_PASS_B: alu_out = alu_operand_b;
            default:     alu_out = 32'b0;
        endcase
    end
    
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
    assign branch_target = jump_in ? alu_out : (pc_in + imm_in);
    
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
        end else begin
            alu_result <= jump_in ? (pc_in + 4) : alu_out;  // JAL/JALR stores return address
            rs2_data_out <= rs2_forwarded;
            rd_out <= rd_in;
            mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in;
            reg_write_out <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            funct3_out <= funct3_in;
            valid_out <= valid_in && !branch_taken;
        end
    end

endmodule
