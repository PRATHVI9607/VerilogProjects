`timescale 1ns/1ps

// Writeback Stage (WB)
// Writes results back to register file

module writeback (
    // From MEM stage
    input  wire [31:0] alu_result_in,
    input  wire [31:0] mem_data_in,
    input  wire [4:0]  rd_in,
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,
    input  wire        valid_in,
    
    // Outputs to register file
    output wire        wb_enable,
    output wire [4:0]  wb_rd,
    output wire [31:0] wb_data
);

    // Select between ALU result and memory data
    assign wb_data = mem_to_reg_in ? mem_data_in : alu_result_in;
    
    // Enable write to register file
    assign wb_enable = reg_write_in && valid_in && (rd_in != 5'b0);
    
    // Destination register
    assign wb_rd = rd_in;

endmodule
