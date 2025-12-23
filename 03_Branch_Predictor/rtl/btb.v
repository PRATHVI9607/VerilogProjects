`timescale 1ns/1ps

// Branch Target Buffer (BTB)
// Caches branch target addresses

module branch_target_buffer (
    input  wire        clk,
    input  wire        rst_n,
    
    // Lookup interface
    input  wire [31:0] pc,
    input  wire        lookup_valid,
    output wire        btb_hit,
    output wire [31:0] target,
    output wire        is_branch,
    
    // Update interface
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire [31:0] update_target,
    input  wire        update_is_branch
);

    // BTB storage (64 entries, direct-mapped)
    reg        valid [0:63];
    reg [23:0] tags  [0:63];  // Tag bits
    reg [31:0] targets [0:63];
    reg        branch_type [0:63];  // 1 = conditional branch
    
    // Index and tag extraction
    wire [5:0]  lookup_index = pc[7:2];
    wire [23:0] lookup_tag   = pc[31:8];
    wire [5:0]  update_index = update_pc[7:2];
    wire [23:0] update_tag   = update_pc[31:8];
    
    // Lookup result
    assign btb_hit   = lookup_valid && valid[lookup_index] && 
                       (tags[lookup_index] == lookup_tag);
    assign target    = targets[lookup_index];
    assign is_branch = branch_type[lookup_index];
    
    // Initialize
    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            valid[i] = 1'b0;
            tags[i] = 24'b0;
            targets[i] = 32'b0;
            branch_type[i] = 1'b0;
        end
    end
    
    // Update BTB
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled by initial block in simulation
        end else if (update_valid) begin
            valid[update_index] <= 1'b1;
            tags[update_index] <= update_tag;
            targets[update_index] <= update_target;
            branch_type[update_index] <= update_is_branch;
        end
    end

endmodule
