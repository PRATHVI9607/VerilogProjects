// Branch Predictor Testbench
// Tests GShare predictor accuracy over branch sequences

`timescale 1ns/1ps

module tb_branch_predictor;

    reg clk;
    reg rst_n;
    
    // Prediction interface
    reg  [31:0] fetch_pc;
    reg         fetch_valid;
    wire        predict_taken;
    wire [31:0] predict_target;
    wire        predict_valid;
    
    // Resolution interface
    reg         resolve_valid;
    reg  [31:0] resolve_pc;
    reg         resolve_taken;
    reg  [31:0] resolve_target;
    reg         resolve_is_branch;
    reg         was_predicted_taken;
    
    // Visualization
    wire [7:0]  ghr;
    wire [7:0]  pht_index;
    wire [1:0]  counter_value;
    wire        misprediction;
    wire        btb_hit;
    
    // Statistics
    integer total_branches;
    integer correct_predictions;
    integer mispredictions;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // DUT
    branch_predictor dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .fetch_pc          (fetch_pc),
        .fetch_valid       (fetch_valid),
        .predict_taken     (predict_taken),
        .predict_target    (predict_target),
        .predict_valid     (predict_valid),
        .resolve_valid     (resolve_valid),
        .resolve_pc        (resolve_pc),
        .resolve_taken     (resolve_taken),
        .resolve_target    (resolve_target),
        .resolve_is_branch (resolve_is_branch),
        .was_predicted_taken(was_predicted_taken),
        .ghr               (ghr),
        .pht_index         (pht_index),
        .counter_value     (counter_value),
        .misprediction     (misprediction),
        .btb_hit_out       (btb_hit)
    );
    
    // VCD dump
    initial begin
        $dumpfile("branch_predictor.vcd");
        $dumpvars(0, tb_branch_predictor);
    end
    
    // Task: Simulate a branch
    task execute_branch;
        input [31:0] pc;
        input [31:0] target;
        input        taken;
        reg          predicted;
        begin
            // Fetch phase - get prediction
            @(posedge clk);
            fetch_pc <= pc;
            fetch_valid <= 1'b1;
            resolve_valid <= 1'b0;
            
            @(posedge clk);
            fetch_valid <= 1'b0;
            predicted = predict_taken;
            
            // Execute phase - resolve branch
            @(posedge clk);
            resolve_valid <= 1'b1;
            resolve_pc <= pc;
            resolve_taken <= taken;
            resolve_target <= target;
            resolve_is_branch <= 1'b1;
            was_predicted_taken <= predicted;
            
            total_branches = total_branches + 1;
            
            if (predicted == taken) begin
                correct_predictions = correct_predictions + 1;
                $display("Branch PC=%h: Predicted=%b, Actual=%b [CORRECT] GHR=%b Counter=%d",
                        pc, predicted, taken, ghr, counter_value);
            end else begin
                mispredictions = mispredictions + 1;
                $display("Branch PC=%h: Predicted=%b, Actual=%b [WRONG]   GHR=%b Counter=%d",
                        pc, predicted, taken, ghr, counter_value);
            end
            
            @(posedge clk);
            resolve_valid <= 1'b0;
        end
    endtask
    
    // Test sequence
    initial begin
        $display("===========================================");
        $display("Branch Predictor Testbench (GShare)");
        $display("===========================================\n");
        
        // Initialize
        rst_n = 0;
        fetch_pc = 0;
        fetch_valid = 0;
        resolve_valid = 0;
        resolve_pc = 0;
        resolve_taken = 0;
        resolve_target = 0;
        resolve_is_branch = 0;
        was_predicted_taken = 0;
        total_branches = 0;
        correct_predictions = 0;
        mispredictions = 0;
        
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 1: Always taken loop (should learn pattern)
        $display("\nTest 1: Always-Taken Loop (10 iterations)");
        $display("-------------------------------------------");
        repeat(10) begin
            execute_branch(32'h00001000, 32'h00001100, 1'b1);
        end
        
        // Test 2: Never taken branch
        $display("\nTest 2: Never-Taken Branch (10 iterations)");
        $display("-------------------------------------------");
        repeat(10) begin
            execute_branch(32'h00002000, 32'h00002100, 1'b0);
        end
        
        // Test 3: Alternating pattern (T,N,T,N,...)
        $display("\nTest 3: Alternating Pattern (10 iterations)");
        $display("-------------------------------------------");
        repeat(10) begin
            execute_branch(32'h00003000, 32'h00003100, 1'b1);
            execute_branch(32'h00003000, 32'h00003100, 1'b0);
        end
        
        // Test 4: TTNNTTNNT... pattern (period 4)
        $display("\nTest 4: TTNN Repeating Pattern (12 iterations)");
        $display("-------------------------------------------");
        repeat(3) begin
            execute_branch(32'h00004000, 32'h00004100, 1'b1);
            execute_branch(32'h00004000, 32'h00004100, 1'b1);
            execute_branch(32'h00004000, 32'h00004100, 1'b0);
            execute_branch(32'h00004000, 32'h00004100, 1'b0);
        end
        
        // Test 5: Different PC addresses (independent branches)
        $display("\nTest 5: Multiple Independent Branches");
        $display("-------------------------------------------");
        repeat(5) begin
            execute_branch(32'h00005000, 32'h00005100, 1'b1);
            execute_branch(32'h00005040, 32'h00005140, 1'b0);
            execute_branch(32'h00005080, 32'h00005180, 1'b1);
        end
        
        repeat(10) @(posedge clk);
        
        // Print statistics
        $display("\n===========================================");
        $display("Branch Prediction Statistics");
        $display("===========================================");
        $display("Total Branches:       %0d", total_branches);
        $display("Correct Predictions:  %0d", correct_predictions);
        $display("Mispredictions:       %0d", mispredictions);
        $display("Accuracy:             %0.1f%%", 
                100.0 * correct_predictions / total_branches);
        $display("");
        $display("GHR Final State: %b", ghr);
        $display("");
        $display("View waveforms: gtkwave branch_predictor.vcd");
        $display("===========================================");
        
        $finish;
    end

endmodule
