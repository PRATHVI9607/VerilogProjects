`timescale 1ns/1ps

// Page Table Walker (PTW)
// Sv32 style 2-level page table walker

module page_table_walker #(
    parameter VPN_WIDTH = 20,
    parameter PPN_WIDTH = 20,
    parameter ASID_WIDTH = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Request interface (from TLB miss)
    input  wire        ptw_request,
    input  wire [VPN_WIDTH-1:0] vpn,
    input  wire [ASID_WIDTH-1:0] asid,
    output wire        ptw_done,
    output wire        ptw_fault,
    output wire [1:0]  fault_type, // 00: none, 01: page fault, 10: access fault
    
    // Result interface (to TLB refill)
    output wire [PPN_WIDTH-1:0] result_ppn,
    output wire [3:0]  result_flags,
    output wire        result_global,
    
    // Memory interface (to access page tables in memory)
    output wire        mem_req_valid,
    output wire [31:0] mem_req_addr,
    input  wire        mem_resp_valid,
    input  wire [31:0] mem_resp_data,
    
    // SATP register (supervisor address translation and protection)
    input  wire [31:0] satp, // [31]: mode, [30:22]: ASID, [21:0]: PPN of root PT
    input  wire        satp_valid,
    
    // Status
    output wire [2:0]  ptw_state
);

    // PTW states
    localparam IDLE         = 3'd0;
    localparam LEVEL1_REQ   = 3'd1;
    localparam LEVEL1_WAIT  = 3'd2;
    localparam LEVEL0_REQ   = 3'd3;
    localparam LEVEL0_WAIT  = 3'd4;
    localparam DONE         = 3'd5;
    localparam FAULT        = 3'd6;
    
    reg [2:0] state, next_state;
    
    // Page Table Entry (PTE) format (Sv32)
    // [31:10] PPN, [9:8] RSW, [7] D, [6] A, [5] G, [4] U, [3] X, [2] W, [1] R, [0] V
    wire [31:0] pte = mem_resp_data;
    wire pte_valid  = pte[0];
    wire pte_read   = pte[1];
    wire pte_write  = pte[2];
    wire pte_exec   = pte[3];
    wire pte_user   = pte[4];
    wire pte_global = pte[5];
    wire pte_access = pte[6];
    wire pte_dirty  = pte[7];
    wire [21:0] pte_ppn = pte[31:10];
    
    // Is this a leaf PTE (has R, W, or X set)?
    wire pte_leaf = pte_read | pte_write | pte_exec;
    
    // VPN breakdown
    wire [9:0] vpn_1 = vpn[19:10]; // Level 1 index
    wire [9:0] vpn_0 = vpn[9:0];   // Level 0 index
    
    // Saved values
    reg [VPN_WIDTH-1:0] saved_vpn;
    reg [ASID_WIDTH-1:0] saved_asid;
    reg [21:0] saved_ppn;
    reg [31:0] saved_pte;
    
    // SATP fields
    wire satp_mode = satp[31];
    wire [21:0] satp_ppn = satp[21:0];
    
    // Address calculation
    reg [31:0] pt_addr;
    
    always @(*) begin
        case (state)
            LEVEL1_REQ, LEVEL1_WAIT: 
                pt_addr = {satp_ppn[19:0], 12'b0} + {vpn_1, 2'b0}; // PPN * 4KB + VPN[1] * 4
            LEVEL0_REQ, LEVEL0_WAIT: 
                pt_addr = {saved_ppn[19:0], 12'b0} + {vpn_0, 2'b0}; // Next level PPN * 4KB + VPN[0] * 4
            default: 
                pt_addr = 32'b0;
        endcase
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (ptw_request && satp_valid && satp_mode) begin
                    next_state = LEVEL1_REQ;
                end else if (ptw_request && (!satp_valid || !satp_mode)) begin
                    next_state = FAULT; // No translation enabled
                end
            end
            
            LEVEL1_REQ: begin
                next_state = LEVEL1_WAIT;
            end
            
            LEVEL1_WAIT: begin
                if (mem_resp_valid) begin
                    if (!pte_valid) begin
                        next_state = FAULT; // Invalid PTE
                    end else if (pte_leaf) begin
                        // Superpage (misaligned check)
                        if (pte_ppn[9:0] != 10'b0) begin
                            next_state = FAULT; // Misaligned superpage
                        end else begin
                            next_state = DONE;
                        end
                    end else begin
                        next_state = LEVEL0_REQ; // Go to next level
                    end
                end
            end
            
            LEVEL0_REQ: begin
                next_state = LEVEL0_WAIT;
            end
            
            LEVEL0_WAIT: begin
                if (mem_resp_valid) begin
                    if (!pte_valid || !pte_leaf) begin
                        next_state = FAULT; // Invalid or non-leaf at level 0
                    end else begin
                        next_state = DONE;
                    end
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            FAULT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Save VPN and intermediate results
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saved_vpn <= 0;
            saved_asid <= 0;
            saved_ppn <= 0;
            saved_pte <= 0;
        end else begin
            if (state == IDLE && ptw_request) begin
                saved_vpn <= vpn;
                saved_asid <= asid;
            end
            if (state == LEVEL1_WAIT && mem_resp_valid && pte_valid && !pte_leaf) begin
                saved_ppn <= pte_ppn;
            end
            if ((state == LEVEL1_WAIT || state == LEVEL0_WAIT) && mem_resp_valid) begin
                saved_pte <= pte;
            end
        end
    end
    
    // Memory request
    assign mem_req_valid = (state == LEVEL1_REQ) || (state == LEVEL0_REQ);
    assign mem_req_addr = pt_addr;
    
    // Results
    assign ptw_done = (state == DONE);
    assign ptw_fault = (state == FAULT);
    assign fault_type = (state == FAULT) ? 2'b01 : 2'b00; // Page fault
    
    // Extract final PPN based on page level
    wire is_superpage = (state == DONE) && (saved_pte[1] || saved_pte[2] || saved_pte[3]) && 
                        (saved_vpn == saved_vpn); // Check if we finished at level 1
    
    assign result_ppn = saved_pte[31:12]; // PPN from saved PTE
    assign result_flags = {saved_pte[4], saved_pte[3], saved_pte[2], saved_pte[1]}; // U, X, W, R
    assign result_global = saved_pte[5];
    
    assign ptw_state = state;

endmodule
