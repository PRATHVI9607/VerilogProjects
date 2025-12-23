`timescale 1ns/1ps

// MESI Cache Line State Machine
// Implements Modified, Exclusive, Shared, Invalid states

module mesi_cache_line #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter TAG_WIDTH = 20,
    parameter LINE_SIZE = 32  // bytes per cache line
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Current state
    output wire [1:0]  state,
    output wire        valid,
    output wire        dirty,
    
    // Tag and data storage
    output wire [TAG_WIDTH-1:0] tag,
    output wire [LINE_SIZE*8-1:0] data,
    
    // Local CPU request
    input  wire        cpu_read,
    input  wire        cpu_write,
    input  wire [TAG_WIDTH-1:0] cpu_tag,
    input  wire [DATA_WIDTH-1:0] cpu_write_data,
    input  wire [$clog2(LINE_SIZE/4)-1:0] cpu_word_sel,
    output wire        cpu_hit,
    output wire [DATA_WIDTH-1:0] cpu_read_data,
    
    // Snoop request from bus (other CPUs)
    input  wire        snoop_read,      // BusRd
    input  wire        snoop_read_x,    // BusRdX (read with intent to modify)
    input  wire        snoop_upgrade,   // BusUpgr
    input  wire [TAG_WIDTH-1:0] snoop_tag,
    output wire        snoop_hit,
    output wire        snoop_supply_data, // Need to supply data on bus
    
    // Memory/Bus interface
    input  wire        fill_valid,
    input  wire [LINE_SIZE*8-1:0] fill_data,
    input  wire        fill_exclusive,  // No other cache has copy
    input  wire [TAG_WIDTH-1:0] fill_tag,
    
    output wire        writeback_needed,
    output wire [LINE_SIZE*8-1:0] writeback_data,
    output wire [TAG_WIDTH-1:0] writeback_tag
);

    // MESI States
    localparam INVALID   = 2'b00;
    localparam SHARED    = 2'b01;
    localparam EXCLUSIVE = 2'b10;
    localparam MODIFIED  = 2'b11;
    
    // State register
    reg [1:0] state_reg, state_next;
    reg [TAG_WIDTH-1:0] tag_reg;
    reg [LINE_SIZE*8-1:0] data_reg;
    
    // Tag comparison
    wire tag_match = (tag_reg == cpu_tag);
    wire snoop_tag_match = (tag_reg == snoop_tag);
    
    // Hit detection
    assign cpu_hit = tag_match && (state_reg != INVALID);
    assign snoop_hit = snoop_tag_match && (state_reg != INVALID);
    
    // State outputs
    assign state = state_reg;
    assign valid = (state_reg != INVALID);
    assign dirty = (state_reg == MODIFIED);
    assign tag = tag_reg;
    assign data = data_reg;
    
    // Read data mux
    wire [DATA_WIDTH-1:0] word_array [0:(LINE_SIZE/4)-1];
    genvar g;
    generate
        for (g = 0; g < LINE_SIZE/4; g = g + 1) begin : gen_words
            assign word_array[g] = data_reg[g*32 +: 32];
        end
    endgenerate
    assign cpu_read_data = word_array[cpu_word_sel];
    
    // Writeback signals
    assign writeback_needed = (state_reg == MODIFIED);
    assign writeback_data = data_reg;
    assign writeback_tag = tag_reg;
    
    // Snoop response - supply data if Modified or Exclusive
    assign snoop_supply_data = snoop_hit && (state_reg == MODIFIED || state_reg == EXCLUSIVE);
    
    // State machine
    always @(*) begin
        state_next = state_reg;
        
        // Priority: Snoop > CPU > Fill
        if (snoop_hit) begin
            case (state_reg)
                MODIFIED: begin
                    if (snoop_read || snoop_read_x) begin
                        // Other CPU wants data - go to Shared or Invalid
                        state_next = snoop_read_x ? INVALID : SHARED;
                    end
                end
                
                EXCLUSIVE: begin
                    if (snoop_read) begin
                        state_next = SHARED;
                    end else if (snoop_read_x) begin
                        state_next = INVALID;
                    end
                end
                
                SHARED: begin
                    if (snoop_read_x || snoop_upgrade) begin
                        state_next = INVALID;
                    end
                end
                
                default: ; // INVALID - no action
            endcase
        end else if (cpu_hit) begin
            case (state_reg)
                EXCLUSIVE: begin
                    if (cpu_write) begin
                        state_next = MODIFIED;
                    end
                end
                
                SHARED: begin
                    if (cpu_write) begin
                        // Need BusUpgr - handled externally
                        state_next = MODIFIED;
                    end
                end
                
                default: ; // MODIFIED stays MODIFIED, INVALID handled by fill
            endcase
        end else if (fill_valid) begin
            // Cache line fill
            if (fill_exclusive) begin
                state_next = EXCLUSIVE;
            end else begin
                state_next = SHARED;
            end
        end
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= INVALID;
            tag_reg <= 0;
            data_reg <= 0;
        end else begin
            state_reg <= state_next;
            
            // Update tag on fill
            if (fill_valid) begin
                tag_reg <= fill_tag;
                data_reg <= fill_data;
            end
            
            // Update data on CPU write (if hit)
            if (cpu_write && cpu_hit) begin
                data_reg[cpu_word_sel*32 +: 32] <= cpu_write_data;
            end
            
            // Clear on invalidation
            if (snoop_hit && state_next == INVALID) begin
                // Optionally keep data for writeback, but mark invalid
            end
        end
    end

endmodule
