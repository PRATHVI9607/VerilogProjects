// Cache System Testbench
// Tests both direct-mapped and set-associative caches

`timescale 1ns/1ps

module tb_cache_system;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // CPU interface signals
    reg  [31:0] cpu_addr;
    reg  [31:0] cpu_wdata;
    reg         cpu_read;
    reg         cpu_write;
    wire [31:0] dm_cpu_rdata;
    wire        dm_cpu_ready;
    wire [31:0] sa_cpu_rdata;
    wire        sa_cpu_ready;
    
    // Memory interface for direct-mapped
    wire [31:0]  dm_mem_addr;
    wire [255:0] dm_mem_wdata;
    wire         dm_mem_read;
    wire         dm_mem_write;
    wire [255:0] dm_mem_rdata;
    wire         dm_mem_ready;
    
    // Memory interface for set-associative
    wire [31:0]  sa_mem_addr;
    wire [255:0] sa_mem_wdata;
    wire         sa_mem_read;
    wire         sa_mem_write;
    wire [255:0] sa_mem_rdata;
    wire         sa_mem_ready;
    
    // Status signals
    wire dm_hit, dm_miss, dm_dirty_evict;
    wire [4:0] dm_index;
    wire [21:0] dm_tag;
    wire dm_valid, dm_dirty;
    
    wire sa_hit, sa_miss, sa_dirty_evict;
    wire [1:0] sa_hit_way, sa_lru_way;
    wire [3:0] sa_index;
    wire [22:0] sa_tag;
    
    // Statistics
    integer dm_hits, dm_misses;
    integer sa_hits, sa_misses;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Direct-Mapped Cache
    direct_mapped_cache dm_cache (
        .clk           (clk),
        .rst_n         (rst_n),
        .cpu_addr      (cpu_addr),
        .cpu_wdata     (cpu_wdata),
        .cpu_read      (cpu_read),
        .cpu_write     (cpu_write),
        .cpu_rdata     (dm_cpu_rdata),
        .cpu_ready     (dm_cpu_ready),
        .mem_addr      (dm_mem_addr),
        .mem_wdata     (dm_mem_wdata),
        .mem_read      (dm_mem_read),
        .mem_write     (dm_mem_write),
        .mem_rdata     (dm_mem_rdata),
        .mem_ready     (dm_mem_ready),
        .hit           (dm_hit),
        .miss          (dm_miss),
        .dirty_evict   (dm_dirty_evict),
        .current_index (dm_index),
        .current_tag   (dm_tag),
        .valid_bit     (dm_valid),
        .dirty_bit     (dm_dirty)
    );
    
    // Memory for direct-mapped cache
    main_memory dm_mem (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (dm_mem_addr),
        .wdata (dm_mem_wdata),
        .read  (dm_mem_read),
        .write (dm_mem_write),
        .rdata (dm_mem_rdata),
        .ready (dm_mem_ready)
    );
    
    // Set-Associative Cache
    set_associative_cache sa_cache (
        .clk           (clk),
        .rst_n         (rst_n),
        .cpu_addr      (cpu_addr),
        .cpu_wdata     (cpu_wdata),
        .cpu_read      (cpu_read),
        .cpu_write     (cpu_write),
        .cpu_rdata     (sa_cpu_rdata),
        .cpu_ready     (sa_cpu_ready),
        .mem_addr      (sa_mem_addr),
        .mem_wdata     (sa_mem_wdata),
        .mem_read      (sa_mem_read),
        .mem_write     (sa_mem_write),
        .mem_rdata     (sa_mem_rdata),
        .mem_ready     (sa_mem_ready),
        .hit           (sa_hit),
        .miss          (sa_miss),
        .hit_way       (sa_hit_way),
        .current_index (sa_index),
        .current_tag   (sa_tag),
        .lru_way       (sa_lru_way),
        .dirty_evict   (sa_dirty_evict)
    );
    
    // Memory for set-associative cache
    main_memory sa_mem (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (sa_mem_addr),
        .wdata (sa_mem_wdata),
        .read  (sa_mem_read),
        .write (sa_mem_write),
        .rdata (sa_mem_rdata),
        .ready (sa_mem_ready)
    );
    
    // VCD dump
    initial begin
        $dumpfile("cache_system.vcd");
        $dumpvars(0, tb_cache_system);
    end
    
    // Task: Read from cache
    task cache_read;
        input [31:0] addr;
        begin
            @(posedge clk);
            cpu_addr <= addr;
            cpu_read <= 1'b1;
            cpu_write <= 1'b0;
            
            // Wait for both caches to complete
            @(posedge clk);
            cpu_read <= 1'b0;
            
            fork
                begin
                    wait(dm_cpu_ready);
                    if (dm_hit) dm_hits = dm_hits + 1;
                    else dm_misses = dm_misses + 1;
                end
                begin
                    wait(sa_cpu_ready);
                    if (sa_hit) sa_hits = sa_hits + 1;
                    else sa_misses = sa_misses + 1;
                end
            join
            
            @(posedge clk);
        end
    endtask
    
    // Task: Write to cache
    task cache_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            cpu_addr <= addr;
            cpu_wdata <= data;
            cpu_read <= 1'b0;
            cpu_write <= 1'b1;
            
            @(posedge clk);
            cpu_write <= 1'b0;
            
            fork
                wait(dm_cpu_ready);
                wait(sa_cpu_ready);
            join
            
            @(posedge clk);
        end
    endtask
    
    // Test sequence
    initial begin
        $display("===========================================");
        $display("Cache Memory System Testbench");
        $display("===========================================\n");
        
        // Initialize
        rst_n = 0;
        cpu_addr = 0;
        cpu_wdata = 0;
        cpu_read = 0;
        cpu_write = 0;
        dm_hits = 0;
        dm_misses = 0;
        sa_hits = 0;
        sa_misses = 0;
        
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("Test 1: Sequential reads (cold cache)");
        $display("-------------------------------------------");
        cache_read(32'h00000000);
        $display("Read 0x00000000: DM_rdata=%h, SA_rdata=%h", dm_cpu_rdata, sa_cpu_rdata);
        
        cache_read(32'h00000004);
        $display("Read 0x00000004: DM_rdata=%h, SA_rdata=%h (same block - hit)", dm_cpu_rdata, sa_cpu_rdata);
        
        cache_read(32'h00000020);
        $display("Read 0x00000020: DM_rdata=%h, SA_rdata=%h (new block)", dm_cpu_rdata, sa_cpu_rdata);
        
        $display("\nTest 2: Write and read back");
        $display("-------------------------------------------");
        cache_write(32'h00000000, 32'hDEADBEEF);
        $display("Write 0xDEADBEEF to 0x00000000");
        
        cache_read(32'h00000000);
        $display("Read 0x00000000: DM_rdata=%h, SA_rdata=%h", dm_cpu_rdata, sa_cpu_rdata);
        
        $display("\nTest 3: Conflict misses (same index, different tag)");
        $display("-------------------------------------------");
        cache_read(32'h00000400);  // Maps to same DM index as 0x0
        $display("Read 0x00000400 (conflicts with 0x0 in DM)");
        
        cache_read(32'h00000000);  // Should miss in DM, may hit in SA
        $display("Read 0x00000000 again");
        
        $display("\nTest 4: LRU replacement test");
        $display("-------------------------------------------");
        // Fill both ways of a set in SA cache
        cache_read(32'h00000000);
        cache_read(32'h00000200);  // Same SA index, different tag
        cache_read(32'h00000400);  // Should evict LRU in SA
        $display("Accessed 0x000, 0x200, 0x400 to test LRU");
        
        $display("\nTest 5: Dirty writeback");
        $display("-------------------------------------------");
        cache_write(32'h00000800, 32'hCAFEBABE);
        cache_write(32'h00000A00, 32'h12345678);  // May cause dirty eviction
        $display("Wrote to 0x800 and 0xA00");
        
        repeat(20) @(posedge clk);
        
        // Print statistics
        $display("\n===========================================");
        $display("Cache Statistics");
        $display("===========================================");
        $display("Direct-Mapped Cache:");
        $display("  Hits:   %0d", dm_hits);
        $display("  Misses: %0d", dm_misses);
        $display("  Hit Rate: %0.1f%%", 100.0 * dm_hits / (dm_hits + dm_misses));
        $display("");
        $display("Set-Associative Cache:");
        $display("  Hits:   %0d", sa_hits);
        $display("  Misses: %0d", sa_misses);
        $display("  Hit Rate: %0.1f%%", 100.0 * sa_hits / (sa_hits + sa_misses));
        $display("");
        $display("View waveforms: gtkwave cache_system.vcd");
        $display("===========================================");
        
        $finish;
    end

endmodule
