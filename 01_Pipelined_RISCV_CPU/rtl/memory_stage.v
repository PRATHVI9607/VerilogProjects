`timescale 1ns/1ps

// Memory Stage (MEM)
// Handles data memory read/write operations

module memory_stage (
    input  wire        clk,
    input  wire        rst_n,
    
    // From EX stage
    input  wire [31:0] alu_result_in,
    input  wire [31:0] rs2_data_in,
    input  wire [4:0]  rd_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,
    input  wire [2:0]  funct3_in,
    input  wire        valid_in,
    
    // Outputs to WB stage
    output reg  [31:0] alu_result_out,
    output reg  [31:0] mem_data_out,
    output reg  [4:0]  rd_out,
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg         valid_out,
    
    // Forwarding output
    output wire [31:0] mem_result
);

    // Data memory (RAM) - 1KB
    reg [7:0] dmem [0:1023];
    
    // Memory read data
    reg [31:0] read_data;
    
    // Forwarding path - return correct data based on instruction type
    // For loads: forward the read_data; for ALU ops: forward ALU result
    assign mem_result = mem_to_reg_in ? read_data : alu_result_in;
    
    // Initialize data memory
    integer mem_idx;
    initial begin
        for (mem_idx = 0; mem_idx < 1024; mem_idx = mem_idx + 1) begin
            dmem[mem_idx] = 8'b0;
        end
    end
    
    // Memory read address calculation
    wire [9:0] mem_addr = alu_result_in[9:0];
    
    // Memory operations (combinational read)
    always @(*) begin
        if (mem_read_in && valid_in) begin
            case (funct3_in)
                3'b000: begin  // LB - Load Byte (signed)
                    read_data = {{24{dmem[mem_addr][7]}}, dmem[mem_addr]};
                end
                3'b001: begin  // LH - Load Halfword (signed)
                    read_data = {{16{dmem[mem_addr+1][7]}}, 
                                dmem[mem_addr+1], dmem[mem_addr]};
                end
                3'b010: begin  // LW - Load Word
                    read_data = {dmem[mem_addr+3], dmem[mem_addr+2],
                                dmem[mem_addr+1], dmem[mem_addr]};
                end
                3'b100: begin  // LBU - Load Byte Unsigned
                    read_data = {24'b0, dmem[mem_addr]};
                end
                3'b101: begin  // LHU - Load Halfword Unsigned
                    read_data = {16'b0, dmem[mem_addr+1], dmem[mem_addr]};
                end
                default: read_data = 32'b0;
            endcase
        end else begin
            read_data = 32'b0;
        end
    end
    
    // Memory write (with reset guard to prevent garbage writes)
    always @(posedge clk) begin
        if (rst_n && mem_write_in && valid_in) begin
            case (funct3_in)
                3'b000: begin  // SB - Store Byte
                    dmem[mem_addr] <= rs2_data_in[7:0];
                end
                3'b001: begin  // SH - Store Halfword
                    dmem[mem_addr]   <= rs2_data_in[7:0];
                    dmem[mem_addr+1] <= rs2_data_in[15:8];
                end
                3'b010: begin  // SW - Store Word
                    dmem[mem_addr]   <= rs2_data_in[7:0];
                    dmem[mem_addr+1] <= rs2_data_in[15:8];
                    dmem[mem_addr+2] <= rs2_data_in[23:16];
                    dmem[mem_addr+3] <= rs2_data_in[31:24];
                end
                default: ;
            endcase
        end
    end
    
    // Pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_out <= 32'b0;
            mem_data_out <= 32'b0;
            rd_out <= 5'b0;
            reg_write_out <= 1'b0;
            mem_to_reg_out <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            alu_result_out <= alu_result_in;
            mem_data_out <= read_data;
            rd_out <= rd_in;
            reg_write_out <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            valid_out <= valid_in;
        end
    end

endmodule
