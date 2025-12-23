`timescale 1ns/1ps

// Superscalar Dual-Issue CPU - Dual Decode Unit
// Decodes two instructions and checks for dependencies

module dual_decode (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        flush,
    
    // From fetch
    input  wire [31:0] pc_0,
    input  wire [31:0] pc_1,
    input  wire [31:0] inst_0,
    input  wire [31:0] inst_1,
    input  wire        valid_0_in,
    input  wire        valid_1_in,
    
    // Decoded outputs - instruction 0
    output reg  [31:0] dec_pc_0,
    output reg  [4:0]  dec_rs1_0,
    output reg  [4:0]  dec_rs2_0,
    output reg  [4:0]  dec_rd_0,
    output reg  [3:0]  dec_alu_op_0,
    output reg  [31:0] dec_imm_0,
    output reg         dec_has_rd_0,
    output reg         dec_use_imm_0,
    output reg         dec_valid_0,
    
    // Decoded outputs - instruction 1
    output reg  [31:0] dec_pc_1,
    output reg  [4:0]  dec_rs1_1,
    output reg  [4:0]  dec_rs2_1,
    output reg  [4:0]  dec_rd_1,
    output reg  [3:0]  dec_alu_op_1,
    output reg  [31:0] dec_imm_1,
    output reg         dec_has_rd_1,
    output reg         dec_use_imm_1,
    output reg         dec_valid_1,
    
    // Dependency status
    output wire        raw_hazard  // RAW between inst 0 and 1
);

    // Decode fields
    wire [6:0] opcode_0 = inst_0[6:0];
    wire [4:0] rd_0     = inst_0[11:7];
    wire [2:0] funct3_0 = inst_0[14:12];
    wire [4:0] rs1_0    = inst_0[19:15];
    wire [4:0] rs2_0    = inst_0[24:20];
    
    wire [6:0] opcode_1 = inst_1[6:0];
    wire [4:0] rd_1     = inst_1[11:7];
    wire [2:0] funct3_1 = inst_1[14:12];
    wire [4:0] rs1_1    = inst_1[19:15];
    wire [4:0] rs2_1    = inst_1[24:20];
    
    // Immediate generation
    wire [31:0] imm_i_0 = {{20{inst_0[31]}}, inst_0[31:20]};
    wire [31:0] imm_i_1 = {{20{inst_1[31]}}, inst_1[31:20]};
    
    // Check for RAW hazard: inst_1 reads what inst_0 writes
    wire rd0_rs1_1 = (rd_0 == rs1_1) && (rd_0 != 0);
    wire rd0_rs2_1 = (rd_0 == rs2_1) && (rd_0 != 0);
    assign raw_hazard = (rd0_rs1_1 || rd0_rs2_1) && valid_0_in && valid_1_in;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            dec_valid_0 <= 1'b0;
            dec_valid_1 <= 1'b0;
            dec_pc_0 <= 32'b0;
            dec_pc_1 <= 32'b0;
            dec_rs1_0 <= 5'b0;
            dec_rs2_0 <= 5'b0;
            dec_rd_0 <= 5'b0;
            dec_rs1_1 <= 5'b0;
            dec_rs2_1 <= 5'b0;
            dec_rd_1 <= 5'b0;
            dec_alu_op_0 <= 4'b0;
            dec_alu_op_1 <= 4'b0;
            dec_imm_0 <= 32'b0;
            dec_imm_1 <= 32'b0;
            dec_has_rd_0 <= 1'b0;
            dec_has_rd_1 <= 1'b0;
            dec_use_imm_0 <= 1'b0;
            dec_use_imm_1 <= 1'b0;
        end else if (!stall) begin
            // Instruction 0
            dec_pc_0 <= pc_0;
            dec_rs1_0 <= rs1_0;
            dec_rs2_0 <= rs2_0;
            dec_rd_0 <= rd_0;
            dec_imm_0 <= imm_i_0;
            dec_valid_0 <= valid_0_in;
            
            // Decode opcode 0
            case (opcode_0)
                7'b0110011: begin  // R-type
                    dec_has_rd_0 <= 1'b1;
                    dec_use_imm_0 <= 1'b0;
                    dec_alu_op_0 <= {inst_0[30], funct3_0};
                end
                7'b0010011: begin  // I-type ALU
                    dec_has_rd_0 <= 1'b1;
                    dec_use_imm_0 <= 1'b1;
                    dec_alu_op_0 <= {1'b0, funct3_0};
                end
                default: begin
                    dec_has_rd_0 <= 1'b0;
                    dec_use_imm_0 <= 1'b0;
                    dec_alu_op_0 <= 4'b0;
                end
            endcase
            
            // Instruction 1
            dec_pc_1 <= pc_1;
            dec_rs1_1 <= rs1_1;
            dec_rs2_1 <= rs2_1;
            dec_rd_1 <= rd_1;
            dec_imm_1 <= imm_i_1;
            dec_valid_1 <= valid_1_in;
            
            // Decode opcode 1
            case (opcode_1)
                7'b0110011: begin
                    dec_has_rd_1 <= 1'b1;
                    dec_use_imm_1 <= 1'b0;
                    dec_alu_op_1 <= {inst_1[30], funct3_1};
                end
                7'b0010011: begin
                    dec_has_rd_1 <= 1'b1;
                    dec_use_imm_1 <= 1'b1;
                    dec_alu_op_1 <= {1'b0, funct3_1};
                end
                default: begin
                    dec_has_rd_1 <= 1'b0;
                    dec_use_imm_1 <= 1'b0;
                    dec_alu_op_1 <= 4'b0;
                end
            endcase
        end
    end

endmodule
