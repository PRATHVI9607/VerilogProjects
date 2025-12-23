`timescale 1ns/1ps

// Common Data Bus (CDB) Arbiter
// Arbitrates between multiple execution units for CDB access

module cdb_arbiter #(
    parameter NUM_UNITS = 3,
    parameter TAG_WIDTH = 6
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Unit 0 (ALU)
    input  wire        unit0_valid,
    input  wire [TAG_WIDTH-1:0] unit0_tag,
    input  wire [31:0] unit0_data,
    output wire        unit0_ack,
    
    // Unit 1 (MUL)
    input  wire        unit1_valid,
    input  wire [TAG_WIDTH-1:0] unit1_tag,
    input  wire [31:0] unit1_data,
    output wire        unit1_ack,
    
    // Unit 2 (MEM)
    input  wire        unit2_valid,
    input  wire [TAG_WIDTH-1:0] unit2_tag,
    input  wire [31:0] unit2_data,
    output wire        unit2_ack,
    
    // CDB output
    output reg         cdb_valid,
    output reg  [TAG_WIDTH-1:0] cdb_tag,
    output reg  [31:0] cdb_data,
    
    // Arbitration status
    output wire [1:0]  grant
);

    // Priority encoder (fixed priority: 0 > 1 > 2)
    reg [1:0] selected;
    
    always @(*) begin
        if (unit0_valid) selected = 2'd0;
        else if (unit1_valid) selected = 2'd1;
        else if (unit2_valid) selected = 2'd2;
        else selected = 2'd3;  // None
    end
    
    // Grant signals
    assign unit0_ack = unit0_valid && (selected == 2'd0);
    assign unit1_ack = unit1_valid && (selected == 2'd1);
    assign unit2_ack = unit2_valid && (selected == 2'd2);
    assign grant = selected;
    
    // CDB output selection
    always @(*) begin
        case (selected)
            2'd0: begin
                cdb_valid = unit0_valid;
                cdb_tag = unit0_tag;
                cdb_data = unit0_data;
            end
            2'd1: begin
                cdb_valid = unit1_valid;
                cdb_tag = unit1_tag;
                cdb_data = unit1_data;
            end
            2'd2: begin
                cdb_valid = unit2_valid;
                cdb_tag = unit2_tag;
                cdb_data = unit2_data;
            end
            default: begin
                cdb_valid = 1'b0;
                cdb_tag = 0;
                cdb_data = 32'b0;
            end
        endcase
    end

endmodule
