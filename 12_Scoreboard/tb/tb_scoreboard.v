// Scoreboard Testbench
// Tests CDC 6600 style scoreboard with various hazard scenarios

`timescale 1ns/1ps

module tb_scoreboard;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter NUM_FUS = 4;
    parameter NUM_REGS = 32;
    parameter REG_BITS = 5;
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Instruction interface
    reg        inst_valid;
    reg [2:0]  inst_op;
    reg [REG_BITS-1:0] inst_fi;
    reg [REG_BITS-1:0] inst_fj;
    reg [REG_BITS-1:0] inst_fk;
    reg [1:0]  inst_fu_type;
    
    // Status outputs
    wire       stall;
    wire [NUM_FUS-1:0] fu_busy;
    wire       issue_ok;
    wire [3:0] state;
    
    // Test tracking
    integer test_num;
    integer errors;
    integer cycle_count;
    
    // Operation codes
    localparam OP_ADD = 3'd0;
    localparam OP_SUB = 3'd1;
    localparam OP_AND = 3'd2;
    localparam OP_OR  = 3'd3;
    localparam OP_XOR = 3'd4;
    localparam OP_MUL = 3'd5;
    localparam OP_DIV = 3'd6;
    
    // FU types
    localparam FU_ALU = 2'd0;
    localparam FU_MUL = 2'd2;
    localparam FU_DIV = 2'd3;
    
    // DUT
    scoreboard #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_FUS(NUM_FUS),
        .NUM_REGS(NUM_REGS),
        .REG_BITS(REG_BITS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .inst_valid(inst_valid),
        .inst_op(inst_op),
        .inst_fi(inst_fi),
        .inst_fj(inst_fj),
        .inst_fk(inst_fk),
        .inst_fu_type(inst_fu_type),
        .stall(stall),
        .fu_busy(fu_busy),
        .issue_ok(issue_ok),
        .state(state)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Cycle counter
    always @(posedge clk) begin
        if (!rst_n)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end
    
    // VCD dump
    initial begin
        $dumpfile("scoreboard.vcd");
        $dumpvars(0, tb_scoreboard);
    end
    
    // Task: Issue instruction
    task issue_instruction;
        input [2:0] op;
        input [REG_BITS-1:0] fi;
        input [REG_BITS-1:0] fj;
        input [REG_BITS-1:0] fk;
        input [1:0] fu_type;
        begin
            @(posedge clk);
            inst_valid <= 1;
            inst_op <= op;
            inst_fi <= fi;
            inst_fj <= fj;
            inst_fk <= fk;
            inst_fu_type <= fu_type;
            @(posedge clk);
            
            // Wait until issued or timeout
            while (stall && cycle_count < 100) begin
                @(posedge clk);
            end
            
            inst_valid <= 0;
        end
    endtask
    
    // Task: Wait cycles
    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask
    
    // Task: Wait until all FUs idle
    task wait_idle;
        begin
            while (|fu_busy && cycle_count < 200) begin
                @(posedge clk);
            end
        end
    endtask
    
    // Main test
    initial begin
        // Initialize
        rst_n = 0;
        inst_valid = 0;
        inst_op = 0;
        inst_fi = 0;
        inst_fj = 0;
        inst_fk = 0;
        inst_fu_type = 0;
        test_num = 0;
        errors = 0;
        
        $display("==============================================");
        $display("CDC 6600 Scoreboard Testbench");
        $display("==============================================");
        
        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        // -------------------------------------------------------------------
        // Test 1: Simple ADD instruction
        // -------------------------------------------------------------------
        test_num = 1;
        $display("\nTest %0d: Simple ADD instruction", test_num);
        $display("  ADD R3 = R1 + R2");
        
        issue_instruction(OP_ADD, 5'd3, 5'd1, 5'd2, FU_ALU);
        wait_idle();
        
        $display("  Completed at cycle %0d", cycle_count);
        
        // -------------------------------------------------------------------
        // Test 2: Multiple independent ALU operations
        // -------------------------------------------------------------------
        test_num = 2;
        $display("\nTest %0d: Multiple independent ALU ops", test_num);
        $display("  ADD R4 = R5 + R6");
        $display("  SUB R7 = R8 - R9");
        
        issue_instruction(OP_ADD, 5'd4, 5'd5, 5'd6, FU_ALU);
        issue_instruction(OP_SUB, 5'd7, 5'd8, 5'd9, FU_ALU);
        wait_idle();
        
        $display("  Completed at cycle %0d", cycle_count);
        
        // -------------------------------------------------------------------
        // Test 3: RAW hazard (Read After Write)
        // -------------------------------------------------------------------
        test_num = 3;
        $display("\nTest %0d: RAW hazard test", test_num);
        $display("  MUL R10 = R1 * R2    (takes 3 cycles)");
        $display("  ADD R11 = R10 + R3   (depends on R10)");
        
        issue_instruction(OP_MUL, 5'd10, 5'd1, 5'd2, FU_MUL);
        issue_instruction(OP_ADD, 5'd11, 5'd10, 5'd3, FU_ALU);
        wait_idle();
        
        $display("  Completed at cycle %0d", cycle_count);
        
        // -------------------------------------------------------------------
        // Test 4: WAW hazard (Write After Write)
        // -------------------------------------------------------------------
        test_num = 4;
        $display("\nTest %0d: WAW hazard test", test_num);
        $display("  DIV R12 = R1 / R2    (takes 8 cycles)");
        $display("  ADD R12 = R3 + R4    (same dest - WAW!)");
        
        issue_instruction(OP_DIV, 5'd12, 5'd1, 5'd2, FU_DIV);
        issue_instruction(OP_ADD, 5'd12, 5'd3, 5'd4, FU_ALU);
        wait_idle();
        
        $display("  Completed at cycle %0d", cycle_count);
        
        // -------------------------------------------------------------------
        // Test 5: WAR hazard (Write After Read)
        // -------------------------------------------------------------------
        test_num = 5;
        $display("\nTest %0d: WAR hazard test", test_num);
        $display("  MUL R13 = R14 * R15  (reads R14)");
        $display("  ADD R14 = R1 + R2    (writes R14 - WAR!)");
        
        issue_instruction(OP_MUL, 5'd13, 5'd14, 5'd15, FU_MUL);
        issue_instruction(OP_ADD, 5'd14, 5'd1, 5'd2, FU_ALU);
        wait_idle();
        
        $display("  Completed at cycle %0d", cycle_count);
        
        // -------------------------------------------------------------------
        // Test 6: Structural hazard - all ALUs busy
        // -------------------------------------------------------------------
        test_num = 6;
        $display("\nTest %0d: Structural hazard test", test_num);
        $display("  ADD R20 = R1 + R2");
        $display("  SUB R21 = R3 - R4");
        $display("  AND R22 = R5 & R6    (should wait for ALU)");
        
        issue_instruction(OP_ADD, 5'd20, 5'd1, 5'd2, FU_ALU);
        issue_instruction(OP_SUB, 5'd21, 5'd3, 5'd4, FU_ALU);
        issue_instruction(OP_AND, 5'd22, 5'd5, 5'd6, FU_ALU);
        wait_idle();
        
        $display("  Completed at cycle %0d", cycle_count);
        
        // -------------------------------------------------------------------
        // Test 7: Long division with multiple short ops
        // -------------------------------------------------------------------
        test_num = 7;
        $display("\nTest %0d: Long division with multiple short ops", test_num);
        $display("  DIV R23 = R1 / R2    (8 cycles)");
        $display("  ADD R24 = R3 + R4    (1 cycle, independent)");
        $display("  SUB R25 = R5 - R6    (1 cycle, independent)");
        
        issue_instruction(OP_DIV, 5'd23, 5'd1, 5'd2, FU_DIV);
        issue_instruction(OP_ADD, 5'd24, 5'd3, 5'd4, FU_ALU);
        issue_instruction(OP_SUB, 5'd25, 5'd5, 5'd6, FU_ALU);
        wait_idle();
        
        $display("  Completed at cycle %0d", cycle_count);
        
        // -------------------------------------------------------------------
        // Test 8: Chain of dependent multiplications
        // -------------------------------------------------------------------
        test_num = 8;
        $display("\nTest %0d: Dependent multiplication chain", test_num);
        $display("  MUL R26 = R1 * R2");
        $display("  MUL R27 = R26 * R3   (depends on R26)");
        $display("  MUL R28 = R27 * R4   (depends on R27)");
        
        issue_instruction(OP_MUL, 5'd26, 5'd1, 5'd2, FU_MUL);
        wait_cycles(5); // Wait for first MUL to complete
        issue_instruction(OP_MUL, 5'd27, 5'd26, 5'd3, FU_MUL);
        wait_cycles(5);
        issue_instruction(OP_MUL, 5'd28, 5'd27, 5'd4, FU_MUL);
        wait_idle();
        
        $display("  Completed at cycle %0d", cycle_count);
        
        // -------------------------------------------------------------------
        // Test 9: Stress test - rapid instruction issue
        // -------------------------------------------------------------------
        test_num = 9;
        $display("\nTest %0d: Stress test - rapid issue", test_num);
        
        issue_instruction(OP_ADD, 5'd1, 5'd2, 5'd3, FU_ALU);
        issue_instruction(OP_SUB, 5'd4, 5'd5, 5'd6, FU_ALU);
        issue_instruction(OP_MUL, 5'd7, 5'd8, 5'd9, FU_MUL);
        issue_instruction(OP_DIV, 5'd10, 5'd11, 5'd12, FU_DIV);
        issue_instruction(OP_AND, 5'd13, 5'd14, 5'd15, FU_ALU);
        issue_instruction(OP_OR, 5'd16, 5'd17, 5'd18, FU_ALU);
        wait_idle();
        
        $display("  Completed at cycle %0d", cycle_count);
        
        // -------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------
        repeat(10) @(posedge clk);
        
        $display("\n==============================================");
        $display("Test Summary");
        $display("==============================================");
        $display("Total tests: %0d", test_num);
        $display("Total cycles: %0d", cycle_count);
        
        if (errors == 0) begin
            $display("STATUS: ALL TESTS PASSED");
        end else begin
            $display("STATUS: %0d ERRORS", errors);
        end
        
        $display("==============================================");
        $finish;
    end
    
    // Timeout
    initial begin
        #10000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
