`timescale 1ns/1ps

// MESI Cache Controller
// Per-processor cache with MESI coherence protocol

module mesi_cache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CACHE_LINES = 64,
    parameter LINE_SIZE = 32,
    parameter TAG_WIDTH = 20
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // CPU interface
    input  wire [ADDR_WIDTH-1:0] cpu_addr,
    input  wire        cpu_read,
    input  wire        cpu_write,
    input  wire [DATA_WIDTH-1:0] cpu_write_data,
    output wire [DATA_WIDTH-1:0] cpu_read_data,
    output wire        cpu_ready,
    output wire        cpu_hit,
    
    // Bus interface (to snoop bus)
    output wire        bus_req,
    output wire [2:0]  bus_op,      // 000: none, 001: BusRd, 010: BusRdX, 011: BusUpgr
    output wire [ADDR_WIDTH-1:0] bus_addr,
    output wire [LINE_SIZE*8-1:0] bus_data_out,
    output wire        bus_data_valid,
    
    input  wire        bus_grant,
    input  wire [2:0]  bus_snoop_op,
    input  wire [ADDR_WIDTH-1:0] bus_snoop_addr,
    input  wire [LINE_SIZE*8-1:0] bus_data_in,
    input  wire        bus_data_ready,
    input  wire        bus_shared,   // Another cache has this line
    
    // Status
    output wire [1:0]  cache_state [0:CACHE_LINES-1]
);

    // Address breakdown
    localparam OFFSET_BITS = $clog2(LINE_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_LINES);
    localparam TAG_BITS = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    
    wire [OFFSET_BITS-1:0] cpu_offset = cpu_addr[OFFSET_BITS-1:0];
    wire [INDEX_BITS-1:0] cpu_index = cpu_addr[OFFSET_BITS +: INDEX_BITS];
    wire [TAG_BITS-1:0] cpu_tag = cpu_addr[ADDR_WIDTH-1 -: TAG_BITS];
    wire [$clog2(LINE_SIZE/4)-1:0] cpu_word_sel = cpu_addr[OFFSET_BITS-1:2];
    
    wire [INDEX_BITS-1:0] snoop_index = bus_snoop_addr[OFFSET_BITS +: INDEX_BITS];
    wire [TAG_BITS-1:0] snoop_tag = bus_snoop_addr[ADDR_WIDTH-1 -: TAG_BITS];
    
    // Cache line signals
    wire [CACHE_LINES-1:0] line_cpu_hit;
    wire [CACHE_LINES-1:0] line_snoop_hit;
    wire [CACHE_LINES-1:0] line_supply_data;
    wire [CACHE_LINES-1:0] line_writeback_needed;
    wire [DATA_WIDTH-1:0] line_read_data [0:CACHE_LINES-1];
    wire [LINE_SIZE*8-1:0] line_data [0:CACHE_LINES-1];
    wire [TAG_BITS-1:0] line_tag [0:CACHE_LINES-1];
    wire [1:0] line_state [0:CACHE_LINES-1];
    
    // State machine
    localparam IDLE = 3'd0;
    localparam BUS_RD = 3'd1;
    localparam BUS_RDX = 3'd2;
    localparam BUS_UPGR = 3'd3;
    localparam WRITEBACK = 3'd4;
    localparam FILL = 3'd5;
    
    reg [2:0] state, next_state;
    reg [ADDR_WIDTH-1:0] pending_addr;
    reg pending_write;
    reg [DATA_WIDTH-1:0] pending_data;
    
    // Hit detection
    wire any_hit = |line_cpu_hit;
    wire selected_hit = line_cpu_hit[cpu_index];
    
    // Current line state
    wire [1:0] current_state = line_state[cpu_index];
    
    // Generate cache lines
    genvar g;
    generate
        for (g = 0; g < CACHE_LINES; g = g + 1) begin : gen_cache_lines
            wire line_selected = (cpu_index == g);
            wire snoop_selected = (snoop_index == g);
            
            mesi_cache_line #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .TAG_WIDTH(TAG_BITS),
                .LINE_SIZE(LINE_SIZE)
            ) u_line (
                .clk(clk),
                .rst_n(rst_n),
                .state(line_state[g]),
                .valid(),
                .dirty(),
                .tag(line_tag[g]),
                .data(line_data[g]),
                .cpu_read(cpu_read && line_selected),
                .cpu_write(cpu_write && line_selected && state == IDLE),
                .cpu_tag(cpu_tag),
                .cpu_write_data(cpu_write_data),
                .cpu_word_sel(cpu_word_sel),
                .cpu_hit(line_cpu_hit[g]),
                .cpu_read_data(line_read_data[g]),
                .snoop_read(bus_snoop_op == 3'b001 && snoop_selected),
                .snoop_read_x(bus_snoop_op == 3'b010 && snoop_selected),
                .snoop_upgrade(bus_snoop_op == 3'b011 && snoop_selected),
                .snoop_tag(snoop_tag),
                .snoop_hit(line_snoop_hit[g]),
                .snoop_supply_data(line_supply_data[g]),
                .fill_valid(state == FILL && line_selected && bus_data_ready),
                .fill_data(bus_data_in),
                .fill_exclusive(!bus_shared),
                .fill_tag(pending_addr[ADDR_WIDTH-1 -: TAG_BITS]),
                .writeback_needed(line_writeback_needed[g]),
                .writeback_data(),
                .writeback_tag()
            );
            
            assign cache_state[g] = line_state[g];
        end
    endgenerate
    
    // CPU read data mux
    assign cpu_read_data = line_read_data[cpu_index];
    assign cpu_hit = selected_hit;
    
    // Bus signals
    reg bus_req_reg;
    reg [2:0] bus_op_reg;
    reg [ADDR_WIDTH-1:0] bus_addr_reg;
    reg bus_data_valid_reg;
    
    assign bus_req = bus_req_reg;
    assign bus_op = bus_op_reg;
    assign bus_addr = bus_addr_reg;
    assign bus_data_out = line_data[cpu_index];
    assign bus_data_valid = bus_data_valid_reg;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pending_addr <= 0;
            pending_write <= 0;
            pending_data <= 0;
            bus_req_reg <= 0;
            bus_op_reg <= 0;
            bus_addr_reg <= 0;
            bus_data_valid_reg <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if ((cpu_read || cpu_write) && !selected_hit) begin
                        pending_addr <= cpu_addr;
                        pending_write <= cpu_write;
                        pending_data <= cpu_write_data;
                        bus_addr_reg <= cpu_addr;
                        bus_req_reg <= 1;
                        
                        if (line_writeback_needed[cpu_index]) begin
                            // Need writeback first
                            bus_op_reg <= 3'b000;
                        end else if (cpu_write) begin
                            bus_op_reg <= 3'b010; // BusRdX
                        end else begin
                            bus_op_reg <= 3'b001; // BusRd
                        end
                    end else if (cpu_write && selected_hit && current_state == 2'b01) begin
                        // Write hit in Shared state - need upgrade
                        pending_addr <= cpu_addr;
                        pending_write <= 1;
                        pending_data <= cpu_write_data;
                        bus_req_reg <= 1;
                        bus_op_reg <= 3'b011; // BusUpgr
                        bus_addr_reg <= cpu_addr;
                    end
                end
                
                WRITEBACK: begin
                    if (bus_grant) begin
                        bus_data_valid_reg <= 1;
                    end
                end
                
                BUS_RD, BUS_RDX, BUS_UPGR: begin
                    // Wait for grant and data
                end
                
                FILL: begin
                    bus_req_reg <= 0;
                    bus_op_reg <= 0;
                    bus_data_valid_reg <= 0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if ((cpu_read || cpu_write) && !selected_hit) begin
                    if (line_writeback_needed[cpu_index]) begin
                        next_state = WRITEBACK;
                    end else if (cpu_write) begin
                        next_state = BUS_RDX;
                    end else begin
                        next_state = BUS_RD;
                    end
                end else if (cpu_write && selected_hit && current_state == 2'b01) begin
                    next_state = BUS_UPGR;
                end
            end
            
            WRITEBACK: begin
                if (bus_grant && bus_data_ready) begin
                    if (pending_write) begin
                        next_state = BUS_RDX;
                    end else begin
                        next_state = BUS_RD;
                    end
                end
            end
            
            BUS_RD, BUS_RDX: begin
                if (bus_grant && bus_data_ready) begin
                    next_state = FILL;
                end
            end
            
            BUS_UPGR: begin
                if (bus_grant) begin
                    next_state = IDLE;
                end
            end
            
            FILL: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // CPU ready
    assign cpu_ready = (state == IDLE) && 
                       ((cpu_read && selected_hit) || 
                        (cpu_write && selected_hit && current_state != 2'b01) ||
                        (!cpu_read && !cpu_write));

endmodule
