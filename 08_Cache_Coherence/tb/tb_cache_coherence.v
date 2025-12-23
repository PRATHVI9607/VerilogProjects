// Cache Coherence System Testbench
`timescale 1ns/1ps

module tb_cache_coherence;

    // Parameters
    parameter NUM_CPUS = 4;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CACHE_LINES = 64;
    parameter LINE_SIZE = 32;
    parameter LINE_BITS = LINE_SIZE * 8;
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // CPU interfaces
    reg [NUM_CPUS*ADDR_WIDTH-1:0] cpu_addr;
    reg [NUM_CPUS-1:0] cpu_read;
    reg [NUM_CPUS-1:0] cpu_write;
    reg [NUM_CPUS*DATA_WIDTH-1:0] cpu_write_data;
    wire [NUM_CPUS*DATA_WIDTH-1:0] cpu_read_data;
    wire [NUM_CPUS-1:0] cpu_ready;
    wire [NUM_CPUS-1:0] cpu_hit;
    
    // Memory interface
    wire mem_read;
    wire mem_write;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [LINE_BITS-1:0] mem_write_data;
    reg [LINE_BITS-1:0] mem_read_data;
    reg mem_ready;
    
    // Debug
    wire [NUM_CPUS*2-1:0] cache_state_dbg;
    
    // Memory model
    reg [LINE_BITS-1:0] main_memory [0:1023];
    
    // DUT
    coherent_cache_system #(
        .NUM_CPUS(NUM_CPUS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CACHE_LINES(CACHE_LINES),
        .LINE_SIZE(LINE_SIZE)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(cpu_addr),
        .cpu_read(cpu_read),
        .cpu_write(cpu_write),
        .cpu_write_data(cpu_write_data),
        .cpu_read_data(cpu_read_data),
        .cpu_ready(cpu_ready),
        .cpu_hit(cpu_hit),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_addr(mem_addr),
        .mem_write_data(mem_write_data),
        .mem_read_data(mem_read_data),
        .mem_ready(mem_ready),
        .cache_state_dbg(cache_state_dbg)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Memory model behavior
    always @(posedge clk) begin
        mem_ready <= 0;
        
        if (mem_read) begin
            mem_read_data <= main_memory[mem_addr[14:5]]; // Line-aligned
            mem_ready <= 1;
        end
        
        if (mem_write) begin
            main_memory[mem_addr[14:5]] <= mem_write_data;
            mem_ready <= 1;
        end
    end
    
    // Test tasks
    task reset_system;
        integer i;
        begin
            rst_n = 0;
            cpu_addr = 0;
            cpu_read = 0;
            cpu_write = 0;
            cpu_write_data = 0;
            
            // Initialize memory
            for (i = 0; i < 1024; i = i + 1) begin
                main_memory[i] = {8{i[31:0]}};
            end
            
            #20;
            rst_n = 1;
            #10;
        end
    endtask
    
    task cpu_read_word(input integer cpu_id, input [31:0] addr);
        begin
            @(posedge clk);
            cpu_addr[cpu_id*ADDR_WIDTH +: ADDR_WIDTH] = addr;
            cpu_read[cpu_id] = 1;
            
            // Wait for ready
            repeat(30) begin
                @(posedge clk);
                if (cpu_ready[cpu_id]) begin
                    cpu_read[cpu_id] = 0;
                    disable cpu_read_word;
                end
            end
            
            $display("TIMEOUT: CPU%0d read from 0x%h", cpu_id, addr);
            cpu_read[cpu_id] = 0;
        end
    endtask
    
    task cpu_write_word(input integer cpu_id, input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            cpu_addr[cpu_id*ADDR_WIDTH +: ADDR_WIDTH] = addr;
            cpu_write_data[cpu_id*DATA_WIDTH +: DATA_WIDTH] = data;
            cpu_write[cpu_id] = 1;
            
            // Wait for ready
            repeat(30) begin
                @(posedge clk);
                if (cpu_ready[cpu_id]) begin
                    cpu_write[cpu_id] = 0;
                    disable cpu_write_word;
                end
            end
            
            $display("TIMEOUT: CPU%0d write to 0x%h", cpu_id, addr);
            cpu_write[cpu_id] = 0;
        end
    endtask
    
    // Test sequence
    integer test_num;
    
    initial begin
        $dumpfile("cache_coherence_tb.vcd");
        $dumpvars(0, tb_cache_coherence);
        
        $display("========================================");
        $display("Cache Coherence (MESI) Testbench");
        $display("========================================\n");
        
        reset_system();
        test_num = 0;
        
        // Test 1: Single CPU read (cold miss)
        test_num = 1;
        $display("Test %0d: CPU0 Cold Read Miss", test_num);
        cpu_read_word(0, 32'h00001000);
        $display("  CPU0 read data: 0x%h", cpu_read_data[31:0]);
        $display("  Hit: %b", cpu_hit[0]);
        #20;
        
        // Test 2: Same CPU read again (hit - Exclusive)
        test_num = 2;
        $display("\nTest %0d: CPU0 Read Hit (Exclusive)", test_num);
        cpu_read_word(0, 32'h00001000);
        $display("  CPU0 read data: 0x%h", cpu_read_data[31:0]);
        $display("  Hit: %b", cpu_hit[0]);
        #20;
        
        // Test 3: Different CPU reads same address (Exclusive -> Shared)
        test_num = 3;
        $display("\nTest %0d: CPU1 Reads Same Address (Sharing)", test_num);
        cpu_read_word(1, 32'h00001000);
        $display("  CPU1 read data: 0x%h", cpu_read_data[63:32]);
        #20;
        
        // Test 4: CPU0 writes (Shared -> Modified, others Invalidate)
        test_num = 4;
        $display("\nTest %0d: CPU0 Write (Invalidate Others)", test_num);
        cpu_write_word(0, 32'h00001000, 32'hDEADBEEF);
        #20;
        
        // Test 5: CPU1 reads after CPU0 write (should get updated data)
        test_num = 5;
        $display("\nTest %0d: CPU1 Reads Modified Data", test_num);
        cpu_read_word(1, 32'h00001000);
        $display("  CPU1 read data: 0x%h", cpu_read_data[63:32]);
        #20;
        
        // Test 6: Multiple CPUs access different addresses
        test_num = 6;
        $display("\nTest %0d: Multiple CPUs Different Addresses", test_num);
        fork
            cpu_read_word(0, 32'h00002000);
            cpu_read_word(1, 32'h00003000);
            cpu_read_word(2, 32'h00004000);
            cpu_read_word(3, 32'h00005000);
        join
        $display("  All CPUs completed parallel reads");
        #20;
        
        // Test 7: Write-through scenario
        test_num = 7;
        $display("\nTest %0d: CPU2 Write to New Address", test_num);
        cpu_write_word(2, 32'h00006000, 32'hCAFEBABE);
        #20;
        
        // Test 8: Read back written data from different CPU
        test_num = 8;
        $display("\nTest %0d: CPU3 Reads CPU2's Write", test_num);
        cpu_read_word(3, 32'h00006000);
        $display("  CPU3 read data: 0x%h", cpu_read_data[127:96]);
        #20;
        
        // Test 9: False sharing scenario (different words, same line)
        test_num = 9;
        $display("\nTest %0d: False Sharing (Same Line)", test_num);
        cpu_write_word(0, 32'h00007000, 32'h11111111);
        cpu_write_word(1, 32'h00007004, 32'h22222222);
        #20;
        
        // Test 10: Verify coherence
        test_num = 10;
        $display("\nTest %0d: Coherence Verification", test_num);
        cpu_read_word(2, 32'h00007000);
        cpu_read_word(3, 32'h00007004);
        $display("  CPU2 read (0x7000): 0x%h", cpu_read_data[95:64]);
        $display("  CPU3 read (0x7004): 0x%h", cpu_read_data[127:96]);
        #20;
        
        // Summary
        $display("\n========================================");
        $display("Cache Coherence Tests Complete");
        $display("========================================\n");
        
        #100;
        $finish;
    end
    
    // Timeout
    initial begin
        #50000;
        $display("SIMULATION TIMEOUT");
        $finish;
    end

endmodule
