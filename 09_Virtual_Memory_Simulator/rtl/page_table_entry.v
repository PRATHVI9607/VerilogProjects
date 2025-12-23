`timescale 1ns/1ps

// Page Table Entry Module
// Supports multi-level page table structure

module page_table_entry #(
    parameter PPN_WIDTH = 22,
    parameter FLAGS_WIDTH = 10
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Entry data
    output wire [PPN_WIDTH-1:0] ppn,
    output wire        valid,
    output wire        readable,
    output wire        writable,
    output wire        executable,
    output wire        user_mode,
    output wire        global_page,
    output wire        accessed,
    output wire        dirty,
    output wire        is_leaf,
    
    // Write interface
    input  wire        write_en,
    input  wire [31:0] write_data,
    
    // Update flags (for A/D bits)
    input  wire        set_accessed,
    input  wire        set_dirty,
    
    // Raw entry output
    output wire [31:0] entry_raw
);

    // PTE format (RISC-V Sv32/Sv39 style)
    // [31:10] PPN
    // [9:8] RSW (reserved for software)
    // [7] D - Dirty
    // [6] A - Accessed
    // [5] G - Global
    // [4] U - User
    // [3] X - Execute
    // [2] W - Write
    // [1] R - Read
    // [0] V - Valid
    
    reg [31:0] pte_reg;
    
    // Extract fields
    assign ppn = pte_reg[31:10];
    assign dirty = pte_reg[7];
    assign accessed = pte_reg[6];
    assign global_page = pte_reg[5];
    assign user_mode = pte_reg[4];
    assign executable = pte_reg[3];
    assign writable = pte_reg[2];
    assign readable = pte_reg[1];
    assign valid = pte_reg[0];
    
    // Leaf page detection (has R, W, or X permission)
    assign is_leaf = readable | writable | executable;
    
    assign entry_raw = pte_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pte_reg <= 32'b0;
        end else begin
            if (write_en) begin
                pte_reg <= write_data;
            end else begin
                // Update A/D bits
                if (set_accessed) begin
                    pte_reg[6] <= 1'b1;
                end
                if (set_dirty) begin
                    pte_reg[7] <= 1'b1;
                end
            end
        end
    end

endmodule
