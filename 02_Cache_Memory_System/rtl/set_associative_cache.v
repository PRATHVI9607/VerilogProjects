`timescale 1ns/1ps

// Set-Associative Cache (2-way)
// 1KB cache with 32-byte blocks, write-back policy, LRU replacement

module set_associative_cache (
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
    output reg  [255:0] mem_wdata,
    output reg         mem_read,
    output reg         mem_write,
    input  wire [255:0] mem_rdata,
    input  wire        mem_ready,
    
    // Status outputs for visualization
    output wire        hit,
    output wire        miss,
    output wire [1:0]  hit_way,
    output wire [3:0]  current_index,
    output wire [22:0] current_tag,
    output wire [1:0]  lru_way,
    output wire        dirty_evict
);

    // Cache storage - 2-way, 16 sets
    // Way 0
    reg         valid_0 [0:15];
    reg         dirty_0 [0:15];
    reg  [22:0] tags_0  [0:15];
    reg  [255:0] data_0 [0:15];
    
    // Way 1
    reg         valid_1 [0:15];
    reg         dirty_1 [0:15];
    reg  [22:0] tags_1  [0:15];
    reg  [255:0] data_1 [0:15];
    
    // LRU bits (0 = way 0 is LRU, 1 = way 1 is LRU)
    reg lru [0:15];
    
    // Address breakdown
    // [4:0]   - byte offset (5 bits)
    // [8:5]   - index (4 bits for 16 sets)
    // [31:9]  - tag (23 bits)
    wire [4:0]  offset = cpu_addr[4:0];
    wire [3:0]  index  = cpu_addr[8:5];
    wire [22:0] tag    = cpu_addr[31:9];
    
    // Way lookup
    wire way0_hit = valid_0[index] && (tags_0[index] == tag);
    wire way1_hit = valid_1[index] && (tags_1[index] == tag);
    wire cache_hit = way0_hit || way1_hit;
    wire cache_miss = !cache_hit && (cpu_read || cpu_write);
    
    // Determine which way hit
    wire [1:0] hit_way_int = way0_hit ? 2'd0 : (way1_hit ? 2'd1 : 2'd2);
    
    // LRU replacement selection
    wire replace_way = lru[index];
    wire needs_writeback = cache_miss && 
                          (replace_way ? (valid_1[index] && dirty_1[index]) :
                                        (valid_0[index] && dirty_0[index]));
    
    // Status outputs
    assign hit = cache_hit;
    assign miss = cache_miss;
    assign hit_way = hit_way_int;
    assign current_index = index;
    assign current_tag = tag;
    assign lru_way = {1'b0, lru[index]};
    assign dirty_evict = needs_writeback;
    
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
    reg        saved_replace_way;
    
    // Word selection
    wire [2:0] word_select = offset[4:2];
    
    // Read data from appropriate way
    wire [31:0] word_way0 = data_0[index][word_select*32 +: 32];
    wire [31:0] word_way1 = data_1[index][word_select*32 +: 32];
    wire [31:0] hit_data = way0_hit ? word_way0 : word_way1;
    
    // Initialize cache
    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            valid_0[i] = 1'b0;
            dirty_0[i] = 1'b0;
            tags_0[i]  = 23'b0;
            data_0[i]  = 256'b0;
            valid_1[i] = 1'b0;
            dirty_1[i] = 1'b0;
            tags_1[i]  = 23'b0;
            data_1[i]  = 256'b0;
            lru[i]     = 1'b0;
        end
    end
    
    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            saved_addr <= 32'b0;
            saved_wdata <= 32'b0;
            saved_write <= 1'b0;
            saved_replace_way <= 1'b0;
        end else begin
            state <= next_state;
            if (state == IDLE && (cpu_read || cpu_write)) begin
                saved_addr <= cpu_addr;
                saved_wdata <= cpu_wdata;
                saved_write <= cpu_write;
                saved_replace_way <= lru[index];
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
                    cpu_ready = 1'b1;
                    if (!saved_write) begin
                        cpu_rdata = hit_data;
                    end
                    next_state = IDLE;
                end else if (needs_writeback) begin
                    next_state = WRITEBACK;
                end else begin
                    next_state = ALLOCATE;
                end
            end
            
            WRITEBACK: begin
                if (saved_replace_way) begin
                    mem_addr = {tags_1[index], index, 5'b0};
                    mem_wdata = data_1[index];
                end else begin
                    mem_addr = {tags_0[index], index, 5'b0};
                    mem_wdata = data_0[index];
                end
                mem_write = 1'b1;
                if (mem_ready) begin
                    next_state = ALLOCATE;
                end
            end
            
            ALLOCATE: begin
                mem_addr = {saved_addr[31:5], 5'b0};
                mem_read = 1'b1;
                if (mem_ready) begin
                    next_state = UPDATE;
                end
            end
            
            UPDATE: begin
                cpu_ready = 1'b1;
                if (!saved_write) begin
                    cpu_rdata = mem_rdata[word_select*32 +: 32];
                end
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Cache and LRU update logic
    always @(posedge clk) begin
        // Update LRU on hit
        if (state == COMPARE && cache_hit) begin
            // Mark the OTHER way as LRU
            lru[index] <= way0_hit ? 1'b1 : 1'b0;
            
            // Handle write hit
            if (saved_write) begin
                if (way0_hit) begin
                    data_0[index][word_select*32 +: 32] <= saved_wdata;
                    dirty_0[index] <= 1'b1;
                end else begin
                    data_1[index][word_select*32 +: 32] <= saved_wdata;
                    dirty_1[index] <= 1'b1;
                end
            end
        end
        
        // Allocate new block
        if (state == UPDATE) begin
            if (saved_replace_way) begin
                // Replace way 1
                valid_1[index] <= 1'b1;
                tags_1[index] <= saved_addr[31:9];
                if (saved_write) begin
                    data_1[index] <= mem_rdata;
                    data_1[index][word_select*32 +: 32] <= saved_wdata;
                    dirty_1[index] <= 1'b1;
                end else begin
                    data_1[index] <= mem_rdata;
                    dirty_1[index] <= 1'b0;
                end
                lru[index] <= 1'b0;  // Way 0 is now LRU
            end else begin
                // Replace way 0
                valid_0[index] <= 1'b1;
                tags_0[index] <= saved_addr[31:9];
                if (saved_write) begin
                    data_0[index] <= mem_rdata;
                    data_0[index][word_select*32 +: 32] <= saved_wdata;
                    dirty_0[index] <= 1'b1;
                end else begin
                    data_0[index] <= mem_rdata;
                    dirty_0[index] <= 1'b0;
                end
                lru[index] <= 1'b1;  // Way 1 is now LRU
            end
        end
    end

endmodule
