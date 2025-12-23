`timescale 1ns/1ps
// Instruction Decode Stage (ID)
// Decodes instruction and reads register file

`include "riscv_pkg.v"

module instruction_decode (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        flush,
    
    // From IF stage
    input  wire [31:0] pc_in,
    input  wire [31:0] instruction_in,
    input  wire        valid_in,
    
    // Writeback from WB stage
    input  wire        wb_enable,
    input  wire [4:0]  wb_rd,
    input  wire [31:0] wb_data,
    
    // Outputs to EX stage
    output reg  [31:0] pc_out,
    output reg  [31:0] rs1_data,
    output reg  [31:0] rs2_data,
    output reg  [31:0] imm_out,
    output reg  [4:0]  rd_out,
    output reg  [4:0]  rs1_addr_out,
    output reg  [4:0]  rs2_addr_out,
    output reg  [3:0]  alu_op,
    output reg         alu_src,         // 0: rs2, 1: immediate
    output reg         mem_read,
    output reg         mem_write,
    output reg         reg_write,
    output reg         mem_to_reg,
    output reg         branch,
    output reg         jump,
    output reg  [2:0]  funct3_out,
    output reg         valid_out
);

    // Register file - 32 x 32-bit registers
    reg [31:0] regfile [0:31];
    
    // Internal wires
    wire [6:0]  opcode;
    wire [4:0]  rd, rs1, rs2;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    
    // Instruction decode
    assign opcode = instruction_in[6:0];
    assign rd     = instruction_in[11:7];
    assign funct3 = instruction_in[14:12];
    assign rs1    = instruction_in[19:15];
    assign rs2    = instruction_in[24:20];
    assign funct7 = instruction_in[31:25];
    
    // Immediate generation
    assign imm_i = {{20{instruction_in[31]}}, instruction_in[31:20]};
    assign imm_s = {{20{instruction_in[31]}}, instruction_in[31:25], instruction_in[11:7]};
    assign imm_b = {{19{instruction_in[31]}}, instruction_in[31], instruction_in[7], 
                   instruction_in[30:25], instruction_in[11:8], 1'b0};
    assign imm_u = {instruction_in[31:12], 12'b0};
    assign imm_j = {{11{instruction_in[31]}}, instruction_in[31], instruction_in[19:12],
                   instruction_in[20], instruction_in[30:21], 1'b0};
    
    // Initialize register file
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            regfile[i] = 32'b0;
        end
    end
    
    // Register file write (WB stage writes)
    always @(posedge clk) begin
        if (wb_enable && wb_rd != 5'b0) begin
            regfile[wb_rd] <= wb_data;
        end
    end
    
    // Pipeline register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            pc_out <= 32'b0;
            rs1_data <= 32'b0;
            rs2_data <= 32'b0;
            imm_out <= 32'b0;
            rd_out <= 5'b0;
            rs1_addr_out <= 5'b0;
            rs2_addr_out <= 5'b0;
            alu_op <= 4'b0;
            alu_src <= 1'b0;
            mem_read <= 1'b0;
            mem_write <= 1'b0;
            reg_write <= 1'b0;
            mem_to_reg <= 1'b0;
            branch <= 1'b0;
            jump <= 1'b0;
            funct3_out <= 3'b0;
            valid_out <= 1'b0;
        end else if (!stall) begin
            pc_out <= pc_in;
            rs1_addr_out <= rs1;
            rs2_addr_out <= rs2;
            rd_out <= rd;
            funct3_out <= funct3;
            valid_out <= valid_in;
            
            // Read register file (x0 always returns 0)
            rs1_data <= (rs1 == 5'b0) ? 32'b0 : regfile[rs1];
            rs2_data <= (rs2 == 5'b0) ? 32'b0 : regfile[rs2];
            
            // Control signal generation based on opcode
            case (opcode)
                `OP_LUI: begin
                    imm_out <= imm_u;
                    alu_op <= `ALU_PASS_B;
                    alu_src <= 1'b1;
                    mem_read <= 1'b0;
                    mem_write <= 1'b0;
                    reg_write <= 1'b1;
                    mem_to_reg <= 1'b0;
                    branch <= 1'b0;
                    jump <= 1'b0;
                end
                
                `OP_AUIPC: begin
                    imm_out <= imm_u;
                    alu_op <= `ALU_ADD;
                    alu_src <= 1'b1;
                    mem_read <= 1'b0;
                    mem_write <= 1'b0;
                    reg_write <= 1'b1;
                    mem_to_reg <= 1'b0;
                    branch <= 1'b0;
                    jump <= 1'b0;
                end
                
                `OP_JAL: begin
                    imm_out <= imm_j;
                    alu_op <= `ALU_ADD;
                    alu_src <= 1'b1;
                    mem_read <= 1'b0;
                    mem_write <= 1'b0;
                    reg_write <= 1'b1;
                    mem_to_reg <= 1'b0;
                    branch <= 1'b0;
                    jump <= 1'b1;
                end
                
                `OP_JALR: begin
                    imm_out <= imm_i;
                    alu_op <= `ALU_ADD;
                    alu_src <= 1'b1;
                    mem_read <= 1'b0;
                    mem_write <= 1'b0;
                    reg_write <= 1'b1;
                    mem_to_reg <= 1'b0;
                    branch <= 1'b0;
                    jump <= 1'b1;
                end
                
                `OP_BRANCH: begin
                    imm_out <= imm_b;
                    alu_op <= `ALU_SUB;
                    alu_src <= 1'b0;
                    mem_read <= 1'b0;
                    mem_write <= 1'b0;
                    reg_write <= 1'b0;
                    mem_to_reg <= 1'b0;
                    branch <= 1'b1;
                    jump <= 1'b0;
                end
                
                `OP_LOAD: begin
                    imm_out <= imm_i;
                    alu_op <= `ALU_ADD;
                    alu_src <= 1'b1;
                    mem_read <= 1'b1;
                    mem_write <= 1'b0;
                    reg_write <= 1'b1;
                    mem_to_reg <= 1'b1;
                    branch <= 1'b0;
                    jump <= 1'b0;
                end
                
                `OP_STORE: begin
                    imm_out <= imm_s;
                    alu_op <= `ALU_ADD;
                    alu_src <= 1'b1;
                    mem_read <= 1'b0;
                    mem_write <= 1'b1;
                    reg_write <= 1'b0;
                    mem_to_reg <= 1'b0;
                    branch <= 1'b0;
                    jump <= 1'b0;
                end
                
                `OP_IMM: begin
                    imm_out <= imm_i;
                    alu_src <= 1'b1;
                    mem_read <= 1'b0;
                    mem_write <= 1'b0;
                    reg_write <= 1'b1;
                    mem_to_reg <= 1'b0;
                    branch <= 1'b0;
                    jump <= 1'b0;
                    // ALU operation based on funct3
                    case (funct3)
                        3'b000: alu_op <= `ALU_ADD;   // ADDI
                        3'b010: alu_op <= `ALU_SLT;   // SLTI
                        3'b011: alu_op <= `ALU_SLTU;  // SLTIU
                        3'b100: alu_op <= `ALU_XOR;   // XORI
                        3'b110: alu_op <= `ALU_OR;    // ORI
                        3'b111: alu_op <= `ALU_AND;   // ANDI
                        3'b001: alu_op <= `ALU_SLL;   // SLLI
                        3'b101: alu_op <= (funct7[5]) ? `ALU_SRA : `ALU_SRL;  // SRLI/SRAI
                        default: alu_op <= `ALU_ADD;
                    endcase
                end
                
                `OP_REG: begin
                    imm_out <= 32'b0;
                    alu_src <= 1'b0;
                    mem_read <= 1'b0;
                    mem_write <= 1'b0;
                    reg_write <= 1'b1;
                    mem_to_reg <= 1'b0;
                    branch <= 1'b0;
                    jump <= 1'b0;
                    // ALU operation based on funct3 and funct7
                    case (funct3)
                        3'b000: alu_op <= (funct7[5]) ? `ALU_SUB : `ALU_ADD;
                        3'b001: alu_op <= `ALU_SLL;
                        3'b010: alu_op <= `ALU_SLT;
                        3'b011: alu_op <= `ALU_SLTU;
                        3'b100: alu_op <= `ALU_XOR;
                        3'b101: alu_op <= (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                        3'b110: alu_op <= `ALU_OR;
                        3'b111: alu_op <= `ALU_AND;
                        default: alu_op <= `ALU_ADD;
                    endcase
                end
                
                default: begin
                    imm_out <= 32'b0;
                    alu_op <= `ALU_ADD;
                    alu_src <= 1'b0;
                    mem_read <= 1'b0;
                    mem_write <= 1'b0;
                    reg_write <= 1'b0;
                    mem_to_reg <= 1'b0;
                    branch <= 1'b0;
                    jump <= 1'b0;
                end
            endcase
        end
    end

endmodule
