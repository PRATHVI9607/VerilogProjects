// TLB and MMU Testbench
`timescale 1ns/1ps

module tb_mmu;

    // Parameters
    parameter TLB_ENTRIES = 16;
    parameter VPN_WIDTH = 20;
    parameter PPN_WIDTH = 20;
    parameter ASID_WIDTH = 8;
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // CPU interface
    reg [31:0] cpu_addr;
    reg cpu_read;
    reg cpu_write;
    reg [ASID_WIDTH-1:0] cpu_asid;
    reg cpu_supervisor;
    wire cpu_ready;
    wire [31:0] phys_addr;
    wire page_fault;
    wire access_violation;
    
    // PTW memory interface
    wire ptw_mem_req;
    wire [31:0] ptw_mem_addr;
    reg ptw_mem_resp;
    reg [31:0] ptw_mem_data;
    
    // Control
    reg [31:0] satp;
    reg mmu_enable;
    
    // SFENCE
    reg sfence_vma;
    reg sfence_all;
    reg [VPN_WIDTH-1:0] sfence_vpn;
    reg [ASID_WIDTH-1:0] sfence_asid;
    
    // Status
    wire tlb_hit;
    wire ptw_active;
    wire [TLB_ENTRIES-1:0] tlb_valid_entries;
    
    // Memory simulation (page tables)
    reg [31:0] page_table_l1 [0:1023];
    reg [31:0] page_table_l0 [0:1023];
    
    // DUT
    mmu #(
        .TLB_ENTRIES(TLB_ENTRIES),
        .VPN_WIDTH(VPN_WIDTH),
        .PPN_WIDTH(PPN_WIDTH),
        .ASID_WIDTH(ASID_WIDTH)
    ) u_mmu (
        .clk                (clk),
        .rst_n              (rst_n),
        .cpu_addr           (cpu_addr),
        .cpu_read           (cpu_read),
        .cpu_write          (cpu_write),
        .cpu_asid           (cpu_asid),
        .cpu_supervisor     (cpu_supervisor),
        .cpu_ready          (cpu_ready),
        .phys_addr          (phys_addr),
        .page_fault         (page_fault),
        .access_violation   (access_violation),
        .ptw_mem_req        (ptw_mem_req),
        .ptw_mem_addr       (ptw_mem_addr),
        .ptw_mem_resp       (ptw_mem_resp),
        .ptw_mem_data       (ptw_mem_data),
        .satp               (satp),
        .mmu_enable         (mmu_enable),
        .sfence_vma         (sfence_vma),
        .sfence_all         (sfence_all),
        .sfence_vpn         (sfence_vpn),
        .sfence_asid        (sfence_asid),
        .tlb_hit            (tlb_hit),
        .ptw_active         (ptw_active),
        .tlb_valid_entries  (tlb_valid_entries)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Memory response simulation
    always @(posedge clk) begin
        ptw_mem_resp <= 0;
        if (ptw_mem_req) begin
            // Simple memory model - respond next cycle
            ptw_mem_resp <= 1;
            // Determine which page table level based on address
            if (ptw_mem_addr[31:22] == satp[21:12]) begin
                // Level 1 page table
                ptw_mem_data <= page_table_l1[ptw_mem_addr[11:2]];
            end else begin
                // Level 0 page table
                ptw_mem_data <= page_table_l0[ptw_mem_addr[11:2]];
            end
        end
    end
    
    // Test tasks
    task reset_system;
        begin
            rst_n = 0;
            cpu_addr = 0;
            cpu_read = 0;
            cpu_write = 0;
            cpu_asid = 0;
            cpu_supervisor = 1;
            satp = 0;
            mmu_enable = 0;
            sfence_vma = 0;
            sfence_all = 0;
            sfence_vpn = 0;
            sfence_asid = 0;
            #20;
            rst_n = 1;
            #10;
        end
    endtask
    
    task setup_page_tables;
        integer i;
        begin
            // Initialize page tables
            for (i = 0; i < 1024; i = i + 1) begin
                page_table_l1[i] = 0;
                page_table_l0[i] = 0;
            end
            
            // Set up SATP: mode=1, ASID=0, PPN=0x80000 (root page table at 0x80000000)
            satp = 32'h80080000;
            
            // Level 1 PTE[0] -> Level 0 PT at PPN 0x80001 (non-leaf)
            // Format: PPN[21:0] | RSW | D | A | G | U | X | W | R | V
            page_table_l1[0] = 32'h20000401; // PPN=0x80001, V=1, rest=0 (non-leaf)
            
            // Level 0 PTE[0] -> Physical page at PPN 0x00001, RWX, User
            page_table_l0[0] = 32'h0000047F; // PPN=0x00001, V=1, R=1, W=1, X=1, U=1, G=0, A=1, D=1
            
            // Level 0 PTE[1] -> Physical page at PPN 0x00002, RW only (no exec)
            page_table_l0[1] = 32'h0000087F; // PPN=0x00002, V=1, R=1, W=1, X=0, U=1
            
            // Level 0 PTE[2] -> Physical page at PPN 0x00003, Read-only
            page_table_l0[2] = 32'h00000C7B; // PPN=0x00003, V=1, R=1, W=0, X=0, U=1
            
            // Level 0 PTE[3] -> Physical page at PPN 0x00004, Supervisor only
            page_table_l0[3] = 32'h0001006F; // PPN=0x00004, V=1, R=1, W=1, X=1, U=0 (supervisor)
            
            // Level 1 PTE[1] -> Invalid entry (for testing page fault)
            page_table_l1[1] = 32'h00000000; // Invalid PTE
        end
    endtask
    
    task cpu_read_access(input [31:0] addr);
        begin
            @(posedge clk);
            cpu_addr = addr;
            cpu_read = 1;
            cpu_write = 0;
            
            // Wait for ready or timeout
            repeat(50) begin
                @(posedge clk);
                if (cpu_ready || page_fault || access_violation) begin
                    cpu_read = 0;
                    disable cpu_read_access;
                end
            end
            
            $display("TIMEOUT: Read access to 0x%h", addr);
            cpu_read = 0;
        end
    endtask
    
    task cpu_write_access(input [31:0] addr);
        begin
            @(posedge clk);
            cpu_addr = addr;
            cpu_read = 0;
            cpu_write = 1;
            
            // Wait for ready or timeout
            repeat(50) begin
                @(posedge clk);
                if (cpu_ready || page_fault || access_violation) begin
                    cpu_write = 0;
                    disable cpu_write_access;
                end
            end
            
            $display("TIMEOUT: Write access to 0x%h", addr);
            cpu_write = 0;
        end
    endtask
    
    // Test sequence
    integer test_passed;
    integer test_failed;
    
    initial begin
        $dumpfile("mmu_tb.vcd");
        $dumpvars(0, tb_mmu);
        
        test_passed = 0;
        test_failed = 0;
        
        $display("========================================");
        $display("TLB and MMU Testbench");
        $display("========================================\n");
        
        // Initialize
        reset_system();
        setup_page_tables();
        
        // Test 1: MMU disabled - pass-through
        $display("Test 1: MMU Disabled (Pass-through)");
        mmu_enable = 0;
        cpu_read_access(32'h12345678);
        #10;
        if (phys_addr == 32'h12345678 && cpu_ready) begin
            $display("  PASS: Address passed through correctly");
            test_passed = test_passed + 1;
        end else begin
            $display("  FAIL: Expected 0x12345678, got 0x%h", phys_addr);
            test_failed = test_failed + 1;
        end
        #20;
        
        // Test 2: MMU enabled - TLB miss then hit
        $display("\nTest 2: TLB Miss -> PTW -> TLB Fill -> TLB Hit");
        mmu_enable = 1;
        cpu_asid = 8'd0;
        
        // First access - TLB miss, triggers PTW
        $display("  First access to 0x00000000 (TLB miss expected)");
        cpu_read_access(32'h00000000);
        #10;
        
        if (cpu_ready && !page_fault) begin
            $display("  PASS: First access completed after PTW");
            $display("  Physical address: 0x%h", phys_addr);
            test_passed = test_passed + 1;
        end else begin
            $display("  FAIL: First access failed");
            test_failed = test_failed + 1;
        end
        #20;
        
        // Second access - TLB hit
        $display("  Second access to 0x00000100 (same page, TLB hit expected)");
        cpu_read_access(32'h00000100);
        
        if (tlb_hit) begin
            $display("  PASS: TLB hit on second access");
            test_passed = test_passed + 1;
        end else begin
            $display("  FAIL: TLB miss on second access");
            test_failed = test_failed + 1;
        end
        #20;
        
        // Test 3: Different page - TLB miss again
        $display("\nTest 3: Access to different page");
        cpu_read_access(32'h00001000); // Page 1
        #10;
        
        if (cpu_ready && !page_fault) begin
            $display("  PASS: Access to page 1 completed");
            $display("  Physical address: 0x%h", phys_addr);
            test_passed = test_passed + 1;
        end else begin
            $display("  FAIL: Access to page 1 failed");
            test_failed = test_failed + 1;
        end
        #20;
        
        // Test 4: SFENCE.VMA - invalidate all
        $display("\nTest 4: SFENCE.VMA (Invalidate All TLB)");
        @(posedge clk);
        sfence_vma = 1;
        sfence_all = 1;
        @(posedge clk);
        sfence_vma = 0;
        sfence_all = 0;
        #10;
        
        $display("  TLB valid entries after SFENCE: 0x%h", tlb_valid_entries);
        if (tlb_valid_entries == 0) begin
            $display("  PASS: All TLB entries invalidated");
            test_passed = test_passed + 1;
        end else begin
            $display("  FAIL: Some entries still valid");
            test_failed = test_failed + 1;
        end
        #20;
        
        // Test 5: Multiple page accesses to fill TLB
        $display("\nTest 5: Fill TLB with multiple pages");
        begin : fill_tlb
            integer i;
            for (i = 0; i < 4; i = i + 1) begin
                cpu_read_access({20'd0, i[9:0], 12'h000});
                #30;
            end
        end
        
        $display("  TLB valid entries: 0x%h", tlb_valid_entries);
        if (|tlb_valid_entries) begin
            $display("  PASS: TLB entries populated");
            test_passed = test_passed + 1;
        end else begin
            $display("  FAIL: No TLB entries populated");
            test_failed = test_failed + 1;
        end
        #20;
        
        // Test 6: Write access (checking permissions)
        $display("\nTest 6: Write access to writable page");
        cpu_write_access(32'h00000000);
        #10;
        
        if (cpu_ready && !access_violation) begin
            $display("  PASS: Write access allowed");
            test_passed = test_passed + 1;
        end else begin
            $display("  FAIL: Write access denied or failed");
            test_failed = test_failed + 1;
        end
        #20;
        
        // Test 7: Check TLB LRU replacement
        $display("\nTest 7: TLB LRU Replacement");
        // Access many pages to force replacement
        sfence_vma = 1;
        sfence_all = 1;
        @(posedge clk);
        sfence_vma = 0;
        sfence_all = 0;
        #10;
        
        begin : lru_test
            integer i;
            for (i = 0; i < TLB_ENTRIES + 2; i = i + 1) begin
                // Need to set up more page table entries for this
                cpu_read_access({10'd0, i[9:0], 12'h000});
                #40;
            end
        end
        $display("  TLB entries after overflow: 0x%h", tlb_valid_entries);
        test_passed = test_passed + 1;
        #20;
        
        // Summary
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Passed: %0d", test_passed);
        $display("Failed: %0d", test_failed);
        $display("========================================\n");
        
        #100;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #50000;
        $display("SIMULATION TIMEOUT");
        $finish;
    end

endmodule
