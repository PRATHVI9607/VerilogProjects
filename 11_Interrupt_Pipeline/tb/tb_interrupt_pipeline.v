// Interrupt-Enabled Pipeline Testbench
`timescale 1ns/1ps

module tb_interrupt_pipeline;

    // Parameters
    parameter XLEN = 32;
    parameter NUM_IRQS = 16;
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Instruction memory
    wire [XLEN-1:0] imem_addr;
    wire imem_req;
    reg [XLEN-1:0] imem_rdata;
    reg imem_ready;
    
    // Data memory
    wire [XLEN-1:0] dmem_addr;
    wire dmem_read;
    wire dmem_write;
    wire [XLEN-1:0] dmem_wdata;
    reg [XLEN-1:0] dmem_rdata;
    reg dmem_ready;
    
    // Interrupts
    reg [NUM_IRQS-1:0] irq_lines;
    reg timer_irq;
    reg sw_irq;
    
    // Status
    wire [1:0] priv_mode;
    wire [XLEN-1:0] pc_out;
    wire halted;
    
    // Memory arrays
    reg [XLEN-1:0] imem [0:1023];
    reg [XLEN-1:0] dmem [0:1023];
    
    // DUT
    interrupt_pipeline #(
        .XLEN(XLEN),
        .NUM_IRQS(NUM_IRQS)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_req(imem_req),
        .imem_rdata(imem_rdata),
        .imem_ready(imem_ready),
        .dmem_addr(dmem_addr),
        .dmem_read(dmem_read),
        .dmem_write(dmem_write),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .irq_lines(irq_lines),
        .timer_irq(timer_irq),
        .sw_irq(sw_irq),
        .priv_mode(priv_mode),
        .pc_out(pc_out),
        .halted(halted)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Memory model
    always @(posedge clk) begin
        // Instruction memory
        if (imem_req) begin
            imem_rdata <= imem[(imem_addr - 32'h80000000) >> 2];
            imem_ready <= 1;
        end else begin
            imem_ready <= 0;
        end
        
        // Data memory
        if (dmem_read) begin
            dmem_rdata <= dmem[dmem_addr >> 2];
            dmem_ready <= 1;
        end else if (dmem_write) begin
            dmem[dmem_addr >> 2] <= dmem_wdata;
            dmem_ready <= 1;
        end else begin
            dmem_ready <= 0;
        end
    end
    
    // Test tasks
    task reset_system;
        integer i;
        begin
            rst_n = 0;
            irq_lines = 0;
            timer_irq = 0;
            sw_irq = 0;
            
            // Initialize memories
            for (i = 0; i < 1024; i = i + 1) begin
                imem[i] = 32'h00000013;  // NOP (addi x0, x0, 0)
                dmem[i] = 0;
            end
            
            #20;
            rst_n = 1;
            #10;
        end
    endtask
    
    task load_test_program;
        begin
            // Simple test program
            // 0x80000000: addi x1, x0, 10      # x1 = 10
            // 0x80000004: addi x2, x0, 20      # x2 = 20
            // 0x80000008: add x3, x1, x2       # x3 = x1 + x2
            // 0x8000000C: sw x3, 0(x0)         # Store x3 to memory
            // 0x80000010: lw x4, 0(x0)         # Load back
            // 0x80000014: jal x0, 0            # Loop forever
            
            imem[0] = 32'h00a00093;  // addi x1, x0, 10
            imem[1] = 32'h01400113;  // addi x2, x0, 20
            imem[2] = 32'h002081b3;  // add x3, x1, x2
            imem[3] = 32'h00302023;  // sw x3, 0(x0)
            imem[4] = 32'h00002203;  // lw x4, 0(x0)
            imem[5] = 32'h0000006f;  // jal x0, 0 (infinite loop)
            
            // Interrupt handler at trap vector (0x80000004)
            // 0x80000100: addi x5, x0, 0xFF    # Mark interrupt taken
            // 0x80000104: mret                 # Return from interrupt
            imem[64] = 32'h0ff00293;  // addi x5, x0, 255
            imem[65] = 32'h30200073;  // mret
        end
    endtask
    
    task assert_interrupt(input [3:0] irq_num);
        begin
            $display("  Asserting IRQ %0d at time %0t", irq_num, $time);
            irq_lines[irq_num] = 1;
        end
    endtask
    
    task deassert_interrupt(input [3:0] irq_num);
        begin
            irq_lines[irq_num] = 0;
        end
    endtask
    
    // Test sequence
    integer cycle_count;
    
    initial begin
        $dumpfile("interrupt_pipeline_tb.vcd");
        $dumpvars(0, tb_interrupt_pipeline);
        
        $display("========================================");
        $display("Interrupt-Enabled Pipeline Testbench");
        $display("========================================\n");
        
        reset_system();
        load_test_program();
        cycle_count = 0;
        
        // Test 1: Basic execution
        $display("Test 1: Basic Pipeline Execution");
        repeat(20) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            $display("  Cycle %0d: PC = 0x%h, Priv = %b", 
                     cycle_count, pc_out, priv_mode);
        end
        #50;
        
        // Test 2: Trigger interrupt
        $display("\nTest 2: External Interrupt");
        assert_interrupt(4'd0);
        
        repeat(10) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            $display("  Cycle %0d: PC = 0x%h, IRQ pending", 
                     cycle_count, pc_out);
        end
        
        deassert_interrupt(4'd0);
        #50;
        
        // Test 3: Multiple interrupts
        $display("\nTest 3: Multiple Interrupts");
        assert_interrupt(4'd1);
        assert_interrupt(4'd5);
        
        repeat(10) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        
        deassert_interrupt(4'd1);
        deassert_interrupt(4'd5);
        #50;
        
        // Test 4: Timer interrupt
        $display("\nTest 4: Timer Interrupt");
        timer_irq = 1;
        
        repeat(10) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        
        timer_irq = 0;
        #50;
        
        // Test 5: Software interrupt
        $display("\nTest 5: Software Interrupt");
        sw_irq = 1;
        
        repeat(10) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        
        sw_irq = 0;
        #50;
        
        // Summary
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total cycles executed: %0d", cycle_count);
        $display("Final PC: 0x%h", pc_out);
        $display("Privilege mode: %s", 
                 priv_mode == 2'b11 ? "Machine" :
                 priv_mode == 2'b01 ? "Supervisor" : "User");
        
        #100;
        $finish;
    end
    
    // Timeout
    initial begin
        #50000;
        $display("SIMULATION TIMEOUT");
        $finish;
    end
    
    // Monitor PC changes
    reg [XLEN-1:0] prev_pc;
    always @(posedge clk) begin
        if (pc_out != prev_pc) begin
            prev_pc <= pc_out;
        end
    end

endmodule
