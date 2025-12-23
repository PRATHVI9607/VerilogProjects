`timescale 1ns/1ps

// Translation Lookaside Buffer (TLB)
// Fully associative TLB with 16 entries

module tlb #(
    parameter NUM_ENTRIES = 16,
    parameter VPN_WIDTH = 20,
    parameter PPN_WIDTH = 20,
    parameter ASID_WIDTH = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Lookup interface
    input  wire [31:0] virtual_addr,
    input  wire [ASID_WIDTH-1:0] asid,
    input  wire        lookup_valid,
    output wire        tlb_hit,
    output wire [31:0] physical_addr,
    output wire [3:0]  page_flags,
    
    // Refill interface (from page table walker)
    input  wire        refill_valid,
    input  wire [VPN_WIDTH-1:0]  refill_vpn,
    input  wire [PPN_WIDTH-1:0]  refill_ppn,
    input  wire [ASID_WIDTH-1:0] refill_asid,
    input  wire [3:0]  refill_flags,
    input  wire        refill_global,
    
    // Invalidate interface
    input  wire        sfence,
    input  wire        sfence_all,
    input  wire [VPN_WIDTH-1:0]  sfence_vpn,
    input  wire [ASID_WIDTH-1:0] sfence_asid,
    
    // Status
    output wire [NUM_ENTRIES-1:0] entry_valid,
    output wire [$clog2(NUM_ENTRIES)-1:0] lru_victim
);

    // VPN extraction (assuming 4KB pages)
    wire [VPN_WIDTH-1:0] lookup_vpn = virtual_addr[31:12];
    wire [11:0] page_offset = virtual_addr[11:0];
    
    // Entry hit signals
    wire [NUM_ENTRIES-1:0] hits;
    wire [PPN_WIDTH-1:0] ppn_array [0:NUM_ENTRIES-1];
    wire [3:0] flags_array [0:NUM_ENTRIES-1];
    
    // LRU replacement (pseudo-LRU using 4-bit counter per entry)
    reg [3:0] lru_counter [0:NUM_ENTRIES-1];
    reg [$clog2(NUM_ENTRIES)-1:0] victim_entry;
    
    // Find LRU entry for replacement
    integer i;
    reg [$clog2(NUM_ENTRIES)-1:0] min_idx;
    reg [3:0] min_val;
    
    always @(*) begin
        min_idx = 0;
        min_val = lru_counter[0];
        for (i = 1; i < NUM_ENTRIES; i = i + 1) begin
            if (lru_counter[i] < min_val || !entry_valid[i]) begin
                min_val = lru_counter[i];
                min_idx = i;
            end
        end
        victim_entry = min_idx;
    end
    
    assign lru_victim = victim_entry;
    
    // Generate TLB entries
    genvar g;
    generate
        for (g = 0; g < NUM_ENTRIES; g = g + 1) begin : gen_entries
            tlb_entry #(
                .VPN_WIDTH(VPN_WIDTH),
                .PPN_WIDTH(PPN_WIDTH),
                .ASID_WIDTH(ASID_WIDTH)
            ) u_entry (
                .clk            (clk),
                .rst_n          (rst_n),
                .lookup_vpn     (lookup_vpn),
                .lookup_asid    (asid),
                .lookup_valid   (lookup_valid),
                .hit            (hits[g]),
                .ppn_out        (ppn_array[g]),
                .flags_out      (flags_array[g]),
                .write_en       (refill_valid && (victim_entry == g)),
                .write_vpn      (refill_vpn),
                .write_ppn      (refill_ppn),
                .write_asid     (refill_asid),
                .write_flags    (refill_flags),
                .write_global   (refill_global),
                .invalidate     (sfence),
                .invalidate_all (sfence_all),
                .invalidate_vpn (sfence_vpn),
                .invalidate_asid(sfence_asid),
                .valid_out      (entry_valid[g])
            );
        end
    endgenerate
    
    // Hit detection (priority encoder for multiple hits - shouldn't happen)
    assign tlb_hit = |hits;
    
    // Select PPN from hitting entry
    reg [PPN_WIDTH-1:0] selected_ppn;
    reg [3:0] selected_flags;
    
    always @(*) begin
        selected_ppn = 0;
        selected_flags = 0;
        for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
            if (hits[i]) begin
                selected_ppn = ppn_array[i];
                selected_flags = flags_array[i];
            end
        end
    end
    
    assign physical_addr = {selected_ppn, page_offset};
    assign page_flags = selected_flags;
    
    // Update LRU counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
                lru_counter[i] <= i[3:0];
            end
        end else begin
            // On hit, set counter to max, decrement others
            if (tlb_hit) begin
                for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
                    if (hits[i]) begin
                        lru_counter[i] <= 4'hF;
                    end else if (lru_counter[i] > 0) begin
                        lru_counter[i] <= lru_counter[i] - 1;
                    end
                end
            end
            // On refill, set new entry to max
            if (refill_valid) begin
                lru_counter[victim_entry] <= 4'hF;
            end
        end
    end

endmodule
