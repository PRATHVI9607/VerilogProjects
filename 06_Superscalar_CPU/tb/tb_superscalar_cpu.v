// Superscalar CPU Testbench

`timescale 1ns/1ps

module tb_superscalar_cpu;

    reg clk;
    reg rst_n;
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    superscalar_cpu dut (
        .clk   (clk),
        .rst_n (rst_n)
    );
    
    initial begin
        $dumpfile("superscalar.vcd");
        $dumpvars(0, tb_superscalar_cpu);
    end
    
    initial begin
        $display("===========================================");
        $display("Superscalar Dual-Issue CPU Testbench");
        $display("===========================================\n");
        
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        repeat(50) begin
            @(posedge clk);
            $display("Cycle: IF0=%h IF1=%h | Valid0=%b Valid1=%b | RAW=%b",
                    dut.if_pc_0, dut.if_pc_1,
                    dut.if_valid_0, dut.if_valid_1,
                    dut.raw_hazard);
            
            if (dut.ex_valid_0)
                $display("  ALU0: x%0d <= %h", dut.ex_rd_0, dut.ex_result_0);
            if (dut.ex_valid_1)
                $display("  ALU1: x%0d <= %h", dut.ex_rd_1, dut.ex_result_1);
        end
        
        $display("\n===========================================");
        $display("View waveforms: gtkwave superscalar.vcd");
        $display("===========================================");
        $finish;
    end

endmodule
