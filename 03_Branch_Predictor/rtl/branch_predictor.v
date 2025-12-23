`timescale 1ns/1ps

// Branch Predictor Top Module
// Combines GShare predictor with BTB

module branch_predictor (
    input  wire        clk,
    input  wire        rst_n,
    
    // Prediction interface (from IF stage)
    input  wire [31:0] fetch_pc,
    input  wire        fetch_valid,
    output wire        predict_taken,
    output wire [31:0] predict_target,
    output wire        predict_valid,
    
    // Resolution interface (from EX stage)
    input  wire        resolve_valid,
    input  wire [31:0] resolve_pc,
    input  wire        resolve_taken,
    input  wire [31:0] resolve_target,
    input  wire        resolve_is_branch,
    input  wire        was_predicted_taken,
    
    // Statistics and visualization
    output wire [7:0]  ghr,
    output wire [7:0]  pht_index,
    output wire [1:0]  counter_value,
    output wire        misprediction,
    output wire        btb_hit_out
);

    // GShare predictor signals
    wire gshare_taken;
    wire gshare_valid;
    
    // BTB signals
    wire btb_hit;
    wire [31:0] btb_target;
    wire btb_is_branch;
    
    // GShare Predictor
    gshare_predictor u_gshare (
        .clk              (clk),
        .rst_n            (rst_n),
        .pc               (fetch_pc),
        .predict_request  (fetch_valid),
        .prediction       (gshare_valid),
        .predicted_taken  (gshare_taken),
        .update_valid     (resolve_valid && resolve_is_branch),
        .update_pc        (resolve_pc),
        .update_taken     (resolve_taken),
        .update_predicted (was_predicted_taken),
        .ghr_out          (ghr),
        .pht_index_out    (pht_index),
        .counter_value    (counter_value),
        .misprediction    (misprediction)
    );
    
    // Branch Target Buffer
    branch_target_buffer u_btb (
        .clk             (clk),
        .rst_n           (rst_n),
        .pc              (fetch_pc),
        .lookup_valid    (fetch_valid),
        .btb_hit         (btb_hit),
        .target          (btb_target),
        .is_branch       (btb_is_branch),
        .update_valid    (resolve_valid),
        .update_pc       (resolve_pc),
        .update_target   (resolve_target),
        .update_is_branch(resolve_is_branch)
    );
    
    // Combined prediction output
    // Predict taken only if BTB hits and GShare predicts taken
    assign predict_valid  = fetch_valid && btb_hit;
    assign predict_taken  = btb_hit && gshare_taken;
    assign predict_target = btb_target;
    assign btb_hit_out    = btb_hit;

endmodule
