// Scoreboard Issue Logic
// Handles instruction issue with hazard detection

`timescale 1ns/1ps

module scoreboard_issue #(
    parameter NUM_FUS = 4,
    parameter NUM_REGS = 32,
    parameter REG_BITS = 5,
    parameter FU_BITS = 2
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction input
    input  wire        inst_valid,
    input  wire [REG_BITS-1:0] inst_fi,
    input  wire [1:0]  inst_fu_type,  // Which FU type can execute
    
    // Functional unit status
    input  wire [NUM_FUS-1:0] fu_busy,
    input  wire [NUM_REGS*NUM_FUS-1:0] reg_result_fu,
    
    // Issue output
    output wire        can_issue,
    output wire [FU_BITS-1:0] selected_fu,
    output wire        waw_hazard,
    output wire        structural_hazard
);

    // FU type to FU mapping
    // Type 0: Integer ALU (FU 0, 1)
    // Type 1: Reserved
    // Type 2: Multiplier (FU 2)
    // Type 3: Divider (FU 3)
    reg [NUM_FUS-1:0] fu_type_mask;
    always @(*) begin
        case (inst_fu_type)
            2'd0: fu_type_mask = 4'b0011;  // ALUs
            2'd1: fu_type_mask = 4'b0011;  // Also ALUs
            2'd2: fu_type_mask = 4'b0100;  // Multiplier
            2'd3: fu_type_mask = 4'b1000;  // Divider
            default: fu_type_mask = 4'b0000;
        endcase
    end
    
    // Find available FU of required type
    wire [NUM_FUS-1:0] fu_available = fu_type_mask & ~fu_busy;
    wire any_fu_available = |fu_available;
    
    // WAW hazard check: is another FU writing to our destination?
    wire [NUM_FUS-1:0] dest_conflict = reg_result_fu[inst_fi*NUM_FUS +: NUM_FUS];
    assign waw_hazard = |dest_conflict && (inst_fi != 0);
    
    // Structural hazard: no FU available
    assign structural_hazard = !any_fu_available;
    
    // Issue condition
    assign can_issue = inst_valid && !structural_hazard && !waw_hazard;
    
    // Select FU (priority encode available FUs)
    reg [FU_BITS-1:0] sel_fu;
    integer i;
    always @(*) begin
        sel_fu = 0;
        for (i = NUM_FUS-1; i >= 0; i = i - 1) begin
            if (fu_available[i]) begin
                sel_fu = i[FU_BITS-1:0];
            end
        end
    end
    
    assign selected_fu = sel_fu;

endmodule
