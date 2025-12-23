// Tomasulo Reservation Station
// CAM-based tag matching for operand wakeup

`include "tomasulo_pkg.v"

module tomasulo_rs #(
    parameter RS_ID = 1,          // Unique RS identifier/tag
    parameter TAG_WIDTH = 4
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Issue interface
    input  wire        issue_valid,
    input  wire [2:0]  issue_op,
    input  wire [31:0] issue_vj,      // Value of source 1
    input  wire [31:0] issue_vk,      // Value of source 2
    input  wire [TAG_WIDTH-1:0] issue_qj,  // Tag of source 1 (0 if ready)
    input  wire [TAG_WIDTH-1:0] issue_qk,  // Tag of source 2 (0 if ready)
    input  wire [31:0] issue_addr,    // Address for load/store
    output wire        busy,
    output wire [TAG_WIDTH-1:0] rs_tag,
    
    // CDB broadcast (for wakeup)
    input  wire        cdb_valid,
    input  wire [TAG_WIDTH-1:0] cdb_tag,
    input  wire [31:0] cdb_data,
    
    // Dispatch to FU
    output wire        dispatch_ready,
    output wire [2:0]  dispatch_op,
    output wire [31:0] dispatch_vj,
    output wire [31:0] dispatch_vk,
    output wire [31:0] dispatch_addr,
    input  wire        dispatch_ack,
    
    // Clear (when result written to CDB)
    input  wire        clear
);

    // RS storage
    reg                  rs_busy;
    reg [2:0]            rs_op;
    reg [31:0]           rs_vj;
    reg [31:0]           rs_vk;
    reg [TAG_WIDTH-1:0]  rs_qj;
    reg [TAG_WIDTH-1:0]  rs_qk;
    reg [31:0]           rs_addr;
    
    // Status
    assign busy = rs_busy;
    assign rs_tag = RS_ID;
    
    // Ready when both operands available (tags = 0)
    wire operands_ready = (rs_qj == `TAG_NONE) && (rs_qk == `TAG_NONE);
    assign dispatch_ready = rs_busy && operands_ready;
    
    // Dispatch outputs
    assign dispatch_op = rs_op;
    assign dispatch_vj = rs_vj;
    assign dispatch_vk = rs_vk;
    assign dispatch_addr = rs_addr;
    
    // RS logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rs_busy <= 1'b0;
            rs_op   <= 3'b0;
            rs_vj   <= 32'b0;
            rs_vk   <= 32'b0;
            rs_qj   <= `TAG_NONE;
            rs_qk   <= `TAG_NONE;
            rs_addr <= 32'b0;
        end else begin
            // Clear RS when result broadcast
            if (clear) begin
                rs_busy <= 1'b0;
            end
            // Issue new instruction
            else if (issue_valid && !rs_busy) begin
                rs_busy <= 1'b1;
                rs_op   <= issue_op;
                rs_vj   <= issue_vj;
                rs_vk   <= issue_vk;
                rs_qj   <= issue_qj;
                rs_qk   <= issue_qk;
                rs_addr <= issue_addr;
            end
            
            // CDB wakeup - CAM match on tags
            if (cdb_valid && rs_busy) begin
                if (rs_qj == cdb_tag && rs_qj != `TAG_NONE) begin
                    rs_vj <= cdb_data;
                    rs_qj <= `TAG_NONE;
                end
                if (rs_qk == cdb_tag && rs_qk != `TAG_NONE) begin
                    rs_vk <= cdb_data;
                    rs_qk <= `TAG_NONE;
                end
            end
        end
    end

endmodule
