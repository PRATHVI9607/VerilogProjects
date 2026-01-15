// Testbench for Pipelined RISC-V CPU
// Generates VCD waveforms for GTKWave visualization

`timescale 1ns/1ps

module tb_riscv_cpu;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Clock generation - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Instantiate DUT
    riscv_cpu dut (
        .clk   (clk),
        .rst_n (rst_n)
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
    
    // Test sequence
    initial begin
        $display("===========================================");
        $display("Pipelined RISC-V CPU Testbench");
        $display("===========================================");
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        $display("\nStarting pipeline execution...\n");
        
        // Run for enough cycles to execute test program
        repeat(100) begin
            @(posedge clk);
            
            // Display pipeline status
            $display("Cycle %0t:", $time);
            $display("  IF:  PC=%h Instr=%h Valid=%b", 
                    dut.if_pc, dut.if_instruction, dut.if_valid);
            $display("  ID:  PC=%h RS1=%d RS2=%d RD=%d Valid=%b",
                    dut.id_pc, dut.id_rs1_addr, dut.id_rs2_addr, dut.id_rd, dut.id_valid);
            $display("       RS1_data=%h RS2_data=%h",
                    dut.u_ex.rs1_data_in, dut.u_ex.rs2_data_in);
            $display("  EX:  ALU_Result=%h RD=%d Valid=%b FwdA=%b FwdB=%b",
                    dut.ex_alu_result, dut.ex_rd, dut.ex_valid, 
                    dut.fwd_a_sel, dut.fwd_b_sel);
            $display("       ALU_OpA=%h ALU_OpB=%h ALUOp=%h",
                    dut.u_ex.alu_operand_a, dut.u_ex.alu_operand_b, dut.u_ex.alu_op_in);
            $display("  MEM: ALU_Result=%h MemData=%h RD=%d Valid=%b",
                    dut.mem_alu_result, dut.mem_mem_data, dut.mem_rd, dut.mem_valid);
            $display("  WB:  Data=%h RD=%d Enable=%b",
                    dut.wb_data, dut.wb_rd, dut.wb_enable);
            $display("  Hazard: StallIF=%b StallID=%b FlushEX=%b",
                    dut.stall_if, dut.stall_id, dut.flush_ex);
            $display("  Branch: Taken=%b Target=%h\n",
                    dut.branch_taken, dut.branch_target);
        end
        
        // Display final register file contents
        $display("\n===========================================");
        $display("Final Register File Contents:");
        $display("===========================================");
        $display("x1  = %h (%0d)", dut.u_id.regfile[1], dut.u_id.regfile[1]);
        $display("x2  = %h (%0d)", dut.u_id.regfile[2], dut.u_id.regfile[2]);
        $display("x3  = %h (%0d)", dut.u_id.regfile[3], dut.u_id.regfile[3]);
        $display("x4  = %h (%0d)", dut.u_id.regfile[4], $signed(dut.u_id.regfile[4]));
        $display("x5  = %h (%0d)", dut.u_id.regfile[5], dut.u_id.regfile[5]);
        $display("x6  = %h (%0d)", dut.u_id.regfile[6], dut.u_id.regfile[6]);
        $display("x7  = %h (%0d)", dut.u_id.regfile[7], dut.u_id.regfile[7]);
        $display("x8  = %h (%0d)", dut.u_id.regfile[8], dut.u_id.regfile[8]);
        $display("x9  = %h (%0d)", dut.u_id.regfile[9], dut.u_id.regfile[9]);
        $display("x10 = %h (%0d)", dut.u_id.regfile[10], dut.u_id.regfile[10]);
        $display("x11 = %h (%0d)", dut.u_id.regfile[11], dut.u_id.regfile[11]);
        $display("x12 = %h (%0d)", dut.u_id.regfile[12], dut.u_id.regfile[12]);
        $display("x13 = %h (%0d)", dut.u_id.regfile[13], dut.u_id.regfile[13]);
        $display("x14 = %h (%0d)", dut.u_id.regfile[14], dut.u_id.regfile[14]);
        $display("x15 = %h (%0d)", dut.u_id.regfile[15], dut.u_id.regfile[15]);
        $display("x16 = %h (%0d)", dut.u_id.regfile[16], dut.u_id.regfile[16]);
        $display("x17 = %h (%0d)", dut.u_id.regfile[17], dut.u_id.regfile[17]);
        $display("x18 = %h (%0d)", dut.u_id.regfile[18], dut.u_id.regfile[18]);
        $display("x19 = %h (%0d)", dut.u_id.regfile[19], dut.u_id.regfile[19]);
        $display("x20 = %h (%0d)", dut.u_id.regfile[20], dut.u_id.regfile[20]);
        $display("x21 = %h (%0d)", dut.u_id.regfile[21], dut.u_id.regfile[21]);
        $display("x22 = %h (%0d)", dut.u_id.regfile[22], $signed(dut.u_id.regfile[22]));
        $display("x23 = %h (%0d)", dut.u_id.regfile[23], $signed(dut.u_id.regfile[23]));
        $display("x24 = %h (%0d)", dut.u_id.regfile[24], dut.u_id.regfile[24]);
        $display("x25 = %h (%0d)", dut.u_id.regfile[25], dut.u_id.regfile[25]);
        $display("x26 = %h (%0d)", dut.u_id.regfile[26], dut.u_id.regfile[26]);
        $display("x27 = %h (%0d)", dut.u_id.regfile[27], dut.u_id.regfile[27]);
        $display("x28 = %h (%0d)", dut.u_id.regfile[28], dut.u_id.regfile[28]);
        $display("x29 = %h (%0d)", dut.u_id.regfile[29], dut.u_id.regfile[29]);
        $display("x30 = %h (%0d)", dut.u_id.regfile[30], dut.u_id.regfile[30]);
        $display("x31 = %h (%0d)", dut.u_id.regfile[31], dut.u_id.regfile[31]);
        
        $display("\n===========================================");
        $display("Simulation Complete!");
        $display("View waveforms: gtkwave riscv_cpu.vcd");
        $display("===========================================");
        
        $finish;
    end

endmodule
