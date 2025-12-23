`timescale 1ns/1ps

// Virtual Memory Controller
// Integrates page tables, frame allocator, and replacement

module virtual_memory_controller #(
    parameter VA_WIDTH = 32,
    parameter PA_WIDTH = 32,
    parameter PAGE_SIZE = 4096,
    parameter NUM_FRAMES = 256,
    parameter PAGE_TABLE_ENTRIES = 1024
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // CPU interface
    input  wire [VA_WIDTH-1:0] virtual_addr,
    input  wire        mem_read,
    input  wire        mem_write,
    output wire [PA_WIDTH-1:0] physical_addr,
    output wire        addr_valid,
    output wire        page_fault,
    output wire        protection_fault,
    
    // Page fault handling
    output wire [VA_WIDTH-1:0] fault_addr,
    output wire [1:0]  fault_type, // 00: not present, 01: read, 10: write
    input  wire        fault_handled,
    input  wire [31:0] new_pte,
    
    // Configuration
    input  wire [1:0]  replacement_policy,
    input  wire        supervisor_mode,
    
    // Page table base
    input  wire [PA_WIDTH-1:0] page_table_base,
    
    // Statistics
    output wire [31:0] page_fault_count,
    output wire [31:0] tlb_hit_count,
    output wire [31:0] tlb_miss_count
);

    // Address breakdown (assuming 4KB pages)
    localparam PAGE_OFFSET_BITS = 12; // log2(4096)
    localparam VPN_BITS = VA_WIDTH - PAGE_OFFSET_BITS;
    localparam FRAME_BITS = $clog2(NUM_FRAMES);
    
    wire [PAGE_OFFSET_BITS-1:0] page_offset = virtual_addr[PAGE_OFFSET_BITS-1:0];
    wire [VPN_BITS-1:0] vpn = virtual_addr[VA_WIDTH-1:PAGE_OFFSET_BITS];
    
    // Two-level page table (VPN split: 10 + 10 bits for 32-bit VA)
    wire [9:0] vpn_l1 = vpn[19:10]; // Level 1 index
    wire [9:0] vpn_l0 = vpn[9:0];   // Level 0 index
    
    // State machine
    localparam IDLE = 3'd0;
    localparam TLB_LOOKUP = 3'd1;
    localparam PT_L1_READ = 3'd2;
    localparam PT_L0_READ = 3'd3;
    localparam PAGE_FAULT_STATE = 3'd4;
    localparam TLB_FILL = 3'd5;
    localparam COMPLETE = 3'd6;
    
    reg [2:0] state, next_state;
    
    // TLB (simple direct-mapped, 32 entries)
    localparam TLB_ENTRIES = 32;
    localparam TLB_INDEX_BITS = 5;
    
    reg [VPN_BITS-1:0] tlb_tag [0:TLB_ENTRIES-1];
    reg [FRAME_BITS+4-1:0] tlb_data [0:TLB_ENTRIES-1]; // PPN + flags
    reg [TLB_ENTRIES-1:0] tlb_valid;
    
    wire [TLB_INDEX_BITS-1:0] tlb_index = vpn[TLB_INDEX_BITS-1:0];
    wire tlb_hit = tlb_valid[tlb_index] && (tlb_tag[tlb_index] == vpn);
    wire [FRAME_BITS-1:0] tlb_ppn = tlb_data[tlb_index][FRAME_BITS+4-1:4];
    wire [3:0] tlb_flags = tlb_data[tlb_index][3:0]; // R, W, X, U
    
    // Page table memory interface (simplified)
    reg pt_read_req;
    reg [PA_WIDTH-1:0] pt_read_addr;
    reg [31:0] pt_read_data;
    reg pt_read_valid;
    
    // Saved request
    reg [VA_WIDTH-1:0] saved_va;
    reg saved_read, saved_write;
    
    // Page table entries
    reg [31:0] pte_l1;
    reg [31:0] pte_l0;
    
    // Fault detection
    wire pte_l1_valid = pte_l1[0];
    wire pte_l0_valid = pte_l0[0];
    wire pte_readable = pte_l0[1];
    wire pte_writable = pte_l0[2];
    wire pte_executable = pte_l0[3];
    wire pte_user = pte_l0[4];
    
    wire permission_ok = (saved_read && pte_readable) || 
                         (saved_write && pte_writable);
    wire mode_ok = supervisor_mode || pte_user;
    
    // Statistics counters
    reg [31:0] fault_counter;
    reg [31:0] hit_counter;
    reg [31:0] miss_counter;
    
    assign page_fault_count = fault_counter;
    assign tlb_hit_count = hit_counter;
    assign tlb_miss_count = miss_counter;
    
    // Frame allocator instance
    wire alloc_req;
    wire alloc_valid;
    wire [FRAME_BITS-1:0] alloc_frame;
    
    page_frame_allocator #(
        .NUM_FRAMES(NUM_FRAMES),
        .FRAME_BITS(FRAME_BITS)
    ) u_allocator (
        .clk(clk),
        .rst_n(rst_n),
        .alloc_req(alloc_req),
        .alloc_valid(alloc_valid),
        .alloc_frame(alloc_frame),
        .dealloc_req(1'b0),
        .dealloc_frame({FRAME_BITS{1'b0}}),
        .dealloc_valid(),
        .free_count(),
        .out_of_memory()
    );
    
    // Page replacement instance
    wire [FRAME_BITS-1:0] victim_frame;
    wire victim_valid;
    
    page_replacement #(
        .NUM_FRAMES(NUM_FRAMES),
        .FRAME_BITS(FRAME_BITS)
    ) u_replacement (
        .clk(clk),
        .rst_n(rst_n),
        .policy(replacement_policy),
        .frame_accessed(state == COMPLETE && tlb_hit),
        .accessed_frame(tlb_ppn),
        .frame_allocated(alloc_req && alloc_valid),
        .allocated_frame(alloc_frame),
        .select_victim(1'b0),
        .victim_frame(victim_frame),
        .victim_valid(victim_valid)
    );
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            saved_va <= 0;
            saved_read <= 0;
            saved_write <= 0;
            pte_l1 <= 0;
            pte_l0 <= 0;
            pt_read_req <= 0;
            pt_read_addr <= 0;
            pt_read_valid <= 0;
            pt_read_data <= 0;
            fault_counter <= 0;
            hit_counter <= 0;
            miss_counter <= 0;
            tlb_valid <= 0;
        end else begin
            state <= next_state;
            
            // Simulate PT read (1 cycle delay)
            pt_read_valid <= pt_read_req;
            if (pt_read_req) begin
                // Simple page table simulation
                pt_read_data <= 32'h00001007; // Valid, RWX, User
            end
            
            case (state)
                IDLE: begin
                    if (mem_read || mem_write) begin
                        saved_va <= virtual_addr;
                        saved_read <= mem_read;
                        saved_write <= mem_write;
                    end
                end
                
                TLB_LOOKUP: begin
                    if (tlb_hit) begin
                        hit_counter <= hit_counter + 1;
                    end else begin
                        miss_counter <= miss_counter + 1;
                        pt_read_req <= 1;
                        pt_read_addr <= page_table_base + (vpn_l1 << 2);
                    end
                end
                
                PT_L1_READ: begin
                    pt_read_req <= 0;
                    if (pt_read_valid) begin
                        pte_l1 <= pt_read_data;
                        if (pt_read_data[0]) begin // Valid
                            pt_read_req <= 1;
                            pt_read_addr <= {pt_read_data[31:12], 12'b0} + (vpn_l0 << 2);
                        end
                    end
                end
                
                PT_L0_READ: begin
                    pt_read_req <= 0;
                    if (pt_read_valid) begin
                        pte_l0 <= pt_read_data;
                    end
                end
                
                PAGE_FAULT_STATE: begin
                    fault_counter <= fault_counter + 1;
                    if (fault_handled) begin
                        pte_l0 <= new_pte;
                    end
                end
                
                TLB_FILL: begin
                    // Add entry to TLB
                    tlb_valid[tlb_index] <= 1'b1;
                    tlb_tag[tlb_index] <= vpn;
                    tlb_data[tlb_index] <= {pte_l0[31:12], pte_l0[4:1]};
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (mem_read || mem_write) begin
                    next_state = TLB_LOOKUP;
                end
            end
            
            TLB_LOOKUP: begin
                if (tlb_hit) begin
                    if (permission_ok && mode_ok) begin
                        next_state = COMPLETE;
                    end else begin
                        next_state = PAGE_FAULT_STATE;
                    end
                end else begin
                    next_state = PT_L1_READ;
                end
            end
            
            PT_L1_READ: begin
                if (pt_read_valid) begin
                    if (!pte_l1_valid) begin
                        next_state = PAGE_FAULT_STATE;
                    end else begin
                        next_state = PT_L0_READ;
                    end
                end
            end
            
            PT_L0_READ: begin
                if (pt_read_valid) begin
                    if (!pte_l0_valid) begin
                        next_state = PAGE_FAULT_STATE;
                    end else if (!permission_ok || !mode_ok) begin
                        next_state = PAGE_FAULT_STATE;
                    end else begin
                        next_state = TLB_FILL;
                    end
                end
            end
            
            PAGE_FAULT_STATE: begin
                if (fault_handled) begin
                    next_state = TLB_FILL;
                end
            end
            
            TLB_FILL: begin
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Output signals
    assign physical_addr = {tlb_ppn, page_offset};
    assign addr_valid = (state == COMPLETE);
    assign page_fault = (state == PAGE_FAULT_STATE);
    assign protection_fault = page_fault && (saved_read || saved_write);
    assign fault_addr = saved_va;
    assign fault_type = saved_write ? 2'b10 : 2'b01;
    
    assign alloc_req = (state == PAGE_FAULT_STATE) && fault_handled;

endmodule
