`timescale 1ns/1ps

// Snoop Bus for Cache Coherence
// Arbitrates bus access and broadcasts snoop requests

module snoop_bus #(
    parameter NUM_CPUS = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 256  // Line size in bits
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // CPU cache interfaces (arrays)
    input  wire [NUM_CPUS-1:0] bus_req,
    input  wire [NUM_CPUS*3-1:0] bus_op,        // 3 bits per CPU
    input  wire [NUM_CPUS*ADDR_WIDTH-1:0] bus_addr,
    input  wire [NUM_CPUS*DATA_WIDTH-1:0] bus_data,
    input  wire [NUM_CPUS-1:0] bus_data_valid,
    
    output wire [NUM_CPUS-1:0] bus_grant,
    output wire [2:0]  snoop_op,
    output wire [ADDR_WIDTH-1:0] snoop_addr,
    output wire [DATA_WIDTH-1:0] snoop_data,
    output wire        snoop_data_ready,
    output wire        snoop_shared,
    
    // Snoop responses from caches
    input  wire [NUM_CPUS-1:0] snoop_hit,       // Cache has the line
    input  wire [NUM_CPUS-1:0] snoop_supply,    // Cache will supply data
    input  wire [NUM_CPUS*DATA_WIDTH-1:0] snoop_data_in,
    
    // Memory interface
    output wire        mem_read,
    output wire        mem_write,
    output wire [ADDR_WIDTH-1:0] mem_addr,
    output wire [DATA_WIDTH-1:0] mem_write_data,
    input  wire [DATA_WIDTH-1:0] mem_read_data,
    input  wire        mem_ready
);

    // Bus states
    localparam BUS_IDLE     = 3'd0;
    localparam BUS_ARBITRATE = 3'd1;
    localparam BUS_SNOOP    = 3'd2;
    localparam BUS_RESPONSE = 3'd3;
    localparam BUS_MEM_READ = 3'd4;
    localparam BUS_MEM_WRITE = 3'd5;
    localparam BUS_COMPLETE = 3'd6;
    
    reg [2:0] state, next_state;
    
    // Bus owner
    reg [$clog2(NUM_CPUS)-1:0] owner;
    reg [NUM_CPUS-1:0] grant_reg;
    
    // Captured request
    reg [2:0] captured_op;
    reg [ADDR_WIDTH-1:0] captured_addr;
    reg [DATA_WIDTH-1:0] captured_data;
    reg captured_data_valid;
    
    // Snoop result
    reg any_snoop_hit;
    reg any_supply;
    reg [DATA_WIDTH-1:0] supply_data;
    
    // Extract per-CPU signals
    wire [2:0] cpu_op [0:NUM_CPUS-1];
    wire [ADDR_WIDTH-1:0] cpu_addr [0:NUM_CPUS-1];
    wire [DATA_WIDTH-1:0] cpu_data [0:NUM_CPUS-1];
    wire [DATA_WIDTH-1:0] cpu_snoop_data [0:NUM_CPUS-1];
    
    genvar g;
    generate
        for (g = 0; g < NUM_CPUS; g = g + 1) begin : gen_extract
            assign cpu_op[g] = bus_op[g*3 +: 3];
            assign cpu_addr[g] = bus_addr[g*ADDR_WIDTH +: ADDR_WIDTH];
            assign cpu_data[g] = bus_data[g*DATA_WIDTH +: DATA_WIDTH];
            assign cpu_snoop_data[g] = snoop_data_in[g*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate
    
    // Round-robin arbiter
    reg [$clog2(NUM_CPUS)-1:0] priority_ptr;
    
    function [$clog2(NUM_CPUS)-1:0] find_next_request;
        input [NUM_CPUS-1:0] requests;
        input [$clog2(NUM_CPUS)-1:0] start;
        integer i, idx;
        reg found;
        begin
            find_next_request = start;
            found = 0;
            for (i = 0; i < NUM_CPUS; i = i + 1) begin
                idx = (start + i) % NUM_CPUS;
                if (requests[idx] && !found) begin
                    find_next_request = idx[$clog2(NUM_CPUS)-1:0];
                    found = 1;
                end
            end
        end
    endfunction
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= BUS_IDLE;
            owner <= 0;
            grant_reg <= 0;
            priority_ptr <= 0;
            captured_op <= 0;
            captured_addr <= 0;
            captured_data <= 0;
            captured_data_valid <= 0;
            any_snoop_hit <= 0;
            any_supply <= 0;
            supply_data <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                BUS_IDLE: begin
                    grant_reg <= 0;
                    if (|bus_req) begin
                        owner <= find_next_request(bus_req, priority_ptr);
                    end
                end
                
                BUS_ARBITRATE: begin
                    grant_reg <= (1 << owner);
                    captured_op <= cpu_op[owner];
                    captured_addr <= cpu_addr[owner];
                    captured_data <= cpu_data[owner];
                    captured_data_valid <= bus_data_valid[owner];
                    priority_ptr <= (owner + 1) % NUM_CPUS;
                end
                
                BUS_SNOOP: begin
                    // Collect snoop responses (combinational in practice, but register for timing)
                    any_snoop_hit <= |snoop_hit;
                    any_supply <= |snoop_supply;
                    
                    // Select supplying cache's data
                    begin : find_supplier
                        integer i;
                        for (i = 0; i < NUM_CPUS; i = i + 1) begin
                            if (snoop_supply[i] && i != owner) begin
                                supply_data <= cpu_snoop_data[i];
                            end
                        end
                    end
                end
                
                BUS_RESPONSE: begin
                    // Data ready from snoop or need memory access
                end
                
                BUS_MEM_READ: begin
                    // Wait for memory
                end
                
                BUS_MEM_WRITE: begin
                    // Writeback to memory
                end
                
                BUS_COMPLETE: begin
                    grant_reg <= 0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            BUS_IDLE: begin
                if (|bus_req) begin
                    next_state = BUS_ARBITRATE;
                end
            end
            
            BUS_ARBITRATE: begin
                next_state = BUS_SNOOP;
            end
            
            BUS_SNOOP: begin
                next_state = BUS_RESPONSE;
            end
            
            BUS_RESPONSE: begin
                if (captured_op == 3'b000) begin
                    // Writeback
                    next_state = BUS_MEM_WRITE;
                end else if (any_supply) begin
                    // Another cache supplies data
                    next_state = BUS_COMPLETE;
                end else begin
                    // Need memory read
                    next_state = BUS_MEM_READ;
                end
            end
            
            BUS_MEM_READ: begin
                if (mem_ready) begin
                    next_state = BUS_COMPLETE;
                end
            end
            
            BUS_MEM_WRITE: begin
                if (mem_ready) begin
                    // Check if we also need to read
                    if (captured_op == 3'b001 || captured_op == 3'b010) begin
                        next_state = BUS_MEM_READ;
                    end else begin
                        next_state = BUS_COMPLETE;
                    end
                end
            end
            
            BUS_COMPLETE: begin
                next_state = BUS_IDLE;
            end
        endcase
    end
    
    // Output assignments
    assign bus_grant = grant_reg;
    assign snoop_op = captured_op;
    assign snoop_addr = captured_addr;
    assign snoop_data = any_supply ? supply_data : mem_read_data;
    assign snoop_data_ready = (state == BUS_COMPLETE);
    assign snoop_shared = any_snoop_hit;
    
    // Memory interface
    assign mem_read = (state == BUS_MEM_READ);
    assign mem_write = (state == BUS_MEM_WRITE);
    assign mem_addr = captured_addr;
    assign mem_write_data = captured_data;

endmodule
