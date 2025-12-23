// Virtual Memory Simulator Testbench
`timescale 1ns/1ps

module tb_virtual_memory;

    // Parameters
    parameter VA_WIDTH = 32;
    parameter PA_WIDTH = 32;
    parameter PAGE_SIZE = 4096;
    parameter NUM_FRAMES = 256;
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // CPU interface
    reg [VA_WIDTH-1:0] virtual_addr;
    reg mem_read;
    reg mem_write;
    wire [PA_WIDTH-1:0] physical_addr;
    wire addr_valid;
    wire page_fault;
    wire protection_fault;
    
    // Fault handling
    wire [VA_WIDTH-1:0] fault_addr;
    wire [1:0] fault_type;
    reg fault_handled;
    reg [31:0] new_pte;
    
    // Configuration
    reg [1:0] replacement_policy;
    reg supervisor_mode;
    reg [PA_WIDTH-1:0] page_table_base;
    
    // Statistics
    wire [31:0] page_fault_count;
    wire [31:0] tlb_hit_count;
    wire [31:0] tlb_miss_count;
    
    // DUT
    virtual_memory_controller #(
        .VA_WIDTH(VA_WIDTH),
        .PA_WIDTH(PA_WIDTH),
        .PAGE_SIZE(PAGE_SIZE),
        .NUM_FRAMES(NUM_FRAMES)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .virtual_addr(virtual_addr),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .physical_addr(physical_addr),
        .addr_valid(addr_valid),
        .page_fault(page_fault),
        .protection_fault(protection_fault),
        .fault_addr(fault_addr),
        .fault_type(fault_type),
        .fault_handled(fault_handled),
        .new_pte(new_pte),
        .replacement_policy(replacement_policy),
        .supervisor_mode(supervisor_mode),
        .page_table_base(page_table_base),
        .page_fault_count(page_fault_count),
        .tlb_hit_count(tlb_hit_count),
        .tlb_miss_count(tlb_miss_count)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test tasks
    task reset_system;
        begin
            rst_n = 0;
            virtual_addr = 0;
            mem_read = 0;
            mem_write = 0;
            fault_handled = 0;
            new_pte = 0;
            replacement_policy = 2'b00; // FIFO
            supervisor_mode = 1;
            page_table_base = 32'h80000000;
            #20;
            rst_n = 1;
            #10;
        end
    endtask
    
    task access_address(input [31:0] addr, input is_write);
        begin
            @(posedge clk);
            virtual_addr = addr;
            mem_read = ~is_write;
            mem_write = is_write;
            
            // Wait for completion or page fault
            repeat(50) begin
                @(posedge clk);
                if (addr_valid) begin
                    $display("  Address 0x%h -> Physical 0x%h", addr, physical_addr);
                    mem_read = 0;
                    mem_write = 0;
                    disable access_address;
                end
                if (page_fault) begin
                    $display("  Page fault at 0x%h (type: %b)", fault_addr, fault_type);
                    // Handle fault by providing a PTE
                    fault_handled = 1;
                    new_pte = 32'h00001007; // Valid, RWX, User
                    @(posedge clk);
                    fault_handled = 0;
                end
            end
            
            $display("  TIMEOUT accessing 0x%h", addr);
            mem_read = 0;
            mem_write = 0;
        end
    endtask
    
    // Test sequence
    integer test_num;
    integer i;
    
    initial begin
        $dumpfile("virtual_memory_tb.vcd");
        $dumpvars(0, tb_virtual_memory);
        
        $display("========================================");
        $display("Virtual Memory Simulator Testbench");
        $display("========================================\n");
        
        reset_system();
        test_num = 0;
        
        // Test 1: First access (TLB miss, page table walk)
        test_num = 1;
        $display("Test %0d: First Access (Cold TLB Miss)", test_num);
        access_address(32'h00001000, 0);
        #20;
        
        // Test 2: Same page access (TLB hit)
        test_num = 2;
        $display("\nTest %0d: Same Page Access (TLB Hit)", test_num);
        access_address(32'h00001004, 0);
        #20;
        
        // Test 3: Different page (TLB miss)
        test_num = 3;
        $display("\nTest %0d: Different Page (TLB Miss)", test_num);
        access_address(32'h00002000, 0);
        #20;
        
        // Test 4: Write access
        test_num = 4;
        $display("\nTest %0d: Write Access", test_num);
        access_address(32'h00003000, 1);
        #20;
        
        // Test 5: Multiple pages (stress TLB)
        test_num = 5;
        $display("\nTest %0d: Multiple Page Accesses", test_num);
        for (i = 0; i < 10; i = i + 1) begin
            access_address(32'h00010000 + (i * 32'h1000), 0);
            #10;
        end
        #20;
        
        // Test 6: Re-access earlier pages (check TLB)
        test_num = 6;
        $display("\nTest %0d: Re-access Earlier Pages", test_num);
        access_address(32'h00001000, 0);
        access_address(32'h00002000, 0);
        #20;
        
        // Test 7: Change replacement policy to LRU
        test_num = 7;
        $display("\nTest %0d: LRU Replacement Policy", test_num);
        replacement_policy = 2'b01;
        for (i = 0; i < 5; i = i + 1) begin
            access_address(32'h00020000 + (i * 32'h1000), 0);
            #10;
        end
        #20;
        
        // Test 8: Clock replacement policy
        test_num = 8;
        $display("\nTest %0d: Clock Replacement Policy", test_num);
        replacement_policy = 2'b10;
        for (i = 0; i < 5; i = i + 1) begin
            access_address(32'h00030000 + (i * 32'h1000), 0);
            #10;
        end
        #20;
        
        // Print statistics
        $display("\n========================================");
        $display("Statistics");
        $display("========================================");
        $display("Page Faults: %0d", page_fault_count);
        $display("TLB Hits:    %0d", tlb_hit_count);
        $display("TLB Misses:  %0d", tlb_miss_count);
        $display("Hit Rate:    %0d%%", (tlb_hit_count * 100) / (tlb_hit_count + tlb_miss_count + 1));
        
        $display("\n========================================");
        $display("Virtual Memory Tests Complete");
        $display("========================================\n");
        
        #100;
        $finish;
    end
    
    // Timeout
    initial begin
        #100000;
        $display("SIMULATION TIMEOUT");
        $finish;
    end

endmodule
