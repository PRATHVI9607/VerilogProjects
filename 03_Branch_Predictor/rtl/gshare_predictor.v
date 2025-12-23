`timescale 1ns/1ps

// GShare Branch Predictor
// 8-bit global history, 256-entry 2-bit saturating counters

module gshare_predictor (
    input  wire        clk,
    input  wire        rst_n,
    
    // Prediction interface
    input  wire [31:0] pc,
    input  wire        predict_request,
    output wire        prediction,
    output wire        predicted_taken,
    
    // Update interface (from branch resolution)
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire        update_taken,      // Actual branch outcome
    input  wire        update_predicted,  // What was predicted
    
    // Status outputs for visualization
    output wire [7:0]  ghr_out,           // Global History Register
    output wire [7:0]  pht_index_out,     // PHT index used
    output wire [1:0]  counter_value,     // Current counter value
    output wire        misprediction      // Misprediction occurred
);

    // 2-bit saturating counter states
    localparam SN = 2'b00;  // Strongly Not Taken
    localparam WN = 2'b01;  // Weakly Not Taken
    localparam WT = 2'b10;  // Weakly Taken
    localparam ST = 2'b11;  // Strongly Taken
    
    // Global History Register (8 bits)
    reg [7:0] ghr;
    
    // Pattern History Table (256 entries x 2 bits)
    reg [1:0] pht [0:255];
    
    // Prediction logic
    wire [7:0] pred_index = pc[9:2] ^ ghr;  // XOR PC bits with GHR
    wire [1:0] pred_counter = pht[pred_index];
    
    // Prediction: taken if counter >= 2 (WT or ST)
    assign prediction = predict_request;
    assign predicted_taken = pred_counter[1];  // MSB indicates taken/not-taken
    
    // Update logic
    wire [7:0] update_index = update_pc[9:2] ^ ghr;
    
    // Status outputs
    assign ghr_out = ghr;
    assign pht_index_out = predict_request ? pred_index : update_index;
    assign counter_value = pht[pht_index_out];
    assign misprediction = update_valid && (update_taken != update_predicted);
    
    // Initialize
    integer i;
    initial begin
        ghr = 8'b0;
        for (i = 0; i < 256; i = i + 1) begin
            pht[i] = WN;  // Initialize to weakly not taken
        end
    end
    
    // Update GHR and PHT
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ghr <= 8'b0;
        end else if (update_valid) begin
            // Shift in actual outcome to GHR
            ghr <= {ghr[6:0], update_taken};
            
            // Update PHT counter with saturating arithmetic
            case (pht[update_index])
                SN: pht[update_index] <= update_taken ? WN : SN;
                WN: pht[update_index] <= update_taken ? WT : SN;
                WT: pht[update_index] <= update_taken ? ST : WN;
                ST: pht[update_index] <= update_taken ? ST : WT;
            endcase
        end
    end

endmodule
