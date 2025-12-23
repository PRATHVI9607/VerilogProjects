`timescale 1ns/1ps

// Memory Management Unit (MMU) - Top Module
// Integrates TLB and Page Table Walker

module mmu #(
    parameter TLB_ENTRIES = 16,
    parameter VPN_WIDTH = 20,
    parameter PPN_WIDTH = 20,
    parameter ASID_WIDTH = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // CPU interface
    input  wire [31:0] cpu_addr,
    input  wire        cpu_read,
    input  wire        cpu_write,
    input  wire [ASID_WIDTH-1:0] cpu_asid,
    input  wire        cpu_supervisor, // 1 = supervisor mode, 0 = user mode
    output wire        cpu_ready,
    output wire [31:0] phys_addr,
    output wire        page_fault,
    output wire        access_violation,
    
    // Memory interface for PTW
    output wire        ptw_mem_req,
    output wire [31:0] ptw_mem_addr,
    input  wire        ptw_mem_resp,
    input  wire [31:0] ptw_mem_data,
    
    // SATP control
    input  wire [31:0] satp,
    input  wire        mmu_enable,
    
    // SFENCE.VMA instruction
    input  wire        sfence_vma,
    input  wire        sfence_all,
    input  wire [VPN_WIDTH-1:0] sfence_vpn,
    input  wire [ASID_WIDTH-1:0] sfence_asid,
    
    // Debug/status
    output wire        tlb_hit,
    output wire        ptw_active,
    output wire [TLB_ENTRIES-1:0] tlb_valid_entries
);

    // Internal signals
    wire lookup_valid;
    wire [31:0] tlb_phys_addr;
    wire [3:0] tlb_flags;
    wire tlb_hit_internal;
    
    // PTW signals
    wire ptw_request;
    wire ptw_done;
    wire ptw_fault;
    wire [1:0] ptw_fault_type;
    wire [PPN_WIDTH-1:0] ptw_result_ppn;
    wire [3:0] ptw_result_flags;
    wire ptw_result_global;
    wire [2:0] ptw_state;
    
    // TLB refill
    wire refill_valid;
    wire [VPN_WIDTH-1:0] refill_vpn;
    
    // State machine for MMU
    localparam MMU_IDLE     = 2'd0;
    localparam MMU_TLB_MISS = 2'd1;
    localparam MMU_REFILL   = 2'd2;
    localparam MMU_FAULT    = 2'd3;
    
    reg [1:0] mmu_state, mmu_next_state;
    reg [VPN_WIDTH-1:0] saved_vpn;
    reg page_fault_reg;
    reg access_violation_reg;
    
    // VPN extraction
    wire [VPN_WIDTH-1:0] vpn = cpu_addr[31:12];
    
    // TLB lookup valid when CPU requests and MMU is enabled
    assign lookup_valid = (cpu_read | cpu_write) & mmu_enable & (mmu_state == MMU_IDLE);
    
    // TLB instance
    tlb #(
        .NUM_ENTRIES(TLB_ENTRIES),
        .VPN_WIDTH(VPN_WIDTH),
        .PPN_WIDTH(PPN_WIDTH),
        .ASID_WIDTH(ASID_WIDTH)
    ) u_tlb (
        .clk            (clk),
        .rst_n          (rst_n),
        .virtual_addr   (cpu_addr),
        .asid           (cpu_asid),
        .lookup_valid   (lookup_valid),
        .tlb_hit        (tlb_hit_internal),
        .physical_addr  (tlb_phys_addr),
        .page_flags     (tlb_flags),
        .refill_valid   (refill_valid),
        .refill_vpn     (saved_vpn),
        .refill_ppn     (ptw_result_ppn),
        .refill_asid    (cpu_asid),
        .refill_flags   (ptw_result_flags),
        .refill_global  (ptw_result_global),
        .sfence         (sfence_vma),
        .sfence_all     (sfence_all),
        .sfence_vpn     (sfence_vpn),
        .sfence_asid    (sfence_asid),
        .entry_valid    (tlb_valid_entries),
        .lru_victim     ()
    );
    
    // Page Table Walker instance
    page_table_walker #(
        .VPN_WIDTH(VPN_WIDTH),
        .PPN_WIDTH(PPN_WIDTH),
        .ASID_WIDTH(ASID_WIDTH)
    ) u_ptw (
        .clk            (clk),
        .rst_n          (rst_n),
        .ptw_request    (ptw_request),
        .vpn            (saved_vpn),
        .asid           (cpu_asid),
        .ptw_done       (ptw_done),
        .ptw_fault      (ptw_fault),
        .fault_type     (ptw_fault_type),
        .result_ppn     (ptw_result_ppn),
        .result_flags   (ptw_result_flags),
        .result_global  (ptw_result_global),
        .mem_req_valid  (ptw_mem_req),
        .mem_req_addr   (ptw_mem_addr),
        .mem_resp_valid (ptw_mem_resp),
        .mem_resp_data  (ptw_mem_data),
        .satp           (satp),
        .satp_valid     (mmu_enable),
        .ptw_state      (ptw_state)
    );
    
    // MMU state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mmu_state <= MMU_IDLE;
        end else begin
            mmu_state <= mmu_next_state;
        end
    end
    
    always @(*) begin
        mmu_next_state = mmu_state;
        case (mmu_state)
            MMU_IDLE: begin
                if (lookup_valid && !tlb_hit_internal) begin
                    mmu_next_state = MMU_TLB_MISS;
                end
            end
            
            MMU_TLB_MISS: begin
                if (ptw_done) begin
                    mmu_next_state = MMU_REFILL;
                end else if (ptw_fault) begin
                    mmu_next_state = MMU_FAULT;
                end
            end
            
            MMU_REFILL: begin
                mmu_next_state = MMU_IDLE;
            end
            
            MMU_FAULT: begin
                mmu_next_state = MMU_IDLE;
            end
            
            default: mmu_next_state = MMU_IDLE;
        endcase
    end
    
    // Save VPN on TLB miss
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saved_vpn <= 0;
        end else if (lookup_valid && !tlb_hit_internal) begin
            saved_vpn <= vpn;
        end
    end
    
    // PTW request
    assign ptw_request = (mmu_state == MMU_TLB_MISS) && (ptw_state == 3'd0);
    
    // Refill TLB when PTW completes successfully
    assign refill_valid = (mmu_state == MMU_REFILL);
    
    // Permission checking
    wire flag_read  = tlb_flags[0];
    wire flag_write = tlb_flags[1];
    wire flag_exec  = tlb_flags[2];
    wire flag_user  = tlb_flags[3];
    
    wire read_allowed  = flag_read;
    wire write_allowed = flag_write;
    wire exec_allowed  = flag_exec;
    wire user_accessible = flag_user;
    
    // Access violation detection
    wire read_violation  = cpu_read && !read_allowed && tlb_hit_internal;
    wire write_violation = cpu_write && !write_allowed && tlb_hit_internal;
    wire user_violation  = !cpu_supervisor && !user_accessible && tlb_hit_internal;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            page_fault_reg <= 0;
            access_violation_reg <= 0;
        end else begin
            page_fault_reg <= (mmu_state == MMU_FAULT);
            access_violation_reg <= read_violation | write_violation | user_violation;
        end
    end
    
    // Output assignments
    assign tlb_hit = tlb_hit_internal;
    assign ptw_active = (mmu_state == MMU_TLB_MISS);
    
    // Physical address output
    // If MMU disabled, pass through virtual address
    // If MMU enabled and TLB hit, use translated address
    assign phys_addr = mmu_enable ? tlb_phys_addr : cpu_addr;
    
    // CPU ready when TLB hits or MMU disabled, or after refill
    assign cpu_ready = (!mmu_enable && (cpu_read | cpu_write)) ||
                       (mmu_enable && tlb_hit_internal && !access_violation_reg) ||
                       (mmu_state == MMU_REFILL);
    
    assign page_fault = page_fault_reg;
    assign access_violation = access_violation_reg;

endmodule
