// ============================================================================
//                    Dynamic Testbench for Pipelined RISC-V CPU
// ============================================================================
// This testbench reads expected values from golden_model output file
// (expected_values.hex) and verifies the CPU against those values.
//
// Usage:
//   1. Run: python3 golden_model.py program.hex > expected_values.hex
//   2. Run: make sim
// ============================================================================

`timescale 1ns/1ps

module tb_riscv_cpu;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Flag register outputs
    wire [3:0] flags;
    wire       flags_valid;
    
    // Expected values from golden model
    reg [31:0] expected_regs [0:31];
    reg [7:0]  reg_index;
    reg [31:0] expected_value;
    integer    fd;
    integer    scan_ret;
    
    // Test verification
    integer error_count;
    integer pass_count;
    integer i;
    
    // Clock generation - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Instantiate DUT
    riscv_cpu dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .flags       (flags),
        .flags_valid (flags_valid)
    );
    
    // VCD dump for GTKWave
    initial begin
        $dumpfile("riscv_cpu.vcd");
        $dumpvars(0, tb_riscv_cpu);
        
        // Dump internal signals for pipeline visualization
        $dumpvars(1, dut.u_if);
        $dumpvars(1, dut.u_id);
        $dumpvars(1, dut.u_ex);
        $dumpvars(1, dut.u_mem);
        $dumpvars(1, dut.u_wb);
        $dumpvars(1, dut.u_forward);
        $dumpvars(1, dut.u_hazard);
    end
    
    // Load expected values from golden model output
    initial begin
        // Initialize all expected registers to 0
        for (i = 0; i < 32; i = i + 1) begin
            expected_regs[i] = 32'h0;
        end
        
        // Read expected values from file
        fd = $fopen("expected_values.hex", "r");
        if (fd == 0) begin
            $display("WARNING: Could not open expected_values.hex");
            $display("         Run: python3 golden_model.py program.hex > expected_values.hex");
            $display("         Falling back to basic verification mode.");
        end else begin
            $display("Loading expected values from golden model...");
            while (!$feof(fd)) begin
                scan_ret = $fscanf(fd, "%d %h\n", reg_index, expected_value);
                if (scan_ret == 2 && reg_index < 32) begin
                    expected_regs[reg_index] = expected_value;
                end
            end
            $fclose(fd);
            $display("Golden model values loaded successfully!");
        end
    end
    
    // Test sequence
    initial begin
        $display("");
        $display("==================================================================");
        $display("     Dynamic Testbench for Pipelined RISC-V CPU                   ");
        $display("     Using Golden Model for Expected Values                       ");
        $display("==================================================================");
        $display("");
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        $display("Starting pipeline execution...\n");
        
        // Run for enough cycles to execute test program
        repeat(100) begin
            @(posedge clk);
            
            // Display pipeline status (condensed)
            if ($time % 100 == 0) begin // Every 10 cycles
                $display("Cycle %0t: PC=%h Instr=%h", 
                        $time, dut.if_pc, dut.if_instruction);
            end
        end
        
        // Display final register file contents
        $display("");
        $display("==================================================================");
        $display("                  Final Register File Contents                    ");
        $display("==================================================================");
        $display("");
        
        for (i = 0; i < 32; i = i + 1) begin
            if (dut.u_id.regfile[i] != 0) begin
                $display("  x%-2d = %h (%0d)", i, dut.u_id.regfile[i], $signed(dut.u_id.regfile[i]));
            end
        end
        
        // ============ Dynamic Verification Against Golden Model ============
        $display("");
        $display("==================================================================");
        $display("              Golden Model Verification Results                   ");
        $display("==================================================================");
        $display("");
        
        error_count = 0;
        pass_count = 0;
        
        // Verify all non-zero expected registers
        for (i = 1; i < 32; i = i + 1) begin  // Skip x0 (always 0)
            if (expected_regs[i] != 0 || dut.u_id.regfile[i] != 0) begin
                if (dut.u_id.regfile[i] === expected_regs[i]) begin
                    $display("  [PASS] x%-2d = %h (expected %h)", 
                            i, dut.u_id.regfile[i], expected_regs[i]);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  [FAIL] x%-2d = %h (expected %h)", 
                            i, dut.u_id.regfile[i], expected_regs[i]);
                    error_count = error_count + 1;
                end
            end
        end
        
        // Verify x0 is always 0
        if (dut.u_id.regfile[0] !== 32'h0) begin
            $display("  [FAIL] x0 = %h (must always be 0!)", dut.u_id.regfile[0]);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] x0 = 0 (hardwired zero)");
            pass_count = pass_count + 1;
        end
        
        // Summary
        $display("");
        $display("==================================================================");
        if (error_count == 0) begin
            $display("  *** ALL %0d TESTS PASSED! ***", pass_count);
        end else begin
            $display("  PASSED: %0d    FAILED: %0d", pass_count, error_count);
        end
        $display("==================================================================");
        
        $display("");
        $display("Simulation Complete!");
        $display("View waveforms: gtkwave riscv_cpu.vcd");
        $display("");
        
        $finish;
    end

endmodule
