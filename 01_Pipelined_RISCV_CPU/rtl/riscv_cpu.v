`timescale 1ns/1ps

// Top-level Pipelined RISC-V CPU
// 5-stage pipeline: IF/ID/EX/MEM/WB with forwarding and hazard detection

module riscv_cpu (
    input  wire clk,
    input  wire rst_n
);

    // IF stage outputs
    wire [31:0] if_pc;
    wire [31:0] if_instruction;
    wire        if_valid;
    
    // ID stage outputs
    wire [31:0] id_pc;
    wire [31:0] id_rs1_data;
    wire [31:0] id_rs2_data;
    wire [31:0] id_imm;
    wire [4:0]  id_rd;
    wire [4:0]  id_rs1_addr;
    wire [4:0]  id_rs2_addr;
    wire [3:0]  id_alu_op;
    wire        id_alu_src;
    wire        id_mem_read;
    wire        id_mem_write;
    wire        id_reg_write;
    wire        id_mem_to_reg;
    wire        id_branch;
    wire        id_jump;
    wire [2:0]  id_funct3;
    wire        id_valid;
    
    // EX stage outputs
    wire [31:0] ex_alu_result;
    wire [31:0] ex_rs2_data;
    wire [4:0]  ex_rd;
    wire        ex_mem_read;
    wire        ex_mem_write;
    wire        ex_reg_write;
    wire        ex_mem_to_reg;
    wire [2:0]  ex_funct3;
    wire        ex_valid;
    wire        branch_taken;
    wire [31:0] branch_target;
    wire [1:0]  fwd_a_sel;
    wire [1:0]  fwd_b_sel;
    
    // MEM stage outputs
    wire [31:0] mem_alu_result;
    wire [31:0] mem_mem_data;
    wire [4:0]  mem_rd;
    wire        mem_reg_write;
    wire        mem_mem_to_reg;
    wire        mem_valid;
    wire [31:0] mem_forward_result;
    
    // WB stage outputs
    wire        wb_enable;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;
    
    // Hazard unit outputs
    wire        stall_if;
    wire        stall_id;
    wire        flush_ex;
    
    // Forwarding unit outputs
    wire [1:0]  forward_a;
    wire [1:0]  forward_b;
    
    // Instruction Fetch Stage
    instruction_fetch u_if (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall         (stall_if),
        .branch_taken  (branch_taken),
        .branch_target (branch_target),
        .pc_out        (if_pc),
        .instruction   (if_instruction),
        .valid         (if_valid)
    );
    
    // Instruction Decode Stage
    instruction_decode u_id (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall          (stall_id),
        .flush          (branch_taken),
        .pc_in          (if_pc),
        .instruction_in (if_instruction),
        .valid_in       (if_valid),
        .wb_enable      (wb_enable),
        .wb_rd          (wb_rd),
        .wb_data        (wb_data),
        .pc_out         (id_pc),
        .rs1_data       (id_rs1_data),
        .rs2_data       (id_rs2_data),
        .imm_out        (id_imm),
        .rd_out         (id_rd),
        .rs1_addr_out   (id_rs1_addr),
        .rs2_addr_out   (id_rs2_addr),
        .alu_op         (id_alu_op),
        .alu_src        (id_alu_src),
        .mem_read       (id_mem_read),
        .mem_write      (id_mem_write),
        .reg_write      (id_reg_write),
        .mem_to_reg     (id_mem_to_reg),
        .branch         (id_branch),
        .jump           (id_jump),
        .funct3_out     (id_funct3),
        .valid_out      (id_valid)
    );
    
    // Execute Stage
    execute u_ex (
        .clk            (clk),
        .rst_n          (rst_n),
        .flush          (flush_ex),
        .pc_in          (id_pc),
        .rs1_data_in    (id_rs1_data),
        .rs2_data_in    (id_rs2_data),
        .imm_in         (id_imm),
        .rd_in          (id_rd),
        .rs1_addr_in    (id_rs1_addr),
        .rs2_addr_in    (id_rs2_addr),
        .alu_op_in      (id_alu_op),
        .alu_src_in     (id_alu_src),
        .mem_read_in    (id_mem_read),
        .mem_write_in   (id_mem_write),
        .reg_write_in   (id_reg_write),
        .mem_to_reg_in  (id_mem_to_reg),
        .branch_in      (id_branch),
        .jump_in        (id_jump),
        .funct3_in      (id_funct3),
        .valid_in       (id_valid),
        .forward_a      (forward_a),
        .forward_b      (forward_b),
        .ex_mem_result  (mem_forward_result),
        .mem_wb_result  (wb_data),
        .alu_result     (ex_alu_result),
        .rs2_data_out   (ex_rs2_data),
        .rd_out         (ex_rd),
        .mem_read_out   (ex_mem_read),
        .mem_write_out  (ex_mem_write),
        .reg_write_out  (ex_reg_write),
        .mem_to_reg_out (ex_mem_to_reg),
        .funct3_out     (ex_funct3),
        .valid_out      (ex_valid),
        .branch_taken   (branch_taken),
        .branch_target  (branch_target),
        .fwd_a_sel      (fwd_a_sel),
        .fwd_b_sel      (fwd_b_sel)
    );
    
    // Memory Stage
    memory_stage u_mem (
        .clk            (clk),
        .rst_n          (rst_n),
        .alu_result_in  (ex_alu_result),
        .rs2_data_in    (ex_rs2_data),
        .rd_in          (ex_rd),
        .mem_read_in    (ex_mem_read),
        .mem_write_in   (ex_mem_write),
        .reg_write_in   (ex_reg_write),
        .mem_to_reg_in  (ex_mem_to_reg),
        .funct3_in      (ex_funct3),
        .valid_in       (ex_valid),
        .alu_result_out (mem_alu_result),
        .mem_data_out   (mem_mem_data),
        .rd_out         (mem_rd),
        .reg_write_out  (mem_reg_write),
        .mem_to_reg_out (mem_mem_to_reg),
        .valid_out      (mem_valid),
        .mem_result     (mem_forward_result)
    );
    
    // Writeback Stage
    writeback u_wb (
        .alu_result_in  (mem_alu_result),
        .mem_data_in    (mem_mem_data),
        .rd_in          (mem_rd),
        .reg_write_in   (mem_reg_write),
        .mem_to_reg_in  (mem_mem_to_reg),
        .valid_in       (mem_valid),
        .wb_enable      (wb_enable),
        .wb_rd          (wb_rd),
        .wb_data        (wb_data)
    );
    
    // Hazard Detection Unit
    hazard_unit u_hazard (
        .if_id_rs1      (if_instruction[19:15]),
        .if_id_rs2      (if_instruction[24:20]),
        .id_ex_rd       (id_rd),
        .id_ex_mem_read (id_mem_read),
        .id_ex_valid    (id_valid),
        .stall_if       (stall_if),
        .stall_id       (stall_id),
        .flush_ex       (flush_ex)
    );
    
    // Forwarding Unit
    forwarding_unit u_forward (
        .id_ex_rs1        (id_rs1_addr),
        .id_ex_rs2        (id_rs2_addr),
        .ex_mem_rd        (ex_rd),
        .ex_mem_reg_write (ex_reg_write),
        .ex_mem_valid     (ex_valid),
        .mem_wb_rd        (mem_rd),
        .mem_wb_reg_write (mem_reg_write),
        .mem_wb_valid     (mem_valid),
        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );

endmodule
