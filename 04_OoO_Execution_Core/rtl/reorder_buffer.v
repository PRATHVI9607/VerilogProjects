// Reorder Buffer (ROB)
// Maintains program order for in-order commit

`include "ooo_pkg.v"

module reorder_buffer #(
    parameter ROB_SIZE = 16,
    parameter TAG_WIDTH = 6
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Allocate interface (from decode)
    input  wire        alloc_valid,
    input  wire [4:0]  alloc_rd,         // Architectural destination register
    input  wire [31:0] alloc_pc,         // PC for debugging
    output wire [TAG_WIDTH-1:0] alloc_tag,  // Assigned ROB entry (tag)
    output wire        alloc_ack,
    output wire        rob_full,
    
    // Complete interface (from execution units via CDB)
    input  wire        complete_valid,
    input  wire [TAG_WIDTH-1:0] complete_tag,
    input  wire [31:0] complete_data,
    input  wire        complete_exception,
    
    // Commit interface (to architectural state)
    output reg         commit_valid,
    output reg  [4:0]  commit_rd,
    output reg  [31:0] commit_data,
    output reg  [TAG_WIDTH-1:0] commit_tag,
    output wire        commit_exception,
    
    // Status outputs for visualization
    output wire [TAG_WIDTH-1:0] head_ptr,
    output wire [TAG_WIDTH-1:0] tail_ptr,
    output wire [$clog2(ROB_SIZE):0] rob_count
);

    // ROB entry storage
    reg [1:0]  state      [0:ROB_SIZE-1];  // Empty/Issued/Complete
    reg [4:0]  rd         [0:ROB_SIZE-1];  // Destination register
    reg [31:0] value      [0:ROB_SIZE-1];  // Result value
    reg [31:0] pc         [0:ROB_SIZE-1];  // PC for debugging
    reg        exception  [0:ROB_SIZE-1];  // Exception flag
    
    // Circular buffer pointers
    reg [TAG_WIDTH-1:0] head;  // Points to oldest entry (commit)
    reg [TAG_WIDTH-1:0] tail;  // Points to next free entry (allocate)
    reg [$clog2(ROB_SIZE):0] count;
    
    // Full/empty detection
    wire rob_empty = (count == 0);
    assign rob_full = (count == ROB_SIZE);
    
    // Status outputs
    assign head_ptr = head;
    assign tail_ptr = tail;
    assign rob_count = count;
    
    // Allocate
    assign alloc_tag = tail;
    assign alloc_ack = alloc_valid && !rob_full;
    
    // Commit logic
    wire head_complete = (state[head] == `ROB_COMPLETE);
    assign commit_exception = exception[head] && head_complete;
    
    integer i;
    
    // Initialize
    initial begin
        head = 0;
        tail = 0;
        count = 0;
        for (i = 0; i < ROB_SIZE; i = i + 1) begin
            state[i] = `ROB_EMPTY;
            rd[i] = 5'b0;
            value[i] = 32'b0;
            pc[i] = 32'b0;
            exception[i] = 1'b0;
        end
    end
    
    // ROB update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            commit_valid <= 1'b0;
            commit_rd <= 5'b0;
            commit_data <= 32'b0;
            commit_tag <= 0;
            for (i = 0; i < ROB_SIZE; i = i + 1) begin
                state[i] <= `ROB_EMPTY;
                rd[i] <= 5'b0;
                value[i] <= 32'b0;
                pc[i] <= 32'b0;
                exception[i] <= 1'b0;
            end
        end else begin
            commit_valid <= 1'b0;
            
            // Allocate new entry
            if (alloc_valid && !rob_full) begin
                state[tail] <= `ROB_ISSUED;
                rd[tail] <= alloc_rd;
                pc[tail] <= alloc_pc;
                value[tail] <= 32'b0;
                exception[tail] <= 1'b0;
                tail <= (tail + 1) % ROB_SIZE;
                count <= count + 1;
            end
            
            // Complete entry (result ready)
            if (complete_valid) begin
                if (state[complete_tag] == `ROB_ISSUED) begin
                    state[complete_tag] <= `ROB_COMPLETE;
                    value[complete_tag] <= complete_data;
                    exception[complete_tag] <= complete_exception;
                end
            end
            
            // Commit oldest entry if complete
            if (!rob_empty && head_complete && !exception[head]) begin
                commit_valid <= 1'b1;
                commit_rd <= rd[head];
                commit_data <= value[head];
                commit_tag <= head;
                state[head] <= `ROB_EMPTY;
                head <= (head + 1) % ROB_SIZE;
                count <= count - 1;
            end
            
            // Adjust count for simultaneous alloc/commit
            if ((alloc_valid && !rob_full) && 
                (!rob_empty && head_complete && !exception[head])) begin
                count <= count;  // No change
            end
        end
    end

endmodule
