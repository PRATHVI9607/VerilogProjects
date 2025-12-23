// Tomasulo Register Status Table
// Tracks which RS will produce value for each register

`include "tomasulo_pkg.v"

module register_status #(
    parameter NUM_REGS = 16,
    parameter TAG_WIDTH = 4
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Read interface (for issue)
    input  wire [3:0]  read_addr1,
    input  wire [3:0]  read_addr2,
    output wire [TAG_WIDTH-1:0] read_tag1,  // Tag of producer (0 if ready)
    output wire [TAG_WIDTH-1:0] read_tag2,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2,
    
    // Allocate (when instruction issues)
    input  wire        alloc_valid,
    input  wire [3:0]  alloc_rd,
    input  wire [TAG_WIDTH-1:0] alloc_tag,
    
    // CDB writeback (clears status when result produced)
    input  wire        cdb_valid,
    input  wire [TAG_WIDTH-1:0] cdb_tag,
    input  wire [31:0] cdb_data,
    
    // Status outputs
    output wire [TAG_WIDTH-1:0] qi [0:NUM_REGS-1]
);

    // Register file
    reg [31:0] regs [0:NUM_REGS-1];
    
    // Register status (Qi) - tag of RS producing value
    reg [TAG_WIDTH-1:0] status [0:NUM_REGS-1];
    
    // Read outputs
    assign read_tag1 = status[read_addr1];
    assign read_tag2 = status[read_addr2];
    assign read_data1 = regs[read_addr1];
    assign read_data2 = regs[read_addr2];
    
    // Status output
    genvar g;
    generate
        for (g = 0; g < NUM_REGS; g = g + 1) begin : gen_qi
            assign qi[g] = status[g];
        end
    endgenerate
    
    integer i;
    
    // Initialize
    initial begin
        for (i = 0; i < NUM_REGS; i = i + 1) begin
            regs[i] = i * 10;  // Initial test values
            status[i] = `TAG_NONE;
        end
    end
    
    // Update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                status[i] <= `TAG_NONE;
            end
        end else begin
            // CDB writeback - update register and clear status
            if (cdb_valid) begin
                for (i = 0; i < NUM_REGS; i = i + 1) begin
                    if (status[i] == cdb_tag) begin
                        regs[i] <= cdb_data;
                        status[i] <= `TAG_NONE;
                    end
                end
            end
            
            // Allocate new tag (after CDB check for same cycle)
            if (alloc_valid && alloc_rd != 4'b0) begin
                status[alloc_rd] <= alloc_tag;
            end
        end
    end

endmodule
