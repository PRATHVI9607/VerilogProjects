`timescale 1ns/1ps

// Direct-Mapped Cache
// 1KB cache with 32-byte blocks, write-back policy

module direct_mapped_cache (
    input  wire        clk,
    input  wire        rst_n,
    
    // CPU interface
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_read,
    input  wire        cpu_write,
    output reg  [31:0] cpu_rdata,
    output reg         cpu_ready,
    
    // Memory interface
    output reg  [31:0] mem_addr,
    output reg  [255:0] mem_wdata,   // 32-byte block
    output reg         mem_read,
    output reg         mem_write,
    input  wire [255:0] mem_rdata,
    input  wire        mem_ready,
    
    // Status outputs for visualization
    output wire        hit,
    output wire        miss,
    output wire        dirty_evict,
    output wire [4:0]  current_index,
    output wire [21:0] current_tag,
    output wire        valid_bit,
    output wire        dirty_bit
);

    // Cache storage
    // 32 sets x 32 bytes = 1024 bytes
    // Each set: valid(1) + dirty(1) + tag(22) + data(256) = 280 bits
    reg         valid [0:31];
    reg         dirty [0:31];
    reg  [21:0] tags  [0:31];
    reg  [255:0] data [0:31];  // 32 bytes = 256 bits per line
    
    // Address breakdown
    // [4:0]   - byte offset within block (5 bits for 32 bytes)
    // [9:5]   - index (5 bits for 32 sets)
    // [31:10] - tag (22 bits)
    wire [4:0]  offset = cpu_addr[4:0];
    wire [4:0]  index  = cpu_addr[9:5];
    wire [21:0] tag    = cpu_addr[31:10];
    
    // Cache lookup
    wire tag_match = (tags[index] == tag);
    wire cache_hit = valid[index] && tag_match;
    wire cache_miss = !cache_hit && (cpu_read || cpu_write);
    wire needs_writeback = valid[index] && dirty[index] && cache_miss;
    
    // Status outputs
    assign hit = cache_hit;
    assign miss = cache_miss;
    assign dirty_evict = needs_writeback;
    assign current_index = index;
    assign current_tag = tag;
    assign valid_bit = valid[index];
    assign dirty_bit = dirty[index];
    
    // FSM states
    localparam IDLE       = 3'd0;
    localparam COMPARE    = 3'd1;
    localparam WRITEBACK  = 3'd2;
    localparam ALLOCATE   = 3'd3;
    localparam UPDATE     = 3'd4;
    
    reg [2:0] state, next_state;
    reg [31:0] saved_addr;
    reg [31:0] saved_wdata;
    reg        saved_write;
    
    // Read data extraction based on offset
    wire [31:0] word_from_block;
    wire [2:0] word_select = offset[4:2];  // Which 32-bit word
    
    assign word_from_block = data[index][word_select*32 +: 32];
    
    // Initialize cache
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            valid[i] = 1'b0;
            dirty[i] = 1'b0;
            tags[i]  = 22'b0;
            data[i]  = 256'b0;
        end
    end
    
    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            saved_addr <= 32'b0;
            saved_wdata <= 32'b0;
            saved_write <= 1'b0;
        end else begin
            state <= next_state;
            if (state == IDLE && (cpu_read || cpu_write)) begin
                saved_addr <= cpu_addr;
                saved_wdata <= cpu_wdata;
                saved_write <= cpu_write;
            end
        end
    end
    
    // FSM combinational logic
    always @(*) begin
        next_state = state;
        cpu_ready = 1'b0;
        cpu_rdata = 32'b0;
        mem_addr = 32'b0;
        mem_wdata = 256'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        
        case (state)
            IDLE: begin
                if (cpu_read || cpu_write) begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                if (cache_hit) begin
                    // Hit - return data or update cache
                    cpu_ready = 1'b1;
                    if (!saved_write) begin
                        cpu_rdata = word_from_block;
                    end
                    next_state = IDLE;
                end else if (needs_writeback) begin
                    // Miss with dirty eviction
                    next_state = WRITEBACK;
                end else begin
                    // Miss without eviction
                    next_state = ALLOCATE;
                end
            end
            
            WRITEBACK: begin
                // Write dirty block to memory
                mem_addr = {tags[index], index, 5'b0};
                mem_wdata = data[index];
                mem_write = 1'b1;
                if (mem_ready) begin
                    next_state = ALLOCATE;
                end
            end
            
            ALLOCATE: begin
                // Read new block from memory
                mem_addr = {saved_addr[31:5], 5'b0};
                mem_read = 1'b1;
                if (mem_ready) begin
                    next_state = UPDATE;
                end
            end
            
            UPDATE: begin
                // Update complete - return to idle
                cpu_ready = 1'b1;
                if (!saved_write) begin
                    cpu_rdata = mem_rdata[word_select*32 +: 32];
                end
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Cache update logic
    always @(posedge clk) begin
        if (state == COMPARE && cache_hit && saved_write) begin
            // Write hit - update cache and set dirty
            data[index][word_select*32 +: 32] <= saved_wdata;
            dirty[index] <= 1'b1;
        end else if (state == UPDATE) begin
            // Allocate new block
            valid[index] <= 1'b1;
            tags[index] <= saved_addr[31:10];
            if (saved_write) begin
                // Write new data
                data[index] <= mem_rdata;
                data[index][word_select*32 +: 32] <= saved_wdata;
                dirty[index] <= 1'b1;
            end else begin
                data[index] <= mem_rdata;
                dirty[index] <= 1'b0;
            end
        end
    end

endmodule
