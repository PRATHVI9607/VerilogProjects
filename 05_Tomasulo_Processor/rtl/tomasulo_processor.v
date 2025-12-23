// Tomasulo Processor Top Module
// IBM 360/91 style floating-point execution

`include "tomasulo_pkg.v"

module tomasulo_processor #(
    parameter TAG_WIDTH = 4
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction interface
    input  wire        inst_valid,
    input  wire [2:0]  inst_op,
    input  wire [3:0]  inst_rs,
    input  wire [3:0]  inst_rt,
    input  wire [3:0]  inst_rd,
    input  wire [31:0] inst_imm,
    output wire        inst_ack,
    
    // Status outputs for visualization
    output wire        cdb_valid,
    output wire [TAG_WIDTH-1:0] cdb_tag,
    output wire [31:0] cdb_data,
    output wire        add_rs1_busy,
    output wire        add_rs2_busy,
    output wire        mul_rs1_busy,
    output wire        mul_rs2_busy
);

    // Register status signals
    wire [TAG_WIDTH-1:0] qi [0:15];
    wire [TAG_WIDTH-1:0] qj_issue, qk_issue;
    wire [31:0] vj_issue, vk_issue;
    
    // CDB signals
    wire cdb_valid_int;
    wire [TAG_WIDTH-1:0] cdb_tag_int;
    wire [31:0] cdb_data_int;
    
    // Adder RS signals
    wire add1_busy, add2_busy;
    wire [TAG_WIDTH-1:0] add1_tag, add2_tag;
    wire add1_ready, add2_ready;
    wire [2:0] add1_op, add2_op;
    wire [31:0] add1_vj, add1_vk, add2_vj, add2_vk;
    
    // Multiplier RS signals
    wire mul1_busy, mul2_busy;
    wire [TAG_WIDTH-1:0] mul1_tag, mul2_tag;
    wire mul1_ready, mul2_ready;
    wire [2:0] mul1_op, mul2_op;
    wire [31:0] mul1_vj, mul1_vk, mul2_vj, mul2_vk;
    
    // FU signals
    wire add_dispatch_ack, mul_dispatch_ack;
    wire add_cdb_request, mul_cdb_request;
    wire [TAG_WIDTH-1:0] add_cdb_tag, mul_cdb_tag;
    wire [31:0] add_cdb_data, mul_cdb_data;
    wire add_cdb_grant, mul_cdb_grant;
    
    // Issue logic - find free RS based on operation type
    wire is_add_op = (inst_op == `FP_ADD) || (inst_op == `FP_SUB);
    wire is_mul_op = (inst_op == `FP_MUL) || (inst_op == `FP_DIV);
    
    wire add_rs_avail = !add1_busy || !add2_busy;
    wire mul_rs_avail = !mul1_busy || !mul2_busy;
    
    wire can_issue = inst_valid && 
                    ((is_add_op && add_rs_avail) || 
                     (is_mul_op && mul_rs_avail));
    
    assign inst_ack = can_issue;
    
    // Select which RS to issue to
    wire issue_to_add1 = is_add_op && !add1_busy;
    wire issue_to_add2 = is_add_op && add1_busy && !add2_busy;
    wire issue_to_mul1 = is_mul_op && !mul1_busy;
    wire issue_to_mul2 = is_mul_op && mul1_busy && !mul2_busy;
    
    wire [TAG_WIDTH-1:0] issued_tag = issue_to_add1 ? `TAG_ADD1 :
                                      issue_to_add2 ? `TAG_ADD2 :
                                      issue_to_mul1 ? `TAG_MUL1 :
                                      issue_to_mul2 ? `TAG_MUL2 : `TAG_NONE;
    
    // Status outputs
    assign cdb_valid = cdb_valid_int;
    assign cdb_tag = cdb_tag_int;
    assign cdb_data = cdb_data_int;
    assign add_rs1_busy = add1_busy;
    assign add_rs2_busy = add2_busy;
    assign mul_rs1_busy = mul1_busy;
    assign mul_rs2_busy = mul2_busy;
    
    // Register Status Table
    register_status #(
        .NUM_REGS(16),
        .TAG_WIDTH(TAG_WIDTH)
    ) u_reg_status (
        .clk        (clk),
        .rst_n      (rst_n),
        .read_addr1 (inst_rs),
        .read_addr2 (inst_rt),
        .read_tag1  (qj_issue),
        .read_tag2  (qk_issue),
        .read_data1 (vj_issue),
        .read_data2 (vk_issue),
        .alloc_valid(can_issue),
        .alloc_rd   (inst_rd),
        .alloc_tag  (issued_tag),
        .cdb_valid  (cdb_valid_int),
        .cdb_tag    (cdb_tag_int),
        .cdb_data   (cdb_data_int),
        .qi         (qi)
    );
    
    // Adder Reservation Station 1
    tomasulo_rs #(
        .RS_ID(`TAG_ADD1),
        .TAG_WIDTH(TAG_WIDTH)
    ) u_add_rs1 (
        .clk            (clk),
        .rst_n          (rst_n),
        .issue_valid    (issue_to_add1 && can_issue),
        .issue_op       (inst_op),
        .issue_vj       (vj_issue),
        .issue_vk       (vk_issue),
        .issue_qj       (qj_issue),
        .issue_qk       (qk_issue),
        .issue_addr     (inst_imm),
        .busy           (add1_busy),
        .rs_tag         (add1_tag),
        .cdb_valid      (cdb_valid_int),
        .cdb_tag        (cdb_tag_int),
        .cdb_data       (cdb_data_int),
        .dispatch_ready (add1_ready),
        .dispatch_op    (add1_op),
        .dispatch_vj    (add1_vj),
        .dispatch_vk    (add1_vk),
        .dispatch_addr  (),
        .dispatch_ack   (add1_ready && add_dispatch_ack),
        .clear          (cdb_valid_int && (cdb_tag_int == `TAG_ADD1))
    );
    
    // Adder Reservation Station 2
    tomasulo_rs #(
        .RS_ID(`TAG_ADD2),
        .TAG_WIDTH(TAG_WIDTH)
    ) u_add_rs2 (
        .clk            (clk),
        .rst_n          (rst_n),
        .issue_valid    (issue_to_add2 && can_issue),
        .issue_op       (inst_op),
        .issue_vj       (vj_issue),
        .issue_vk       (vk_issue),
        .issue_qj       (qj_issue),
        .issue_qk       (qk_issue),
        .issue_addr     (inst_imm),
        .busy           (add2_busy),
        .rs_tag         (add2_tag),
        .cdb_valid      (cdb_valid_int),
        .cdb_tag        (cdb_tag_int),
        .cdb_data       (cdb_data_int),
        .dispatch_ready (add2_ready),
        .dispatch_op    (add2_op),
        .dispatch_vj    (add2_vj),
        .dispatch_vk    (add2_vk),
        .dispatch_addr  (),
        .dispatch_ack   (!add1_ready && add2_ready && add_dispatch_ack),
        .clear          (cdb_valid_int && (cdb_tag_int == `TAG_ADD2))
    );
    
    // Multiplier Reservation Station 1
    tomasulo_rs #(
        .RS_ID(`TAG_MUL1),
        .TAG_WIDTH(TAG_WIDTH)
    ) u_mul_rs1 (
        .clk            (clk),
        .rst_n          (rst_n),
        .issue_valid    (issue_to_mul1 && can_issue),
        .issue_op       (inst_op),
        .issue_vj       (vj_issue),
        .issue_vk       (vk_issue),
        .issue_qj       (qj_issue),
        .issue_qk       (qk_issue),
        .issue_addr     (inst_imm),
        .busy           (mul1_busy),
        .rs_tag         (mul1_tag),
        .cdb_valid      (cdb_valid_int),
        .cdb_tag        (cdb_tag_int),
        .cdb_data       (cdb_data_int),
        .dispatch_ready (mul1_ready),
        .dispatch_op    (mul1_op),
        .dispatch_vj    (mul1_vj),
        .dispatch_vk    (mul1_vk),
        .dispatch_addr  (),
        .dispatch_ack   (mul1_ready && mul_dispatch_ack),
        .clear          (cdb_valid_int && (cdb_tag_int == `TAG_MUL1))
    );
    
    // Multiplier Reservation Station 2
    tomasulo_rs #(
        .RS_ID(`TAG_MUL2),
        .TAG_WIDTH(TAG_WIDTH)
    ) u_mul_rs2 (
        .clk            (clk),
        .rst_n          (rst_n),
        .issue_valid    (issue_to_mul2 && can_issue),
        .issue_op       (inst_op),
        .issue_vj       (vj_issue),
        .issue_vk       (vk_issue),
        .issue_qj       (qj_issue),
        .issue_qk       (qk_issue),
        .issue_addr     (inst_imm),
        .busy           (mul2_busy),
        .rs_tag         (mul2_tag),
        .cdb_valid      (cdb_valid_int),
        .cdb_tag        (cdb_tag_int),
        .cdb_data       (cdb_data_int),
        .dispatch_ready (mul2_ready),
        .dispatch_op    (mul2_op),
        .dispatch_vj    (mul2_vj),
        .dispatch_vk    (mul2_vk),
        .dispatch_addr  (),
        .dispatch_ack   (!mul1_ready && mul2_ready && mul_dispatch_ack),
        .clear          (cdb_valid_int && (cdb_tag_int == `TAG_MUL2))
    );
    
    // Adder arbiter - select from ready RS
    wire add_dispatch_valid = add1_ready || add2_ready;
    wire [2:0] add_dispatch_op = add1_ready ? add1_op : add2_op;
    wire [31:0] add_dispatch_vj = add1_ready ? add1_vj : add2_vj;
    wire [31:0] add_dispatch_vk = add1_ready ? add1_vk : add2_vk;
    wire [TAG_WIDTH-1:0] add_dispatch_tag = add1_ready ? `TAG_ADD1 : `TAG_ADD2;
    
    // FP Adder Unit
    fp_adder #(
        .LATENCY(`ADD_LATENCY),
        .TAG_WIDTH(TAG_WIDTH)
    ) u_fp_adder (
        .clk            (clk),
        .rst_n          (rst_n),
        .dispatch_valid (add_dispatch_valid),
        .dispatch_op    (add_dispatch_op),
        .dispatch_vj    (add_dispatch_vj),
        .dispatch_vk    (add_dispatch_vk),
        .dispatch_tag   (add_dispatch_tag),
        .dispatch_ack   (add_dispatch_ack),
        .cdb_request    (add_cdb_request),
        .cdb_tag        (add_cdb_tag),
        .cdb_data       (add_cdb_data),
        .cdb_grant      (add_cdb_grant),
        .busy           ()
    );
    
    // Multiplier arbiter
    wire mul_dispatch_valid = mul1_ready || mul2_ready;
    wire [2:0] mul_dispatch_op = mul1_ready ? mul1_op : mul2_op;
    wire [31:0] mul_dispatch_vj = mul1_ready ? mul1_vj : mul2_vj;
    wire [31:0] mul_dispatch_vk = mul1_ready ? mul1_vk : mul2_vk;
    wire [TAG_WIDTH-1:0] mul_dispatch_tag = mul1_ready ? `TAG_MUL1 : `TAG_MUL2;
    
    // FP Multiplier Unit
    fp_multiplier #(
        .LATENCY(`MUL_LATENCY),
        .TAG_WIDTH(TAG_WIDTH)
    ) u_fp_mul (
        .clk            (clk),
        .rst_n          (rst_n),
        .dispatch_valid (mul_dispatch_valid),
        .dispatch_op    (mul_dispatch_op),
        .dispatch_vj    (mul_dispatch_vj),
        .dispatch_vk    (mul_dispatch_vk),
        .dispatch_tag   (mul_dispatch_tag),
        .dispatch_ack   (mul_dispatch_ack),
        .cdb_request    (mul_cdb_request),
        .cdb_tag        (mul_cdb_tag),
        .cdb_data       (mul_cdb_data),
        .cdb_grant      (mul_cdb_grant),
        .busy           ()
    );
    
    // Common Data Bus
    common_data_bus #(
        .TAG_WIDTH(TAG_WIDTH)
    ) u_cdb (
        .clk          (clk),
        .rst_n        (rst_n),
        .add_request  (add_cdb_request),
        .add_tag      (add_cdb_tag),
        .add_data     (add_cdb_data),
        .add_grant    (add_cdb_grant),
        .mul_request  (mul_cdb_request),
        .mul_tag      (mul_cdb_tag),
        .mul_data     (mul_cdb_data),
        .mul_grant    (mul_cdb_grant),
        .load_request (1'b0),
        .load_tag     (4'b0),
        .load_data    (32'b0),
        .load_grant   (),
        .cdb_valid    (cdb_valid_int),
        .cdb_tag      (cdb_tag_int),
        .cdb_data     (cdb_data_int),
        .grant_unit   ()
    );

endmodule
