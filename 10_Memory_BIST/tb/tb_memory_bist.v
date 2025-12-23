// Memory BIST Testbench
`timescale 1ns/1ps

module tb_memory_bist;

    // Parameters
    parameter ADDR_WIDTH = 8;  // 256 locations for faster simulation
    parameter DATA_WIDTH = 32;
    parameter MEM_DEPTH = 256;
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // BIST control
    reg bist_start;
    reg [2:0] test_mode;
    wire bist_done;
    wire bist_pass;
    wire bist_fail;
    wire bist_busy;
    
    // Memory interface
    wire mem_ce;
    wire mem_we;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [DATA_WIDTH-1:0] mem_wdata;
    reg [DATA_WIDTH-1:0] mem_rdata;
    
    // Fault info
    wire fault_detected;
    wire [ADDR_WIDTH-1:0] fault_addr;
    wire [DATA_WIDTH-1:0] fault_expected;
    wire [DATA_WIDTH-1:0] fault_actual;
    wire [2:0] fault_type;
    
    // Progress
    wire [7:0] progress_percent;
    wire [31:0] test_count;
    
    // Memory array (memory under test)
    reg [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    
    // Fault injection
    reg inject_fault;
    reg [ADDR_WIDTH-1:0] fault_location;
    reg [DATA_WIDTH-1:0] fault_mask;
    
    // DUT
    memory_bist #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_DEPTH(MEM_DEPTH)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .bist_start(bist_start),
        .test_mode(test_mode),
        .bist_done(bist_done),
        .bist_pass(bist_pass),
        .bist_fail(bist_fail),
        .bist_busy(bist_busy),
        .mem_ce(mem_ce),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .fault_detected(fault_detected),
        .fault_addr(fault_addr),
        .fault_expected(fault_expected),
        .fault_actual(fault_actual),
        .fault_type(fault_type),
        .progress_percent(progress_percent),
        .test_count(test_count)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Memory model with fault injection
    always @(posedge clk) begin
        if (mem_ce) begin
            if (mem_we) begin
                memory[mem_addr] <= mem_wdata;
            end else begin
                mem_rdata <= memory[mem_addr];
                // Inject fault if enabled
                if (inject_fault && mem_addr == fault_location) begin
                    mem_rdata <= memory[mem_addr] ^ fault_mask;
                end
            end
        end
    end
    
    // Test tasks
    task reset_system;
        integer i;
        begin
            rst_n = 0;
            bist_start = 0;
            test_mode = 0;
            inject_fault = 0;
            fault_location = 0;
            fault_mask = 0;
            
            // Initialize memory
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                memory[i] = 0;
            end
            
            #20;
            rst_n = 1;
            #10;
        end
    endtask
    
    task run_bist_test(input [2:0] mode, input string name);
        begin
            $display("\n--- Running %s Test ---", name);
            test_mode = mode;
            
            @(posedge clk);
            bist_start = 1;
            @(posedge clk);
            bist_start = 0;
            
            // Wait for completion
            while (!bist_done) begin
                @(posedge clk);
                if (progress_percent % 25 == 0) begin
                    $display("  Progress: %0d%%", progress_percent);
                end
            end
            
            if (bist_pass) begin
                $display("  Result: PASS");
            end else begin
                $display("  Result: FAIL");
                if (fault_detected) begin
                    $display("  Fault at address: 0x%h", fault_addr);
                    $display("  Expected: 0x%h", fault_expected);
                    $display("  Actual:   0x%h", fault_actual);
                    case (fault_type)
                        3'd1: $display("  Type: Stuck-at-0");
                        3'd2: $display("  Type: Stuck-at-1");
                        3'd3: $display("  Type: Transition Fault");
                        3'd4: $display("  Type: Coupling Fault");
                        default: $display("  Type: Unknown");
                    endcase
                end
            end
            
            #50;
        end
    endtask
    
    // Test sequence
    integer test_num;
    
    initial begin
        $dumpfile("memory_bist_tb.vcd");
        $dumpvars(0, tb_memory_bist);
        
        $display("========================================");
        $display("Memory BIST Testbench");
        $display("========================================");
        $display("Memory: %0d x %0d bits", MEM_DEPTH, DATA_WIDTH);
        
        reset_system();
        test_num = 0;
        
        // Test 1: March C- on good memory
        test_num = 1;
        $display("\n========================================");
        $display("Test %0d: March C- (No Faults)", test_num);
        $display("========================================");
        inject_fault = 0;
        run_bist_test(3'd0, "March C-");
        
        // Test 2: LFSR random pattern
        test_num = 2;
        $display("\n========================================");
        $display("Test %0d: LFSR Random Pattern", test_num);
        $display("========================================");
        run_bist_test(3'd2, "LFSR Random");
        
        // Test 3: March C- with stuck-at-0 fault
        test_num = 3;
        $display("\n========================================");
        $display("Test %0d: March C- with SAF-0 Fault", test_num);
        $display("========================================");
        inject_fault = 1;
        fault_location = 8'd100;
        fault_mask = 32'h0000FF00; // Stuck at 0 in byte 1
        run_bist_test(3'd0, "March C- (Faulty)");
        
        // Test 4: March C- with stuck-at-1 fault
        test_num = 4;
        $display("\n========================================");
        $display("Test %0d: March C- with SAF-1 Fault", test_num);
        $display("========================================");
        inject_fault = 1;
        fault_location = 8'd50;
        fault_mask = 32'hFFFFFFFF; // Make all 1s read as 0s
        run_bist_test(3'd0, "March C- (SAF-1)");
        
        // Test 5: March C+ variant
        test_num = 5;
        $display("\n========================================");
        $display("Test %0d: March C+ (No Faults)", test_num);
        $display("========================================");
        inject_fault = 0;
        run_bist_test(3'd1, "March C+");
        
        // Summary
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total test runs: %0d", test_num);
        
        #100;
        $finish;
    end
    
    // Timeout
    initial begin
        #500000;
        $display("SIMULATION TIMEOUT");
        $finish;
    end
    
    // Monitor progress - track previous fault_detected value
    reg fault_detected_prev;
    always @(posedge clk) begin
        fault_detected_prev <= fault_detected;
        if (bist_busy && fault_detected && !fault_detected_prev) begin
            $display("  [%0t] Fault detected at 0x%h", $time, fault_addr);
        end
    end

endmodule
