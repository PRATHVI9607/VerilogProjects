// CDC 6600 Style Scoreboard - Top Level
// Implements complete scoreboard mechanism for out-of-order execution

`timescale 1ns/1ps

module scoreboard #(
    parameter DATA_WIDTH = 32,
    parameter NUM_FUS = 4,
    parameter NUM_REGS = 32,
    parameter REG_BITS = 5,
    parameter FU_BITS = 2
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction interface
    input  wire        inst_valid,
    input  wire [2:0]  inst_op,
    input  wire [REG_BITS-1:0] inst_fi,  // Destination register
    input  wire [REG_BITS-1:0] inst_fj,  // Source register 1
    input  wire [REG_BITS-1:0] inst_fk,  // Source register 2
    input  wire [1:0]  inst_fu_type,     // FU type required
    
    // Status outputs
    output wire        stall,
    output wire [NUM_FUS-1:0] fu_busy,
    output wire        issue_ok,
    
    // Debug outputs
    output wire [3:0]  state
);

    // =========================================================================
    // Internal signals
    // =========================================================================
    
    // FU Status Table signals
    wire [NUM_FUS-1:0] busy_out;
    wire [NUM_FUS-1:0] rj_out;
    wire [NUM_FUS-1:0] rk_out;
    wire [NUM_REGS*NUM_FUS-1:0] reg_result_fu;
    
    // Issue logic signals
    wire can_issue;
    wire [FU_BITS-1:0] issue_fu;
    wire issue_waw_hazard;
    wire issue_structural_hazard;
    
    // Scoreboard control
    reg issue_grant_reg;
    reg [NUM_FUS-1:0] read_grant;
    reg [NUM_FUS-1:0] write_grant;
    
    // Register file signals
    wire rf_write_en;
    wire [REG_BITS-1:0] rf_write_addr;
    wire [DATA_WIDTH-1:0] rf_write_data;
    
    // FU signals
    wire [NUM_FUS-1:0] fu_exec_busy;
    wire [NUM_FUS-1:0] fu_exec_done;
    wire [REG_BITS-1:0] fu_result_reg [0:NUM_FUS-1];
    wire [DATA_WIDTH-1:0] fu_result_data [0:NUM_FUS-1];
    wire [NUM_FUS-1:0] fu_result_valid;
    
    // =========================================================================
    // Scoreboard State Machine
    // =========================================================================
    
    localparam S_IDLE = 4'd0;
    localparam S_ISSUE = 4'd1;
    localparam S_READ = 4'd2;
    localparam S_EXEC = 4'd3;
    localparam S_WRITE = 4'd4;
    
    reg [3:0] sb_state;
    assign state = sb_state;
    
    // =========================================================================
    // FU Status Table
    // =========================================================================
    
    fu_status #(
        .NUM_FUS(NUM_FUS),
        .NUM_REGS(NUM_REGS),
        .REG_BITS(REG_BITS),
        .FU_BITS(FU_BITS)
    ) fu_status_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Issue interface
        .issue_grant(issue_grant_reg),
        .issue_fu(issue_fu),
        .issue_op(inst_op),
        .issue_fi(inst_fi),
        .issue_fj(inst_fj),
        .issue_fk(inst_fk),
        
        // Read operands interface
        .read_grant(read_grant),
        
        // Write result interface
        .write_grant(write_grant),
        
        // Status outputs
        .busy(busy_out),
        .rj(rj_out),
        .rk(rk_out),
        .reg_result_fu(reg_result_fu)
    );
    
    // =========================================================================
    // Issue Logic
    // =========================================================================
    
    scoreboard_issue #(
        .NUM_FUS(NUM_FUS),
        .NUM_REGS(NUM_REGS),
        .REG_BITS(REG_BITS),
        .FU_BITS(FU_BITS)
    ) issue_logic (
        .clk(clk),
        .rst_n(rst_n),
        
        // Instruction
        .inst_valid(inst_valid),
        .inst_fi(inst_fi),
        .inst_fu_type(inst_fu_type),
        
        // FU status
        .fu_busy(busy_out),
        .reg_result_fu(reg_result_fu),
        
        // Outputs
        .can_issue(can_issue),
        .selected_fu(issue_fu),
        .waw_hazard(issue_waw_hazard),
        .structural_hazard(issue_structural_hazard)
    );
    
    // =========================================================================
    // Register File
    // =========================================================================
    
    // Shared register file
    reg [REG_BITS-1:0] rf_read_addr1, rf_read_addr2;
    wire [DATA_WIDTH-1:0] rf_read_data1, rf_read_data2;
    
    register_file #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_REGS(NUM_REGS),
        .REG_BITS(REG_BITS)
    ) regfile (
        .clk(clk),
        .rst_n(rst_n),
        .read_addr1(rf_read_addr1),
        .read_data1(rf_read_data1),
        .read_addr2(rf_read_addr2),
        .read_data2(rf_read_data2),
        .write_en(rf_write_en),
        .write_addr(rf_write_addr),
        .write_data(rf_write_data)
    );
    
    // =========================================================================
    // Functional Units
    // =========================================================================
    
    // ALU 0 (1 cycle latency)
    functional_unit #(
        .FU_ID(0),
        .LATENCY(1),
        .DATA_WIDTH(DATA_WIDTH),
        .REG_BITS(REG_BITS)
    ) fu_alu0 (
        .clk(clk),
        .rst_n(rst_n),
        .issue(issue_grant_reg && issue_fu == 0),
        .op(inst_op),
        .fi(inst_fi),
        .operand_j(rf_read_data1),
        .operand_k(rf_read_data2),
        .read_done(read_grant[0]),
        .exec_busy(fu_exec_busy[0]),
        .exec_done(fu_exec_done[0]),
        .result_reg(fu_result_reg[0]),
        .result_data(fu_result_data[0]),
        .result_valid(fu_result_valid[0])
    );
    
    // ALU 1 (1 cycle latency)
    functional_unit #(
        .FU_ID(1),
        .LATENCY(1),
        .DATA_WIDTH(DATA_WIDTH),
        .REG_BITS(REG_BITS)
    ) fu_alu1 (
        .clk(clk),
        .rst_n(rst_n),
        .issue(issue_grant_reg && issue_fu == 1),
        .op(inst_op),
        .fi(inst_fi),
        .operand_j(rf_read_data1),
        .operand_k(rf_read_data2),
        .read_done(read_grant[1]),
        .exec_busy(fu_exec_busy[1]),
        .exec_done(fu_exec_done[1]),
        .result_reg(fu_result_reg[1]),
        .result_data(fu_result_data[1]),
        .result_valid(fu_result_valid[1])
    );
    
    // Multiplier (3 cycle latency)
    functional_unit #(
        .FU_ID(2),
        .LATENCY(3),
        .DATA_WIDTH(DATA_WIDTH),
        .REG_BITS(REG_BITS)
    ) fu_mul (
        .clk(clk),
        .rst_n(rst_n),
        .issue(issue_grant_reg && issue_fu == 2),
        .op(3'd5), // MUL op
        .fi(inst_fi),
        .operand_j(rf_read_data1),
        .operand_k(rf_read_data2),
        .read_done(read_grant[2]),
        .exec_busy(fu_exec_busy[2]),
        .exec_done(fu_exec_done[2]),
        .result_reg(fu_result_reg[2]),
        .result_data(fu_result_data[2]),
        .result_valid(fu_result_valid[2])
    );
    
    // Divider (8 cycle latency)
    functional_unit #(
        .FU_ID(3),
        .LATENCY(8),
        .DATA_WIDTH(DATA_WIDTH),
        .REG_BITS(REG_BITS)
    ) fu_div (
        .clk(clk),
        .rst_n(rst_n),
        .issue(issue_grant_reg && issue_fu == 3),
        .op(3'd6), // DIV op
        .fi(inst_fi),
        .operand_j(rf_read_data1),
        .operand_k(rf_read_data2),
        .read_done(read_grant[3]),
        .exec_busy(fu_exec_busy[3]),
        .exec_done(fu_exec_done[3]),
        .result_reg(fu_result_reg[3]),
        .result_data(fu_result_data[3]),
        .result_valid(fu_result_valid[3])
    );
    
    // =========================================================================
    // Write Arbitration
    // =========================================================================
    
    reg [FU_BITS-1:0] write_fu;
    reg write_pending;
    
    // Priority encoder for write
    always @(*) begin
        write_fu = 0;
        write_pending = 0;
        if (fu_result_valid[0]) begin
            write_fu = 2'd0;
            write_pending = 1;
        end else if (fu_result_valid[1]) begin
            write_fu = 2'd1;
            write_pending = 1;
        end else if (fu_result_valid[2]) begin
            write_fu = 2'd2;
            write_pending = 1;
        end else if (fu_result_valid[3]) begin
            write_fu = 2'd3;
            write_pending = 1;
        end
    end
    
    assign rf_write_en = write_pending && write_grant[write_fu];
    assign rf_write_addr = fu_result_reg[write_fu];
    assign rf_write_data = fu_result_data[write_fu];
    
    // =========================================================================
    // Scoreboard Control Logic
    // =========================================================================
    
    // Issue/Stall logic
    assign issue_ok = can_issue;
    assign stall = inst_valid && !can_issue;
    assign fu_busy = busy_out;
    
    // Main state machine and control
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sb_state <= S_IDLE;
            issue_grant_reg <= 0;
            read_grant <= 0;
            write_grant <= 0;
            rf_read_addr1 <= 0;
            rf_read_addr2 <= 0;
        end else begin
            // Default
            issue_grant_reg <= 0;
            read_grant <= 0;
            write_grant <= 0;
            
            // Issue stage - issue instruction if possible
            if (inst_valid && can_issue) begin
                issue_grant_reg <= 1;
                rf_read_addr1 <= inst_fj;
                rf_read_addr2 <= inst_fk;
            end
            
            // Read stage - read operands when ready
            // Rj=1 and Rk=1 means operands are ready
            for (i = 0; i < NUM_FUS; i = i + 1) begin
                if (busy_out[i] && rj_out[i] && rk_out[i]) begin
                    read_grant[i] <= 1;
                end
            end
            
            // Write stage - write results back
            if (write_pending) begin
                write_grant[write_fu] <= 1;
            end
        end
    end

endmodule
