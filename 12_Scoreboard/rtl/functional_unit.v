// Functional Unit Module
// Executes operations with variable latency

`timescale 1ns/1ps

module functional_unit #(
    parameter FU_ID = 0,
    parameter LATENCY = 1,
    parameter DATA_WIDTH = 32,
    parameter REG_BITS = 5
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Issue interface
    input  wire        issue,
    input  wire [2:0]  op,
    input  wire [REG_BITS-1:0] fi,
    input  wire [DATA_WIDTH-1:0] operand_j,
    input  wire [DATA_WIDTH-1:0] operand_k,
    
    // Execution control
    input  wire        read_done,  // Operands have been read
    output wire        exec_busy,
    output wire        exec_done,
    
    // Result
    output wire [REG_BITS-1:0] result_reg,
    output wire [DATA_WIDTH-1:0] result_data,
    output wire        result_valid
);

    // Pipeline stages for multi-cycle operations
    reg [LATENCY-1:0] busy_pipe;
    reg [DATA_WIDTH-1:0] result_pipe [0:LATENCY-1];
    reg [REG_BITS-1:0] dest_pipe [0:LATENCY-1];
    
    // Operation codes
    localparam OP_ADD = 3'd0;
    localparam OP_SUB = 3'd1;
    localparam OP_AND = 3'd2;
    localparam OP_OR  = 3'd3;
    localparam OP_XOR = 3'd4;
    localparam OP_MUL = 3'd5;
    localparam OP_DIV = 3'd6;
    
    // Compute result
    reg [DATA_WIDTH-1:0] alu_result;
    always @(*) begin
        case (op)
            OP_ADD: alu_result = operand_j + operand_k;
            OP_SUB: alu_result = operand_j - operand_k;
            OP_AND: alu_result = operand_j & operand_k;
            OP_OR:  alu_result = operand_j | operand_k;
            OP_XOR: alu_result = operand_j ^ operand_k;
            OP_MUL: alu_result = operand_j * operand_k;
            OP_DIV: alu_result = (operand_k != 0) ? operand_j / operand_k : 0;
            default: alu_result = 0;
        endcase
    end
    
    // Status
    assign exec_busy = |busy_pipe;
    assign exec_done = busy_pipe[LATENCY-1];
    
    // Result output
    assign result_reg = dest_pipe[LATENCY-1];
    assign result_data = result_pipe[LATENCY-1];
    assign result_valid = busy_pipe[LATENCY-1];
    
    // Pipeline shift
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_pipe <= 0;
            for (i = 0; i < LATENCY; i = i + 1) begin
                result_pipe[i] <= 0;
                dest_pipe[i] <= 0;
            end
        end else begin
            // Shift pipeline
            if (LATENCY > 1) begin
                for (i = LATENCY-1; i > 0; i = i - 1) begin
                    busy_pipe[i] <= busy_pipe[i-1];
                    result_pipe[i] <= result_pipe[i-1];
                    dest_pipe[i] <= dest_pipe[i-1];
                end
            end
            
            // New operation enters pipeline when operands read
            if (read_done) begin
                busy_pipe[0] <= 1'b1;
                result_pipe[0] <= alu_result;
                dest_pipe[0] <= fi;
            end else if (!issue) begin
                busy_pipe[0] <= 1'b0;
            end
            
            // Clear end of pipeline after result taken
            if (exec_done) begin
                busy_pipe[LATENCY-1] <= 1'b0;
            end
        end
    end

endmodule
