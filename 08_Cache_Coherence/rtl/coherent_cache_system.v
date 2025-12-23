`timescale 1ns/1ps

// Multi-Processor Cache Coherence System - Top Module
// Integrates multiple MESI caches with snoop bus

module coherent_cache_system #(
    parameter NUM_CPUS = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CACHE_LINES = 64,
    parameter LINE_SIZE = 32
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // CPU interfaces (packed arrays)
    input  wire [NUM_CPUS*ADDR_WIDTH-1:0] cpu_addr,
    input  wire [NUM_CPUS-1:0] cpu_read,
    input  wire [NUM_CPUS-1:0] cpu_write,
    input  wire [NUM_CPUS*DATA_WIDTH-1:0] cpu_write_data,
    output wire [NUM_CPUS*DATA_WIDTH-1:0] cpu_read_data,
    output wire [NUM_CPUS-1:0] cpu_ready,
    output wire [NUM_CPUS-1:0] cpu_hit,
    
    // Main memory interface
    output wire        mem_read,
    output wire        mem_write,
    output wire [ADDR_WIDTH-1:0] mem_addr,
    output wire [LINE_SIZE*8-1:0] mem_write_data,
    input  wire [LINE_SIZE*8-1:0] mem_read_data,
    input  wire        mem_ready,
    
    // Debug/status
    output wire [NUM_CPUS*2-1:0] cache_state_dbg
);

    localparam LINE_BITS = LINE_SIZE * 8;
    localparam TAG_WIDTH = ADDR_WIDTH - $clog2(CACHE_LINES) - $clog2(LINE_SIZE);
    
    // Per-cache bus signals
    wire [NUM_CPUS-1:0] cache_bus_req;
    wire [NUM_CPUS*3-1:0] cache_bus_op;
    wire [NUM_CPUS*ADDR_WIDTH-1:0] cache_bus_addr;
    wire [NUM_CPUS*LINE_BITS-1:0] cache_bus_data;
    wire [NUM_CPUS-1:0] cache_bus_data_valid;
    wire [NUM_CPUS-1:0] cache_bus_grant;
    
    // Snoop signals
    wire [2:0] snoop_op;
    wire [ADDR_WIDTH-1:0] snoop_addr;
    wire [LINE_BITS-1:0] snoop_data;
    wire snoop_data_ready;
    wire snoop_shared;
    
    // Snoop responses
    wire [NUM_CPUS-1:0] snoop_hit;
    wire [NUM_CPUS-1:0] snoop_supply;
    wire [NUM_CPUS*LINE_BITS-1:0] snoop_data_out;
    
    // Extract individual CPU signals
    wire [ADDR_WIDTH-1:0] cpu_addr_arr [0:NUM_CPUS-1];
    wire [DATA_WIDTH-1:0] cpu_wdata_arr [0:NUM_CPUS-1];
    wire [DATA_WIDTH-1:0] cpu_rdata_arr [0:NUM_CPUS-1];
    
    genvar g;
    generate
        for (g = 0; g < NUM_CPUS; g = g + 1) begin : gen_extract
            assign cpu_addr_arr[g] = cpu_addr[g*ADDR_WIDTH +: ADDR_WIDTH];
            assign cpu_wdata_arr[g] = cpu_write_data[g*DATA_WIDTH +: DATA_WIDTH];
            assign cpu_read_data[g*DATA_WIDTH +: DATA_WIDTH] = cpu_rdata_arr[g];
        end
    endgenerate
    
    // Instantiate caches
    generate
        for (g = 0; g < NUM_CPUS; g = g + 1) begin : gen_caches
            wire [1:0] line_states [0:CACHE_LINES-1];
            
            mesi_cache #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .CACHE_LINES(CACHE_LINES),
                .LINE_SIZE(LINE_SIZE),
                .TAG_WIDTH(TAG_WIDTH)
            ) u_cache (
                .clk(clk),
                .rst_n(rst_n),
                
                // CPU interface
                .cpu_addr(cpu_addr_arr[g]),
                .cpu_read(cpu_read[g]),
                .cpu_write(cpu_write[g]),
                .cpu_write_data(cpu_wdata_arr[g]),
                .cpu_read_data(cpu_rdata_arr[g]),
                .cpu_ready(cpu_ready[g]),
                .cpu_hit(cpu_hit[g]),
                
                // Bus interface
                .bus_req(cache_bus_req[g]),
                .bus_op(cache_bus_op[g*3 +: 3]),
                .bus_addr(cache_bus_addr[g*ADDR_WIDTH +: ADDR_WIDTH]),
                .bus_data_out(cache_bus_data[g*LINE_BITS +: LINE_BITS]),
                .bus_data_valid(cache_bus_data_valid[g]),
                
                .bus_grant(cache_bus_grant[g]),
                .bus_snoop_op(snoop_op),
                .bus_snoop_addr(snoop_addr),
                .bus_data_in(snoop_data),
                .bus_data_ready(snoop_data_ready),
                .bus_shared(snoop_shared),
                
                .cache_state()
            );
            
            // Snoop response logic would need additional ports
            // For simplicity, connect snoop signals
            assign snoop_hit[g] = 1'b0; // Simplified - would need actual snoop logic
            assign snoop_supply[g] = 1'b0;
            assign snoop_data_out[g*LINE_BITS +: LINE_BITS] = 0;
        end
    endgenerate
    
    // Snoop bus instance
    snoop_bus #(
        .NUM_CPUS(NUM_CPUS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(LINE_BITS)
    ) u_snoop_bus (
        .clk(clk),
        .rst_n(rst_n),
        
        // Cache interfaces
        .bus_req(cache_bus_req),
        .bus_op(cache_bus_op),
        .bus_addr(cache_bus_addr),
        .bus_data(cache_bus_data),
        .bus_data_valid(cache_bus_data_valid),
        
        .bus_grant(cache_bus_grant),
        .snoop_op(snoop_op),
        .snoop_addr(snoop_addr),
        .snoop_data(snoop_data),
        .snoop_data_ready(snoop_data_ready),
        .snoop_shared(snoop_shared),
        
        // Snoop responses
        .snoop_hit(snoop_hit),
        .snoop_supply(snoop_supply),
        .snoop_data_in(snoop_data_out),
        
        // Memory interface
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_addr(mem_addr),
        .mem_write_data(mem_write_data),
        .mem_read_data(mem_read_data),
        .mem_ready(mem_ready)
    );
    
    // Debug output (first line state from each cache)
    assign cache_state_dbg = 0; // Would connect to actual cache states

endmodule
