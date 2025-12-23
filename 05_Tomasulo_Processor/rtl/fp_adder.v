// Tomasulo FP Adder Unit
// Multi-cycle pipelined adder with structural hazard detection

`include "tomasulo_pkg.v"

module fp_adder #(
    parameter LATENCY = 2,
    parameter TAG_WIDTH = 4
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Dispatch interface
    input  wire        dispatch_valid,
    input  wire [2:0]  dispatch_op,
    input  wire [31:0] dispatch_vj,
    input  wire [31:0] dispatch_vk,
    input  wire [TAG_WIDTH-1:0] dispatch_tag,
    output wire        dispatch_ack,
    
    // CDB interface
    output reg         cdb_request,
    output reg  [TAG_WIDTH-1:0] cdb_tag,
    output reg  [31:0] cdb_data,
    input  wire        cdb_grant,
    
    // Status
    output wire        busy
);

    // Pipeline stages
    reg        valid [0:LATENCY];
    reg [TAG_WIDTH-1:0] tag [0:LATENCY];
    reg [31:0] result [0:LATENCY];
    
    // Accept dispatch if first stage is free
    assign dispatch_ack = dispatch_valid && !valid[0];
    assign busy = valid[0] || cdb_request;
    
    // Compute result (simplified - just add/sub integers for demo)
    wire [31:0] computed_result = (dispatch_op == `FP_SUB) ? 
                                  (dispatch_vj - dispatch_vk) :
                                  (dispatch_vj + dispatch_vk);
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i <= LATENCY; i = i + 1) begin
                valid[i] <= 1'b0;
                tag[i] <= 0;
                result[i] <= 32'b0;
            end
            cdb_request <= 1'b0;
            cdb_tag <= 0;
            cdb_data <= 32'b0;
        end else begin
            // CDB handshake
            if (cdb_grant && cdb_request) begin
                cdb_request <= 1'b0;
            end
            
            // Output stage to CDB
            if (valid[LATENCY] && !cdb_request) begin
                cdb_request <= 1'b1;
                cdb_tag <= tag[LATENCY];
                cdb_data <= result[LATENCY];
                valid[LATENCY] <= 1'b0;
            end
            
            // Pipeline stages
            for (i = LATENCY; i > 0; i = i - 1) begin
                if (!valid[i] || (i == LATENCY && cdb_grant)) begin
                    valid[i] <= valid[i-1];
                    tag[i] <= tag[i-1];
                    result[i] <= result[i-1];
                    if (i == 1) valid[0] <= 1'b0;
                end
            end
            
            // Input stage
            if (dispatch_valid && dispatch_ack) begin
                valid[0] <= 1'b1;
                tag[0] <= dispatch_tag;
                result[0] <= computed_result;
            end
        end
    end

endmodule
