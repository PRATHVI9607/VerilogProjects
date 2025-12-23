`timescale 1ns/1ps

// Superscalar Dual-Issue CPU - Top Module

module superscalar_cpu (
    input  wire clk,
    input  wire rst_n
);

    // Fetch stage outputs
    wire [31:0] if_pc_0, if_pc_1;
    wire [31:0] if_inst_0, if_inst_1;
    wire        if_valid_0, if_valid_1;
    
    // Decode stage outputs
    wire [31:0] id_pc_0, id_pc_1;
    wire [4:0]  id_rs1_0, id_rs2_0, id_rd_0;
    wire [4:0]  id_rs1_1, id_rs2_1, id_rd_1;
    wire [3:0]  id_alu_op_0, id_alu_op_1;
    wire [31:0] id_imm_0, id_imm_1;
    wire        id_has_rd_0, id_has_rd_1;
    wire        id_use_imm_0, id_use_imm_1;
    wire        id_valid_0, id_valid_1;
    wire        raw_hazard;
    
    // Execute stage outputs
    wire [31:0] ex_result_0, ex_result_1;
    wire [4:0]  ex_rd_0, ex_rd_1;
    wire        ex_valid_0, ex_valid_1;
    
    // Physical register file (64 x 32-bit)
    reg [31:0] phys_regfile [0:63];
    
    // Register rename signals
    wire [5:0] phys_rs1_0, phys_rs2_0, phys_rd_0;
    wire [5:0] phys_rs1_1, phys_rs2_1, phys_rd_1;
    wire       rename_ack_0, rename_ack_1;
    wire       freelist_empty;
    
    // Stall logic
    wire stall = freelist_empty;
    
    // Read physical registers
    wire [31:0] rs1_data_0 = phys_regfile[phys_rs1_0];
    wire [31:0] rs2_data_0 = phys_regfile[phys_rs2_0];
    wire [31:0] rs1_data_1 = phys_regfile[phys_rs1_1];
    wire [31:0] rs2_data_1 = phys_regfile[phys_rs2_1];
    
    // ALU operands
    wire [31:0] alu_a_0 = rs1_data_0;
    wire [31:0] alu_b_0 = id_use_imm_0 ? id_imm_0 : rs2_data_0;
    wire [31:0] alu_a_1 = rs1_data_1;
    wire [31:0] alu_b_1 = id_use_imm_1 ? id_imm_1 : rs2_data_1;
    
    // Initialize physical register file
    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            phys_regfile[i] = 32'b0;
        end
    end
    
    // Write back results
    always @(posedge clk) begin
        if (ex_valid_0 && ex_rd_0 != 0) begin
            phys_regfile[ex_rd_0] <= ex_result_0;
        end
        if (ex_valid_1 && ex_rd_1 != 0) begin
            phys_regfile[ex_rd_1] <= ex_result_1;
        end
    end
    
    // Dual Fetch Unit
    dual_fetch u_fetch (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall        (stall),
        .flush        (1'b0),
        .branch_target(32'b0),
        .branch_taken (1'b0),
        .pc_0         (if_pc_0),
        .pc_1         (if_pc_1),
        .inst_0       (if_inst_0),
        .inst_1       (if_inst_1),
        .valid_0      (if_valid_0),
        .valid_1      (if_valid_1)
    );
    
    // Dual Decode Unit
    dual_decode u_decode (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall        (stall),
        .flush        (1'b0),
        .pc_0         (if_pc_0),
        .pc_1         (if_pc_1),
        .inst_0       (if_inst_0),
        .inst_1       (if_inst_1),
        .valid_0_in   (if_valid_0),
        .valid_1_in   (if_valid_1),
        .dec_pc_0     (id_pc_0),
        .dec_rs1_0    (id_rs1_0),
        .dec_rs2_0    (id_rs2_0),
        .dec_rd_0     (id_rd_0),
        .dec_alu_op_0 (id_alu_op_0),
        .dec_imm_0    (id_imm_0),
        .dec_has_rd_0 (id_has_rd_0),
        .dec_use_imm_0(id_use_imm_0),
        .dec_valid_0  (id_valid_0),
        .dec_pc_1     (id_pc_1),
        .dec_rs1_1    (id_rs1_1),
        .dec_rs2_1    (id_rs2_1),
        .dec_rd_1     (id_rd_1),
        .dec_alu_op_1 (id_alu_op_1),
        .dec_imm_1    (id_imm_1),
        .dec_has_rd_1 (id_has_rd_1),
        .dec_use_imm_1(id_use_imm_1),
        .dec_valid_1  (id_valid_1),
        .raw_hazard   (raw_hazard)
    );
    
    // Register Rename Unit
    register_rename #(
        .ARCH_REGS(32),
        .PHYS_REGS(64),
        .TAG_WIDTH(6)
    ) u_rename (
        .clk           (clk),
        .rst_n         (rst_n),
        .rename_valid_0(id_valid_0),
        .rename_rs1_0  (id_rs1_0),
        .rename_rs2_0  (id_rs2_0),
        .rename_rd_0   (id_rd_0),
        .has_rd_0      (id_has_rd_0),
        .rename_valid_1(id_valid_1),
        .rename_rs1_1  (id_rs1_1),
        .rename_rs2_1  (id_rs2_1),
        .rename_rd_1   (id_rd_1),
        .has_rd_1      (id_has_rd_1),
        .phys_rs1_0    (phys_rs1_0),
        .phys_rs2_0    (phys_rs2_0),
        .phys_rd_0     (phys_rd_0),
        .rename_ack_0  (rename_ack_0),
        .phys_rs1_1    (phys_rs1_1),
        .phys_rs2_1    (phys_rs2_1),
        .phys_rd_1     (phys_rd_1),
        .rename_ack_1  (rename_ack_1),
        .free_valid    (1'b0),
        .free_preg     (6'b0),
        .commit_valid_0(1'b0),
        .commit_rd_0   (5'b0),
        .commit_preg_0 (6'b0),
        .commit_valid_1(1'b0),
        .commit_rd_1   (5'b0),
        .commit_preg_1 (6'b0),
        .freelist_empty(freelist_empty)
    );
    
    // Dual ALU Execute
    dual_alu u_alu (
        .clk           (clk),
        .rst_n         (rst_n),
        .valid_0       (id_valid_0 && rename_ack_0),
        .alu_op_0      (id_alu_op_0),
        .operand_a_0   (alu_a_0),
        .operand_b_0   (alu_b_0),
        .rd_0          (id_rd_0),
        .valid_1       (id_valid_1 && rename_ack_1),
        .alu_op_1      (id_alu_op_1),
        .operand_a_1   (alu_a_1),
        .operand_b_1   (alu_b_1),
        .rd_1          (id_rd_1),
        .result_0      (ex_result_0),
        .result_rd_0   (ex_rd_0),
        .result_valid_0(ex_valid_0),
        .result_1      (ex_result_1),
        .result_rd_1   (ex_rd_1),
        .result_valid_1(ex_valid_1)
    );

endmodule
