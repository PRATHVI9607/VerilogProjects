`timescale 1ns/1ps

// Superscalar Dual-Issue CPU - Register Rename Unit
// Maps architectural to physical registers, handles WAW hazards

module register_rename #(
    parameter ARCH_REGS = 32,
    parameter PHYS_REGS = 64,
    parameter TAG_WIDTH = 6
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Rename request (from decode) - 2 instructions
    input  wire        rename_valid_0,
    input  wire [4:0]  rename_rs1_0,
    input  wire [4:0]  rename_rs2_0,
    input  wire [4:0]  rename_rd_0,
    input  wire        has_rd_0,
    
    input  wire        rename_valid_1,
    input  wire [4:0]  rename_rs1_1,
    input  wire [4:0]  rename_rs2_1,
    input  wire [4:0]  rename_rd_1,
    input  wire        has_rd_1,
    
    // Renamed outputs
    output wire [TAG_WIDTH-1:0] phys_rs1_0,
    output wire [TAG_WIDTH-1:0] phys_rs2_0,
    output wire [TAG_WIDTH-1:0] phys_rd_0,
    output wire                  rename_ack_0,
    
    output wire [TAG_WIDTH-1:0] phys_rs1_1,
    output wire [TAG_WIDTH-1:0] phys_rs2_1,
    output wire [TAG_WIDTH-1:0] phys_rd_1,
    output wire                  rename_ack_1,
    
    // Free physical register (from commit)
    input  wire        free_valid,
    input  wire [TAG_WIDTH-1:0] free_preg,
    
    // Commit (update committed RAT)
    input  wire        commit_valid_0,
    input  wire [4:0]  commit_rd_0,
    input  wire [TAG_WIDTH-1:0] commit_preg_0,
    
    input  wire        commit_valid_1,
    input  wire [4:0]  commit_rd_1,
    input  wire [TAG_WIDTH-1:0] commit_preg_1,
    
    // Status
    output wire        freelist_empty
);

    // Register Alias Table (RAT) - maps arch to phys
    reg [TAG_WIDTH-1:0] rat [0:ARCH_REGS-1];
    
    // Committed RAT (for recovery)
    reg [TAG_WIDTH-1:0] c_rat [0:ARCH_REGS-1];
    
    // Free list (circular buffer of available physical registers)
    reg [TAG_WIDTH-1:0] freelist [0:PHYS_REGS-1];
    reg [$clog2(PHYS_REGS):0] fl_head, fl_tail, fl_count;
    
    // Free list status
    wire fl_empty = (fl_count == 0);
    wire fl_has_two = (fl_count >= 2);
    assign freelist_empty = fl_empty;
    
    // Check dependencies between two instructions
    wire rd0_rs1_1_dep = has_rd_0 && (rename_rd_0 == rename_rs1_1) && (rename_rd_0 != 0);
    wire rd0_rs2_1_dep = has_rd_0 && (rename_rd_0 == rename_rs2_1) && (rename_rd_0 != 0);
    
    // Allocate from free list
    wire [TAG_WIDTH-1:0] new_preg_0 = freelist[fl_head];
    wire [TAG_WIDTH-1:0] new_preg_1 = freelist[(fl_head + 1) % PHYS_REGS];
    
    // Renamed source registers
    assign phys_rs1_0 = (rename_rs1_0 == 0) ? 0 : rat[rename_rs1_0];
    assign phys_rs2_0 = (rename_rs2_0 == 0) ? 0 : rat[rename_rs2_0];
    assign phys_rd_0  = new_preg_0;
    
    // Second instruction may depend on first
    assign phys_rs1_1 = (rename_rs1_1 == 0) ? 0 :
                        rd0_rs1_1_dep ? new_preg_0 : rat[rename_rs1_1];
    assign phys_rs2_1 = (rename_rs2_1 == 0) ? 0 :
                        rd0_rs2_1_dep ? new_preg_0 : rat[rename_rs2_1];
    assign phys_rd_1  = new_preg_1;
    
    // Can rename if free list has space
    assign rename_ack_0 = rename_valid_0 && (!has_rd_0 || !fl_empty);
    assign rename_ack_1 = rename_valid_1 && rename_ack_0 && 
                         (!has_rd_1 || (has_rd_0 ? fl_has_two : !fl_empty));
    
    integer i;
    
    // Initialize
    initial begin
        // Identity mapping initially
        for (i = 0; i < ARCH_REGS; i = i + 1) begin
            rat[i] = i;
            c_rat[i] = i;
        end
        // Free list contains P32-P63
        fl_head = 0;
        fl_tail = PHYS_REGS - ARCH_REGS;
        fl_count = PHYS_REGS - ARCH_REGS;
        for (i = 0; i < PHYS_REGS - ARCH_REGS; i = i + 1) begin
            freelist[i] = ARCH_REGS + i;
        end
    end
    
    // Update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fl_head <= 0;
            fl_tail <= PHYS_REGS - ARCH_REGS;
            fl_count <= PHYS_REGS - ARCH_REGS;
            for (i = 0; i < ARCH_REGS; i = i + 1) begin
                rat[i] <= i;
                c_rat[i] <= i;
            end
        end else begin
            // Rename instruction 0
            if (rename_ack_0 && has_rd_0 && rename_rd_0 != 0) begin
                rat[rename_rd_0] <= new_preg_0;
                fl_head <= (fl_head + 1) % PHYS_REGS;
                fl_count <= fl_count - 1;
            end
            
            // Rename instruction 1
            if (rename_ack_1 && has_rd_1 && rename_rd_1 != 0) begin
                rat[rename_rd_1] <= new_preg_1;
                fl_head <= has_rd_0 ? (fl_head + 2) % PHYS_REGS : (fl_head + 1) % PHYS_REGS;
                fl_count <= has_rd_0 ? fl_count - 2 : fl_count - 1;
            end
            
            // Free physical register
            if (free_valid) begin
                freelist[fl_tail] <= free_preg;
                fl_tail <= (fl_tail + 1) % PHYS_REGS;
                fl_count <= fl_count + 1;
            end
            
            // Adjust count for simultaneous alloc/free
            if ((rename_ack_0 && has_rd_0 && rename_rd_0 != 0) && free_valid) begin
                fl_count <= fl_count;
            end
            
            // Update committed RAT
            if (commit_valid_0 && commit_rd_0 != 0) begin
                c_rat[commit_rd_0] <= commit_preg_0;
            end
            if (commit_valid_1 && commit_rd_1 != 0) begin
                c_rat[commit_rd_1] <= commit_preg_1;
            end
        end
    end

endmodule
