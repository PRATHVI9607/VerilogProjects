// Register File Module
// Provides operand data for functional units

`timescale 1ns/1ps

module register_file #(
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS = 32,
    parameter REG_BITS = 5
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Read port 1 (Fj)
    input  wire [REG_BITS-1:0] read_addr1,
    output wire [DATA_WIDTH-1:0] read_data1,
    
    // Read port 2 (Fk)
    input  wire [REG_BITS-1:0] read_addr2,
    output wire [DATA_WIDTH-1:0] read_data2,
    
    // Write port
    input  wire        write_en,
    input  wire [REG_BITS-1:0] write_addr,
    input  wire [DATA_WIDTH-1:0] write_data
);

    // Register array
    reg [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];
    
    // Read operations (combinational)
    assign read_data1 = (read_addr1 == 0) ? 0 : regs[read_addr1];
    assign read_data2 = (read_addr2 == 0) ? 0 : regs[read_addr2];
    
    // Write operation
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                regs[i] <= i; // Initialize with index for testing
            end
        end else begin
            if (write_en && write_addr != 0) begin
                regs[write_addr] <= write_data;
            end
        end
    end

endmodule
