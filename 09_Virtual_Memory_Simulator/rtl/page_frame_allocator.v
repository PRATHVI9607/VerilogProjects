`timescale 1ns/1ps

// Page Frame Allocator
// Manages physical page allocation with free list

module page_frame_allocator #(
    parameter NUM_FRAMES = 256,
    parameter FRAME_BITS = 8  // log2(NUM_FRAMES)
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Allocation interface
    input  wire        alloc_req,
    output wire        alloc_valid,
    output wire [FRAME_BITS-1:0] alloc_frame,
    
    // Deallocation interface
    input  wire        dealloc_req,
    input  wire [FRAME_BITS-1:0] dealloc_frame,
    output wire        dealloc_valid,
    
    // Status
    output wire [FRAME_BITS:0] free_count,
    output wire        out_of_memory
);

    // Free frame bitmap
    reg [NUM_FRAMES-1:0] frame_free;
    reg [FRAME_BITS:0] free_counter;
    
    // Find first free frame (priority encoder)
    reg [FRAME_BITS-1:0] first_free;
    reg found_free;
    
    integer i;
    always @(*) begin
        first_free = 0;
        found_free = 0;
        for (i = 0; i < NUM_FRAMES; i = i + 1) begin
            if (frame_free[i] && !found_free) begin
                first_free = i[FRAME_BITS-1:0];
                found_free = 1;
            end
        end
    end
    
    // Allocation logic
    assign alloc_valid = alloc_req && found_free;
    assign alloc_frame = first_free;
    
    // Deallocation logic
    assign dealloc_valid = dealloc_req && !frame_free[dealloc_frame];
    
    // Status
    assign free_count = free_counter;
    assign out_of_memory = (free_counter == 0);
    
    // State update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // All frames start free
            frame_free <= {NUM_FRAMES{1'b1}};
            free_counter <= NUM_FRAMES;
        end else begin
            // Handle allocation
            if (alloc_valid) begin
                frame_free[first_free] <= 1'b0;
                free_counter <= free_counter - 1;
            end
            
            // Handle deallocation
            if (dealloc_valid) begin
                frame_free[dealloc_frame] <= 1'b1;
                free_counter <= free_counter + 1;
            end
        end
    end

endmodule
