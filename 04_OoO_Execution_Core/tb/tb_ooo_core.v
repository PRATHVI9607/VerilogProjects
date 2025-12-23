// Out-of-Order Execution Core Testbench

`timescale 1ns/1ps

module tb_ooo_core;

    parameter TAG_WIDTH = 4;
    
    reg clk;
    reg rst_n;
    
    // Instruction interface
    reg         inst_valid;
    reg  [2:0]  inst_op;
    reg  [4:0]  inst_rs1;
    reg  [4:0]  inst_rs2;
    reg  [4:0]  inst_rd;
    reg  [31:0] inst_pc;
    wire        inst_ack;
    
    // Register read (simplified: always ready with test values)
    wire [4:0]  reg_read_addr1;
    wire [4:0]  reg_read_addr2;
    reg  [31:0] reg_read_data1;
    reg  [31:0] reg_read_data2;
    reg         reg_ready1;
    reg         reg_ready2;
    reg  [TAG_WIDTH-1:0] reg_tag1;
    reg  [TAG_WIDTH-1:0] reg_tag2;
    
    // Commit interface
    wire        commit_valid;
    wire [4:0]  commit_rd;
    wire [31:0] commit_data;
    
    // Status outputs
    wire [TAG_WIDTH-1:0] rob_head;
    wire [TAG_WIDTH-1:0] rob_tail;
    wire        rob_full;
    wire [3:0]  rs_alu_busy;
    wire [3:0]  rs_alu_ready;
    wire        cdb_valid;
    wire [TAG_WIDTH-1:0] cdb_tag;
    wire [31:0] cdb_data;
    
    // Simple register file for simulation
    reg [31:0] regfile [0:31];
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // DUT
    ooo_core #(
        .TAG_WIDTH(TAG_WIDTH),
        .ROB_SIZE(16)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .inst_valid     (inst_valid),
        .inst_op        (inst_op),
        .inst_rs1       (inst_rs1),
        .inst_rs2       (inst_rs2),
        .inst_rd        (inst_rd),
        .inst_pc        (inst_pc),
        .inst_ack       (inst_ack),
        .reg_read_addr1 (reg_read_addr1),
        .reg_read_addr2 (reg_read_addr2),
        .reg_read_data1 (reg_read_data1),
        .reg_read_data2 (reg_read_data2),
        .reg_ready1     (reg_ready1),
        .reg_ready2     (reg_ready2),
        .reg_tag1       (reg_tag1),
        .reg_tag2       (reg_tag2),
        .commit_valid   (commit_valid),
        .commit_rd      (commit_rd),
        .commit_data    (commit_data),
        .rob_head       (rob_head),
        .rob_tail       (rob_tail),
        .rob_full       (rob_full),
        .rs_alu_busy    (rs_alu_busy),
        .rs_alu_ready   (rs_alu_ready),
        .cdb_valid      (cdb_valid),
        .cdb_tag        (cdb_tag),
        .cdb_data       (cdb_data)
    );
    
    // VCD dump
    initial begin
        $dumpfile("ooo_core.vcd");
        $dumpvars(0, tb_ooo_core);
    end
    
    // Provide register values
    always @(*) begin
        reg_read_data1 = regfile[reg_read_addr1];
        reg_read_data2 = regfile[reg_read_addr2];
        reg_ready1 = 1'b1;  // Simplified: always ready
        reg_ready2 = 1'b1;
        reg_tag1 = 0;
        reg_tag2 = 0;
    end
    
    // Update regfile on commit
    always @(posedge clk) begin
        if (commit_valid && commit_rd != 0) begin
            regfile[commit_rd] <= commit_data;
            $display("COMMIT: x%0d <= %h", commit_rd, commit_data);
        end
    end
    
    // Task: Issue instruction
    task issue_inst;
        input [2:0]  op;
        input [4:0]  rs1;
        input [4:0]  rs2;
        input [4:0]  rd;
        input [31:0] pc;
        begin
            @(posedge clk);
            inst_valid <= 1'b1;
            inst_op <= op;
            inst_rs1 <= rs1;
            inst_rs2 <= rs2;
            inst_rd <= rd;
            inst_pc <= pc;
            
            @(posedge clk);
            while (!inst_ack) @(posedge clk);
            inst_valid <= 1'b0;
            
            $display("ISSUE: op=%d rs1=x%0d rs2=x%0d rd=x%0d pc=%h",
                    op, rs1, rs2, rd, pc);
        end
    endtask
    
    // Test sequence
    integer i;
    initial begin
        $display("===========================================");
        $display("Out-of-Order Execution Core Testbench");
        $display("===========================================\n");
        
        // Initialize
        rst_n = 0;
        inst_valid = 0;
        inst_op = 0;
        inst_rs1 = 0;
        inst_rs2 = 0;
        inst_rd = 0;
        inst_pc = 0;
        
        // Initialize register file
        for (i = 0; i < 32; i = i + 1) begin
            regfile[i] = i * 10;  // x0=0, x1=10, x2=20, etc.
        end
        
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("\nInitial register values:");
        $display("x1=%0d, x2=%0d, x3=%0d, x4=%0d, x5=%0d",
                regfile[1], regfile[2], regfile[3], regfile[4], regfile[5]);
        
        $display("\nTest 1: Simple ADD instructions");
        $display("-------------------------------------------");
        issue_inst(3'd0, 5'd1, 5'd2, 5'd3, 32'h1000);  // x3 = x1 + x2
        issue_inst(3'd0, 5'd3, 5'd4, 5'd5, 32'h1004);  // x5 = x3 + x4 (depends on prev)
        
        repeat(10) @(posedge clk);
        
        $display("\nTest 2: SUB instruction");
        $display("-------------------------------------------");
        issue_inst(3'd1, 5'd2, 5'd1, 5'd6, 32'h1008);  // x6 = x2 - x1
        
        repeat(10) @(posedge clk);
        
        $display("\nTest 3: Multiple independent instructions");
        $display("-------------------------------------------");
        issue_inst(3'd0, 5'd1, 5'd2, 5'd7, 32'h100C);   // x7 = x1 + x2
        issue_inst(3'd4, 5'd3, 5'd4, 5'd8, 32'h1010);   // x8 = x3 & x4
        issue_inst(3'd5, 5'd5, 5'd6, 5'd9, 32'h1014);   // x9 = x5 | x6
        
        repeat(15) @(posedge clk);
        
        $display("\nTest 4: Fill ROB with multiple instructions");
        $display("-------------------------------------------");
        for (i = 0; i < 8; i = i + 1) begin
            issue_inst(3'd0, 5'd1, 5'd2, 5'd10 + i[4:0], 32'h2000 + i*4);
        end
        
        repeat(20) @(posedge clk);
        
        // Final status
        $display("\n===========================================");
        $display("Final Register File:");
        $display("===========================================");
        for (i = 0; i < 18; i = i + 1) begin
            $display("x%0d = %0d (%h)", i, regfile[i], regfile[i]);
        end
        
        $display("\nFinal ROB Status:");
        $display("Head=%0d, Tail=%0d, Full=%b", rob_head, rob_tail, rob_full);
        $display("RS Busy=%b, RS Ready=%b", rs_alu_busy, rs_alu_ready);
        
        $display("\n===========================================");
        $display("View waveforms: gtkwave ooo_core.vcd");
        $display("===========================================");
        
        $finish;
    end
    
    // Monitor CDB broadcasts
    always @(posedge clk) begin
        if (cdb_valid) begin
            $display("CDB: tag=%0d data=%h", cdb_tag, cdb_data);
        end
    end

endmodule
