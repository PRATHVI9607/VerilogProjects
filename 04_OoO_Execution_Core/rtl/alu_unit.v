`timescale 1ns/1ps

// Execution Unit - ALU
// Performs arithmetic/logic operations

module alu_unit #(
    parameter TAG_WIDTH = 6,
    parameter LATENCY = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Dispatch interface (from RS)
    input  wire        dispatch_valid,
    input  wire [2:0]  dispatch_op,
    input  wire [31:0] dispatch_val1,
    input  wire [31:0] dispatch_val2,
    input  wire [TAG_WIDTH-1:0] dispatch_tag,
    output wire        dispatch_ack,
    
    // Result interface (to CDB)
    output reg         result_valid,
    output reg  [TAG_WIDTH-1:0] result_tag,
    output reg  [31:0] result_data,
    input  wire        result_ack,
    
    // Status
    output wire        busy
);

    // Pipeline registers for latency > 1
    reg        pipe_valid [0:LATENCY-1];
    reg [TAG_WIDTH-1:0] pipe_tag [0:LATENCY-1];
    reg [31:0] pipe_result [0:LATENCY-1];
    
    // ALU operation
    reg [31:0] alu_result;
    
    always @(*) begin
        case (dispatch_op)
            3'd0: alu_result = dispatch_val1 + dispatch_val2;  // ADD
            3'd1: alu_result = dispatch_val1 - dispatch_val2;  // SUB
            3'd4: alu_result = dispatch_val1 & dispatch_val2;  // AND
            3'd5: alu_result = dispatch_val1 | dispatch_val2;  // OR
            3'd6: alu_result = dispatch_val1 ^ dispatch_val2;  // XOR
            default: alu_result = 32'b0;
        endcase
    end
    
    // Accept dispatch if not outputting result
    assign dispatch_ack = dispatch_valid && !result_valid;
    assign busy = pipe_valid[0] || result_valid;
    
    integer i;
    
    // Pipeline logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < LATENCY; i = i + 1) begin
                pipe_valid[i] <= 1'b0;
                pipe_tag[i] <= 0;
                pipe_result[i] <= 32'b0;
            end
            result_valid <= 1'b0;
            result_tag <= 0;
            result_data <= 32'b0;
        end else begin
            // Input stage
            if (dispatch_valid && dispatch_ack) begin
                pipe_valid[0] <= 1'b1;
                pipe_tag[0] <= dispatch_tag;
                pipe_result[0] <= alu_result;
            end else begin
                pipe_valid[0] <= 1'b0;
            end
            
            // Pipeline stages (if LATENCY > 1)
            for (i = 1; i < LATENCY; i = i + 1) begin
                pipe_valid[i] <= pipe_valid[i-1];
                pipe_tag[i] <= pipe_tag[i-1];
                pipe_result[i] <= pipe_result[i-1];
            end
            
            // Output stage
            if (pipe_valid[LATENCY-1]) begin
                result_valid <= 1'b1;
                result_tag <= pipe_tag[LATENCY-1];
                result_data <= pipe_result[LATENCY-1];
            end else if (result_ack) begin
                result_valid <= 1'b0;
            end
        end
    end

endmodule
