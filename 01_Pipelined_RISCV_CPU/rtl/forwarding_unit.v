`timescale 1ns/1ps

// Forwarding Unit
// Resolves data hazards by forwarding results from later stages

`include "riscv_pkg.v"

module forwarding_unit (
    // Source registers from ID/EX stage
    input  wire [4:0] id_ex_rs1,
    input  wire [4:0] id_ex_rs2,
    
    // Destination registers from later stages
    input  wire [4:0] ex_mem_rd,
    input  wire       ex_mem_reg_write,
    input  wire       ex_mem_valid,
    
    input  wire [4:0] mem_wb_rd,
    input  wire       mem_wb_reg_write,
    input  wire       mem_wb_valid,
    
    // Forwarding control outputs
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);

    // Forwarding logic for operand A (rs1)
    always @(*) begin
        if (ex_mem_reg_write && ex_mem_valid && 
            (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1)) begin
            // Forward from EX/MEM stage
            forward_a = `FWD_EX_MEM;
        end else if (mem_wb_reg_write && mem_wb_valid && 
                    (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1)) begin
            // Forward from MEM/WB stage
            forward_a = `FWD_MEM_WB;
        end else begin
            // No forwarding needed
            forward_a = `FWD_NONE;
        end
    end
    
    // Forwarding logic for operand B (rs2)
    always @(*) begin
        if (ex_mem_reg_write && ex_mem_valid && 
            (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2)) begin
            // Forward from EX/MEM stage
            forward_b = `FWD_EX_MEM;
        end else if (mem_wb_reg_write && mem_wb_valid && 
                    (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2)) begin
            // Forward from MEM/WB stage
            forward_b = `FWD_MEM_WB;
        end else begin
            // No forwarding needed
            forward_b = `FWD_NONE;
        end
    end

endmodule
