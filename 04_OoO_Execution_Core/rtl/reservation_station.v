// Reservation Station Entry
// Holds pending instructions waiting for operands

`include "ooo_pkg.v"

module reservation_station #(
    parameter NUM_ENTRIES = 4,
    parameter TAG_WIDTH = 6
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Issue interface (from dispatch)
    input  wire        issue_valid,
    input  wire [2:0]  issue_op,
    input  wire [31:0] issue_val1,
    input  wire [31:0] issue_val2,
    input  wire [TAG_WIDTH-1:0] issue_tag1,
    input  wire [TAG_WIDTH-1:0] issue_tag2,
    input  wire        issue_ready1,     // Operand 1 ready
    input  wire        issue_ready2,     // Operand 2 ready
    input  wire [TAG_WIDTH-1:0] issue_dest_tag,  // ROB tag for result
    output wire        issue_ack,        // RS accepted instruction
    output wire        rs_full,
    
    // CDB broadcast (for wakeup)
    input  wire        cdb_valid,
    input  wire [TAG_WIDTH-1:0] cdb_tag,
    input  wire [31:0] cdb_data,
    
    // Dispatch to execution unit
    output reg         dispatch_valid,
    output reg  [2:0]  dispatch_op,
    output reg  [31:0] dispatch_val1,
    output reg  [31:0] dispatch_val2,
    output reg  [TAG_WIDTH-1:0] dispatch_dest_tag,
    input  wire        dispatch_ack,     // Execution unit accepted
    
    // Status outputs for visualization
    output wire [NUM_ENTRIES-1:0] entry_busy,
    output wire [NUM_ENTRIES-1:0] entry_ready
);

    // RS entry storage
    reg                  busy      [0:NUM_ENTRIES-1];
    reg [2:0]            op        [0:NUM_ENTRIES-1];
    reg [31:0]           val1      [0:NUM_ENTRIES-1];
    reg [31:0]           val2      [0:NUM_ENTRIES-1];
    reg [TAG_WIDTH-1:0]  tag1      [0:NUM_ENTRIES-1];
    reg [TAG_WIDTH-1:0]  tag2      [0:NUM_ENTRIES-1];
    reg                  ready1    [0:NUM_ENTRIES-1];
    reg                  ready2    [0:NUM_ENTRIES-1];
    reg [TAG_WIDTH-1:0]  dest_tag  [0:NUM_ENTRIES-1];
    
    // Find free entry (for issue)
    reg [$clog2(NUM_ENTRIES)-1:0] free_entry;
    reg free_found;
    
    // Find ready entry (for dispatch)
    reg [$clog2(NUM_ENTRIES)-1:0] ready_entry;
    reg ready_found;
    
    integer i;
    
    // Free entry finder
    always @(*) begin
        free_found = 1'b0;
        free_entry = 0;
        for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
            if (!busy[i] && !free_found) begin
                free_found = 1'b1;
                free_entry = i;
            end
        end
    end
    
    // Ready entry finder (oldest first for fairness)
    always @(*) begin
        ready_found = 1'b0;
        ready_entry = 0;
        for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
            if (busy[i] && ready1[i] && ready2[i] && !ready_found) begin
                ready_found = 1'b1;
                ready_entry = i;
            end
        end
    end
    
    // Status outputs
    assign rs_full = !free_found;
    assign issue_ack = issue_valid && free_found;
    
    genvar g;
    generate
        for (g = 0; g < NUM_ENTRIES; g = g + 1) begin : gen_status
            assign entry_busy[g] = busy[g];
            assign entry_ready[g] = busy[g] && ready1[g] && ready2[g];
        end
    endgenerate
    
    // Dispatch output
    always @(*) begin
        dispatch_valid = ready_found;
        if (ready_found) begin
            dispatch_op = op[ready_entry];
            dispatch_val1 = val1[ready_entry];
            dispatch_val2 = val2[ready_entry];
            dispatch_dest_tag = dest_tag[ready_entry];
        end else begin
            dispatch_op = 0;
            dispatch_val1 = 0;
            dispatch_val2 = 0;
            dispatch_dest_tag = 0;
        end
    end
    
    // RS update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
                busy[i]     <= 1'b0;
                op[i]       <= 3'b0;
                val1[i]     <= 32'b0;
                val2[i]     <= 32'b0;
                tag1[i]     <= {TAG_WIDTH{1'b0}};
                tag2[i]     <= {TAG_WIDTH{1'b0}};
                ready1[i]   <= 1'b0;
                ready2[i]   <= 1'b0;
                dest_tag[i] <= {TAG_WIDTH{1'b0}};
            end
        end else begin
            // Issue new instruction
            if (issue_valid && free_found) begin
                busy[free_entry]     <= 1'b1;
                op[free_entry]       <= issue_op;
                val1[free_entry]     <= issue_val1;
                val2[free_entry]     <= issue_val2;
                tag1[free_entry]     <= issue_tag1;
                tag2[free_entry]     <= issue_tag2;
                ready1[free_entry]   <= issue_ready1;
                ready2[free_entry]   <= issue_ready2;
                dest_tag[free_entry] <= issue_dest_tag;
            end
            
            // Dispatch ready instruction
            if (ready_found && dispatch_ack) begin
                busy[ready_entry] <= 1'b0;
            end
            
            // CDB wakeup - update waiting operands
            if (cdb_valid) begin
                for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
                    if (busy[i]) begin
                        // Match tag1
                        if (!ready1[i] && (tag1[i] == cdb_tag)) begin
                            val1[i] <= cdb_data;
                            ready1[i] <= 1'b1;
                        end
                        // Match tag2
                        if (!ready2[i] && (tag2[i] == cdb_tag)) begin
                            val2[i] <= cdb_data;
                            ready2[i] <= 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
