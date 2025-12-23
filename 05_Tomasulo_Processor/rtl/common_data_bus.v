// Common Data Bus (CDB) for Tomasulo
// Broadcasts results to all reservation stations and register status

`include "tomasulo_pkg.v"

module common_data_bus #(
    parameter TAG_WIDTH = 4
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Adder request
    input  wire        add_request,
    input  wire [TAG_WIDTH-1:0] add_tag,
    input  wire [31:0] add_data,
    output wire        add_grant,
    
    // Multiplier request
    input  wire        mul_request,
    input  wire [TAG_WIDTH-1:0] mul_tag,
    input  wire [31:0] mul_data,
    output wire        mul_grant,
    
    // Load unit request
    input  wire        load_request,
    input  wire [TAG_WIDTH-1:0] load_tag,
    input  wire [31:0] load_data,
    output wire        load_grant,
    
    // CDB output (broadcast to all)
    output reg         cdb_valid,
    output reg  [TAG_WIDTH-1:0] cdb_tag,
    output reg  [31:0] cdb_data,
    
    // Arbitration status
    output reg  [1:0]  grant_unit
);

    // Priority arbitration (round-robin would be better for fairness)
    // Priority: load > mul > add
    wire [1:0] selected;
    
    assign selected = load_request ? 2'd2 :
                     (mul_request ? 2'd1 :
                     (add_request ? 2'd0 : 2'd3));
    
    assign load_grant = load_request && (selected == 2'd2);
    assign mul_grant  = mul_request && (selected == 2'd1);
    assign add_grant  = add_request && (selected == 2'd0);
    
    // CDB output
    always @(*) begin
        case (selected)
            2'd0: begin
                cdb_valid = add_request;
                cdb_tag = add_tag;
                cdb_data = add_data;
            end
            2'd1: begin
                cdb_valid = mul_request;
                cdb_tag = mul_tag;
                cdb_data = mul_data;
            end
            2'd2: begin
                cdb_valid = load_request;
                cdb_tag = load_tag;
                cdb_data = load_data;
            end
            default: begin
                cdb_valid = 1'b0;
                cdb_tag = 0;
                cdb_data = 32'b0;
            end
        endcase
        grant_unit = selected;
    end

endmodule
