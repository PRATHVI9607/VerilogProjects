`timescale 1ns/1ps

// Page Replacement Module
// Implements FIFO, LRU, and Clock replacement policies

module page_replacement #(
    parameter NUM_FRAMES = 256,
    parameter FRAME_BITS = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Configuration
    input  wire [1:0]  policy, // 00: FIFO, 01: LRU, 10: Clock
    
    // Frame access notification
    input  wire        frame_accessed,
    input  wire [FRAME_BITS-1:0] accessed_frame,
    
    // Frame allocation notification
    input  wire        frame_allocated,
    input  wire [FRAME_BITS-1:0] allocated_frame,
    
    // Victim selection
    input  wire        select_victim,
    output wire [FRAME_BITS-1:0] victim_frame,
    output wire        victim_valid
);

    // Policy encodings
    localparam FIFO  = 2'b00;
    localparam LRU   = 2'b01;
    localparam CLOCK = 2'b10;
    
    // FIFO queue
    reg [FRAME_BITS-1:0] fifo_queue [0:NUM_FRAMES-1];
    reg [FRAME_BITS-1:0] fifo_head, fifo_tail;
    reg [FRAME_BITS:0] fifo_count;
    
    // LRU tracking (timestamp-based)
    reg [15:0] lru_timestamp [0:NUM_FRAMES-1];
    reg [15:0] global_time;
    
    // Clock algorithm
    reg [NUM_FRAMES-1:0] reference_bits;
    reg [FRAME_BITS-1:0] clock_hand;
    
    // Frame valid tracking
    reg [NUM_FRAMES-1:0] frame_valid;
    
    // FIFO victim
    wire [FRAME_BITS-1:0] fifo_victim = fifo_queue[fifo_head];
    
    // LRU victim (find oldest timestamp)
    reg [FRAME_BITS-1:0] lru_victim;
    reg [15:0] min_timestamp;
    
    integer i;
    always @(*) begin
        lru_victim = 0;
        min_timestamp = 16'hFFFF;
        for (i = 0; i < NUM_FRAMES; i = i + 1) begin
            if (frame_valid[i] && lru_timestamp[i] < min_timestamp) begin
                min_timestamp = lru_timestamp[i];
                lru_victim = i[FRAME_BITS-1:0];
            end
        end
    end
    
    // Clock victim (scan for reference bit = 0)
    reg [FRAME_BITS-1:0] clock_victim;
    reg clock_found;
    
    always @(*) begin
        clock_victim = clock_hand;
        clock_found = 0;
        for (i = 0; i < NUM_FRAMES; i = i + 1) begin
            if (!clock_found) begin
                if (frame_valid[(clock_hand + i) % NUM_FRAMES] && 
                    !reference_bits[(clock_hand + i) % NUM_FRAMES]) begin
                    clock_victim = (clock_hand + i) % NUM_FRAMES;
                    clock_found = 1;
                end
            end
        end
    end
    
    // Victim selection mux
    reg [FRAME_BITS-1:0] selected_victim;
    always @(*) begin
        case (policy)
            FIFO:  selected_victim = fifo_victim;
            LRU:   selected_victim = lru_victim;
            CLOCK: selected_victim = clock_victim;
            default: selected_victim = 0;
        endcase
    end
    
    assign victim_frame = selected_victim;
    assign victim_valid = |frame_valid;
    
    // State updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_head <= 0;
            fifo_tail <= 0;
            fifo_count <= 0;
            global_time <= 0;
            clock_hand <= 0;
            reference_bits <= 0;
            frame_valid <= 0;
            
            for (i = 0; i < NUM_FRAMES; i = i + 1) begin
                fifo_queue[i] <= 0;
                lru_timestamp[i] <= 0;
            end
        end else begin
            // Increment global time
            global_time <= global_time + 1;
            
            // Handle frame allocation
            if (frame_allocated) begin
                frame_valid[allocated_frame] <= 1'b1;
                
                // FIFO: add to queue
                fifo_queue[fifo_tail] <= allocated_frame;
                fifo_tail <= (fifo_tail + 1) % NUM_FRAMES;
                fifo_count <= fifo_count + 1;
                
                // LRU: set timestamp
                lru_timestamp[allocated_frame] <= global_time;
                
                // Clock: set reference bit
                reference_bits[allocated_frame] <= 1'b1;
            end
            
            // Handle frame access (for LRU/Clock)
            if (frame_accessed && frame_valid[accessed_frame]) begin
                // LRU: update timestamp
                lru_timestamp[accessed_frame] <= global_time;
                
                // Clock: set reference bit
                reference_bits[accessed_frame] <= 1'b1;
            end
            
            // Handle victim selection
            if (select_victim && victim_valid) begin
                frame_valid[selected_victim] <= 1'b0;
                
                // FIFO: advance head
                if (policy == FIFO) begin
                    fifo_head <= (fifo_head + 1) % NUM_FRAMES;
                    fifo_count <= fifo_count - 1;
                end
                
                // Clock: advance hand and clear reference bits
                if (policy == CLOCK) begin
                    // Clear bits as we scan
                    for (i = 0; i < NUM_FRAMES; i = i + 1) begin
                        if (i < ((clock_victim - clock_hand + NUM_FRAMES) % NUM_FRAMES)) begin
                            reference_bits[(clock_hand + i) % NUM_FRAMES] <= 1'b0;
                        end
                    end
                    clock_hand <= (clock_victim + 1) % NUM_FRAMES;
                end
            end
        end
    end

endmodule
