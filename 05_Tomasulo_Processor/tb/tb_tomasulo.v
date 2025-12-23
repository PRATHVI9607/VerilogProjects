// Tomasulo Processor Testbench

`timescale 1ns/1ps

`include "tomasulo_pkg.v"

module tb_tomasulo;

    parameter TAG_WIDTH = 4;
    
    reg clk;
    reg rst_n;
    
    // Instruction interface
    reg         inst_valid;
    reg  [2:0]  inst_op;
    reg  [3:0]  inst_rs;
    reg  [3:0]  inst_rt;
    reg  [3:0]  inst_rd;
    reg  [31:0] inst_imm;
    wire        inst_ack;
    
    // Status
    wire        cdb_valid;
    wire [TAG_WIDTH-1:0] cdb_tag;
    wire [31:0] cdb_data;
    wire        add_rs1_busy;
    wire        add_rs2_busy;
    wire        mul_rs1_busy;
    wire        mul_rs2_busy;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // DUT
    tomasulo_processor #(
        .TAG_WIDTH(TAG_WIDTH)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .inst_valid  (inst_valid),
        .inst_op     (inst_op),
        .inst_rs     (inst_rs),
        .inst_rt     (inst_rt),
        .inst_rd     (inst_rd),
        .inst_imm    (inst_imm),
        .inst_ack    (inst_ack),
        .cdb_valid   (cdb_valid),
        .cdb_tag     (cdb_tag),
        .cdb_data    (cdb_data),
        .add_rs1_busy(add_rs1_busy),
        .add_rs2_busy(add_rs2_busy),
        .mul_rs1_busy(mul_rs1_busy),
        .mul_rs2_busy(mul_rs2_busy)
    );
    
    // VCD dump
    initial begin
        $dumpfile("tomasulo.vcd");
        $dumpvars(0, tb_tomasulo);
    end
    
    // Task: Issue instruction
    task issue_inst;
        input [2:0]  op;
        input [3:0]  rs;
        input [3:0]  rt;
        input [3:0]  rd;
        begin
            @(posedge clk);
            inst_valid <= 1'b1;
            inst_op <= op;
            inst_rs <= rs;
            inst_rt <= rt;
            inst_rd <= rd;
            inst_imm <= 32'b0;
            
            @(posedge clk);
            while (!inst_ack) @(posedge clk);
            inst_valid <= 1'b0;
            
            $display("ISSUE: %s F%0d, F%0d, F%0d | RS_busy: Add1=%b Add2=%b Mul1=%b Mul2=%b",
                    op == `FP_ADD ? "ADD" : 
                    op == `FP_SUB ? "SUB" :
                    op == `FP_MUL ? "MUL" : "DIV",
                    rd, rs, rt,
                    add_rs1_busy, add_rs2_busy, mul_rs1_busy, mul_rs2_busy);
        end
    endtask
    
    // Monitor CDB broadcasts
    always @(posedge clk) begin
        if (cdb_valid) begin
            $display("  CDB BROADCAST: Tag=%0d Data=%0d", cdb_tag, cdb_data);
        end
    end
    
    // Test sequence
    initial begin
        $display("===========================================");
        $display("Tomasulo Algorithm Processor Testbench");
        $display("===========================================");
        $display("Register initial values: F0=0, F1=10, F2=20, ...\n");
        
        // Initialize
        rst_n = 0;
        inst_valid = 0;
        inst_op = 0;
        inst_rs = 0;
        inst_rt = 0;
        inst_rd = 0;
        inst_imm = 0;
        
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("Test 1: Classic Tomasulo Example");
        $display("-------------------------------------------");
        $display("F4 = F0 + F2");
        issue_inst(`FP_ADD, 4'd0, 4'd2, 4'd4);  // F4 = F0 + F2
        
        $display("F6 = F4 * F2  (RAW hazard on F4)");
        issue_inst(`FP_MUL, 4'd4, 4'd2, 4'd6);  // F6 = F4 * F2 (RAW on F4)
        
        $display("F8 = F4 + F6  (RAW hazards on F4 and F6)");
        issue_inst(`FP_ADD, 4'd4, 4'd6, 4'd8);  // F8 = F4 + F6 (RAW on F4, F6)
        
        // Wait for completion
        repeat(15) @(posedge clk);
        
        $display("\nTest 2: Independent Operations");
        $display("-------------------------------------------");
        issue_inst(`FP_ADD, 4'd1, 4'd2, 4'd9);   // F9 = F1 + F2
        issue_inst(`FP_MUL, 4'd3, 4'd5, 4'd10);  // F10 = F3 * F5
        
        repeat(10) @(posedge clk);
        
        $display("\nTest 3: Multiple Adds (fill ADD RS)");
        $display("-------------------------------------------");
        issue_inst(`FP_ADD, 4'd1, 4'd2, 4'd11);
        issue_inst(`FP_ADD, 4'd3, 4'd4, 4'd12);
        
        repeat(10) @(posedge clk);
        
        $display("\nTest 4: Structural Hazard");
        $display("-------------------------------------------");
        issue_inst(`FP_MUL, 4'd1, 4'd2, 4'd13);
        issue_inst(`FP_MUL, 4'd3, 4'd4, 4'd14);
        // Third MUL should stall until RS frees
        issue_inst(`FP_MUL, 4'd5, 4'd6, 4'd15);
        
        repeat(20) @(posedge clk);
        
        $display("\n===========================================");
        $display("Simulation Complete!");
        $display("View waveforms: gtkwave tomasulo.vcd");
        $display("===========================================");
        
        $finish;
    end

endmodule
