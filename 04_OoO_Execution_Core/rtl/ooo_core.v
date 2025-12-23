// Out-of-Order Execution Core - Top Module

`include "ooo_pkg.v"

module ooo_core #(
    parameter TAG_WIDTH = 4,
    parameter ROB_SIZE = 16
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction interface (from decode)
    input  wire        inst_valid,
    input  wire [2:0]  inst_op,
    input  wire [4:0]  inst_rs1,
    input  wire [4:0]  inst_rs2,
    input  wire [4:0]  inst_rd,
    input  wire [31:0] inst_pc,
    output wire        inst_ack,
    
    // Register read interface
    output wire [4:0]  reg_read_addr1,
    output wire [4:0]  reg_read_addr2,
    input  wire [31:0] reg_read_data1,
    input  wire [31:0] reg_read_data2,
    input  wire        reg_ready1,       // From RAT: operand ready
    input  wire        reg_ready2,
    input  wire [TAG_WIDTH-1:0] reg_tag1,  // From RAT: producer tag
    input  wire [TAG_WIDTH-1:0] reg_tag2,
    
    // Commit interface (to architectural register file)
    output wire        commit_valid,
    output wire [4:0]  commit_rd,
    output wire [31:0] commit_data,
    
    // Status outputs for visualization
    output wire [TAG_WIDTH-1:0] rob_head,
    output wire [TAG_WIDTH-1:0] rob_tail,
    output wire        rob_full,
    output wire [3:0]  rs_alu_busy,
    output wire [3:0]  rs_alu_ready,
    output wire        cdb_valid,
    output wire [TAG_WIDTH-1:0] cdb_tag,
    output wire [31:0] cdb_data
);

    // Register read
    assign reg_read_addr1 = inst_rs1;
    assign reg_read_addr2 = inst_rs2;
    
    // ROB signals
    wire [TAG_WIDTH-1:0] rob_alloc_tag;
    wire rob_alloc_ack;
    wire rob_commit_valid;
    wire [4:0] rob_commit_rd;
    wire [31:0] rob_commit_data;
    wire [TAG_WIDTH-1:0] rob_commit_tag;
    
    // RS signals
    wire rs_issue_ack;
    wire rs_full;
    wire rs_dispatch_valid;
    wire [2:0] rs_dispatch_op;
    wire [31:0] rs_dispatch_val1;
    wire [31:0] rs_dispatch_val2;
    wire [TAG_WIDTH-1:0] rs_dispatch_tag;
    
    // ALU signals
    wire alu_dispatch_ack;
    wire alu_result_valid;
    wire [TAG_WIDTH-1:0] alu_result_tag;
    wire [31:0] alu_result_data;
    wire alu_busy;
    
    // CDB signals (directly from ALU for now)
    wire cdb_valid_int;
    wire [TAG_WIDTH-1:0] cdb_tag_int;
    wire [31:0] cdb_data_int;
    
    // For simplicity, use ALU result directly as CDB
    assign cdb_valid_int = alu_result_valid;
    assign cdb_tag_int = alu_result_tag;
    assign cdb_data_int = alu_result_data;
    
    // Status outputs
    assign cdb_valid = cdb_valid_int;
    assign cdb_tag = cdb_tag_int;
    assign cdb_data = cdb_data_int;
    assign commit_valid = rob_commit_valid;
    assign commit_rd = rob_commit_rd;
    assign commit_data = rob_commit_data;
    
    // Issue acknowledge (both ROB and RS must accept)
    assign inst_ack = inst_valid && rob_alloc_ack && rs_issue_ack;
    
    // Reorder Buffer
    reorder_buffer #(
        .ROB_SIZE(ROB_SIZE),
        .TAG_WIDTH(TAG_WIDTH)
    ) u_rob (
        .clk              (clk),
        .rst_n            (rst_n),
        .alloc_valid      (inst_valid && !rs_full),
        .alloc_rd         (inst_rd),
        .alloc_pc         (inst_pc),
        .alloc_tag        (rob_alloc_tag),
        .alloc_ack        (rob_alloc_ack),
        .rob_full         (rob_full),
        .complete_valid   (cdb_valid_int),
        .complete_tag     (cdb_tag_int),
        .complete_data    (cdb_data_int),
        .complete_exception(1'b0),
        .commit_valid     (rob_commit_valid),
        .commit_rd        (rob_commit_rd),
        .commit_data      (rob_commit_data),
        .commit_tag       (rob_commit_tag),
        .commit_exception (),
        .head_ptr         (rob_head),
        .tail_ptr         (rob_tail),
        .rob_count        ()
    );
    
    // Reservation Station (ALU)
    reservation_station #(
        .NUM_ENTRIES(4),
        .TAG_WIDTH(TAG_WIDTH)
    ) u_rs_alu (
        .clk              (clk),
        .rst_n            (rst_n),
        .issue_valid      (inst_valid && !rob_full),
        .issue_op         (inst_op),
        .issue_val1       (reg_read_data1),
        .issue_val2       (reg_read_data2),
        .issue_tag1       (reg_tag1),
        .issue_tag2       (reg_tag2),
        .issue_ready1     (reg_ready1),
        .issue_ready2     (reg_ready2),
        .issue_dest_tag   (rob_alloc_tag),
        .issue_ack        (rs_issue_ack),
        .rs_full          (rs_full),
        .cdb_valid        (cdb_valid_int),
        .cdb_tag          (cdb_tag_int),
        .cdb_data         (cdb_data_int),
        .dispatch_valid   (rs_dispatch_valid),
        .dispatch_op      (rs_dispatch_op),
        .dispatch_val1    (rs_dispatch_val1),
        .dispatch_val2    (rs_dispatch_val2),
        .dispatch_dest_tag(rs_dispatch_tag),
        .dispatch_ack     (alu_dispatch_ack),
        .entry_busy       (rs_alu_busy),
        .entry_ready      (rs_alu_ready)
    );
    
    // ALU Execution Unit
    alu_unit #(
        .TAG_WIDTH(TAG_WIDTH),
        .LATENCY(1)
    ) u_alu (
        .clk              (clk),
        .rst_n            (rst_n),
        .dispatch_valid   (rs_dispatch_valid),
        .dispatch_op      (rs_dispatch_op),
        .dispatch_val1    (rs_dispatch_val1),
        .dispatch_val2    (rs_dispatch_val2),
        .dispatch_tag     (rs_dispatch_tag),
        .dispatch_ack     (alu_dispatch_ack),
        .result_valid     (alu_result_valid),
        .result_tag       (alu_result_tag),
        .result_data      (alu_result_data),
        .result_ack       (1'b1),  // Always accept
        .busy             (alu_busy)
    );

endmodule
