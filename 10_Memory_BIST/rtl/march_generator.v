`timescale 1ns/1ps

// March Test Pattern Generator
// Implements various March test algorithms

module march_generator #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Control
    input  wire        start,
    input  wire [2:0]  march_type, // Algorithm selection
    output wire        done,
    output wire        busy,
    
    // Memory interface
    output wire [ADDR_WIDTH-1:0] mem_addr,
    output wire        mem_read,
    output wire        mem_write,
    output wire [DATA_WIDTH-1:0] mem_wdata,
    input  wire [DATA_WIDTH-1:0] mem_rdata,
    input  wire        mem_ready,
    
    // Error detection
    output wire        error_detected,
    output wire [ADDR_WIDTH-1:0] error_addr,
    output wire [DATA_WIDTH-1:0] expected_data,
    output wire [DATA_WIDTH-1:0] actual_data,
    
    // Status
    output wire [3:0]  current_element,
    output wire [3:0]  total_elements
);

    // March algorithms
    localparam MARCH_C_MINUS = 3'd0;
    localparam MARCH_C_PLUS  = 3'd1;
    localparam MARCH_B      = 3'd2;
    localparam MARCH_LR     = 3'd3;
    localparam CHECKERBOARD = 3'd4;
    localparam WALKING_ONES = 3'd5;
    localparam WALKING_ZEROS = 3'd6;
    localparam ALL_ZEROS_ONES = 3'd7;
    
    // Address range
    localparam MAX_ADDR = (1 << ADDR_WIDTH) - 1;
    
    // State machine
    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam M0   = 4'd2;  // March element 0
    localparam M1   = 4'd3;  // March element 1
    localparam M2   = 4'd4;  // March element 2
    localparam M3   = 4'd5;  // March element 3
    localparam M4   = 4'd6;  // March element 4
    localparam M5   = 4'd7;  // March element 5
    localparam VERIFY = 4'd8;
    localparam ERROR_STATE = 4'd9;
    localparam COMPLETE = 4'd10;
    
    reg [3:0] state, next_state;
    
    // Address counter
    reg [ADDR_WIDTH-1:0] addr_cnt;
    reg addr_up; // Direction: 1 = up, 0 = down
    
    // Pattern registers
    reg [DATA_WIDTH-1:0] pattern_0, pattern_1;
    
    // Operation tracking
    reg [2:0] march_alg;
    reg [2:0] op_cnt; // Operation within element
    
    // Error capture
    reg error_flag;
    reg [ADDR_WIDTH-1:0] error_addr_reg;
    reg [DATA_WIDTH-1:0] expected_reg;
    reg [DATA_WIDTH-1:0] actual_reg;
    
    // Memory control
    reg mem_read_reg, mem_write_reg;
    reg [DATA_WIDTH-1:0] wdata_reg;
    
    // Address at boundaries
    wire at_max = (addr_cnt == MAX_ADDR);
    wire at_min = (addr_cnt == 0);
    wire at_boundary = addr_up ? at_max : at_min;
    
    // Checkerboard pattern based on address
    wire [DATA_WIDTH-1:0] checker_pattern = addr_cnt[0] ? {DATA_WIDTH{1'b1}} : {DATA_WIDTH{1'b0}};
    
    // Outputs
    assign done = (state == COMPLETE);
    assign busy = (state != IDLE) && (state != COMPLETE);
    assign mem_addr = addr_cnt;
    assign mem_read = mem_read_reg;
    assign mem_write = mem_write_reg;
    assign mem_wdata = wdata_reg;
    assign error_detected = error_flag;
    assign error_addr = error_addr_reg;
    assign expected_data = expected_reg;
    assign actual_data = actual_reg;
    assign current_element = state - INIT;
    assign total_elements = 4'd6; // March C- has 6 elements
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            addr_cnt <= 0;
            addr_up <= 1;
            pattern_0 <= 0;
            pattern_1 <= {DATA_WIDTH{1'b1}};
            march_alg <= 0;
            op_cnt <= 0;
            error_flag <= 0;
            error_addr_reg <= 0;
            expected_reg <= 0;
            actual_reg <= 0;
            mem_read_reg <= 0;
            mem_write_reg <= 0;
            wdata_reg <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        march_alg <= march_type;
                        addr_cnt <= 0;
                        addr_up <= 1;
                        error_flag <= 0;
                        pattern_0 <= 0;
                        pattern_1 <= {DATA_WIDTH{1'b1}};
                        op_cnt <= 0;
                    end
                end
                
                // March C- Elements:
                // M0: ⇑ (w0) - Write 0 ascending
                // M1: ⇑ (r0, w1) - Read 0, write 1 ascending
                // M2: ⇑ (r1, w0) - Read 1, write 0 ascending
                // M3: ⇓ (r0, w1) - Read 0, write 1 descending
                // M4: ⇓ (r1, w0) - Read 1, write 0 descending
                // M5: ⇓ (r0) - Read 0 descending
                
                M0: begin // ⇑ (w0)
                    addr_up <= 1;
                    mem_write_reg <= 1;
                    wdata_reg <= pattern_0;
                    if (mem_ready) begin
                        mem_write_reg <= 0;
                        if (at_boundary) begin
                            addr_cnt <= 0;
                        end else begin
                            addr_cnt <= addr_cnt + 1;
                        end
                    end
                end
                
                M1: begin // ⇑ (r0, w1)
                    addr_up <= 1;
                    if (op_cnt == 0) begin
                        mem_read_reg <= 1;
                        if (mem_ready) begin
                            mem_read_reg <= 0;
                            // Check read value
                            if (mem_rdata != pattern_0) begin
                                error_flag <= 1;
                                error_addr_reg <= addr_cnt;
                                expected_reg <= pattern_0;
                                actual_reg <= mem_rdata;
                            end
                            op_cnt <= 1;
                        end
                    end else begin
                        mem_write_reg <= 1;
                        wdata_reg <= pattern_1;
                        if (mem_ready) begin
                            mem_write_reg <= 0;
                            op_cnt <= 0;
                            if (at_boundary) begin
                                addr_cnt <= 0;
                            end else begin
                                addr_cnt <= addr_cnt + 1;
                            end
                        end
                    end
                end
                
                M2: begin // ⇑ (r1, w0)
                    addr_up <= 1;
                    if (op_cnt == 0) begin
                        mem_read_reg <= 1;
                        if (mem_ready) begin
                            mem_read_reg <= 0;
                            if (mem_rdata != pattern_1) begin
                                error_flag <= 1;
                                error_addr_reg <= addr_cnt;
                                expected_reg <= pattern_1;
                                actual_reg <= mem_rdata;
                            end
                            op_cnt <= 1;
                        end
                    end else begin
                        mem_write_reg <= 1;
                        wdata_reg <= pattern_0;
                        if (mem_ready) begin
                            mem_write_reg <= 0;
                            op_cnt <= 0;
                            if (at_boundary) begin
                                addr_cnt <= MAX_ADDR;
                            end else begin
                                addr_cnt <= addr_cnt + 1;
                            end
                        end
                    end
                end
                
                M3: begin // ⇓ (r0, w1)
                    addr_up <= 0;
                    if (op_cnt == 0) begin
                        mem_read_reg <= 1;
                        if (mem_ready) begin
                            mem_read_reg <= 0;
                            if (mem_rdata != pattern_0) begin
                                error_flag <= 1;
                                error_addr_reg <= addr_cnt;
                                expected_reg <= pattern_0;
                                actual_reg <= mem_rdata;
                            end
                            op_cnt <= 1;
                        end
                    end else begin
                        mem_write_reg <= 1;
                        wdata_reg <= pattern_1;
                        if (mem_ready) begin
                            mem_write_reg <= 0;
                            op_cnt <= 0;
                            if (at_boundary) begin
                                addr_cnt <= MAX_ADDR;
                            end else begin
                                addr_cnt <= addr_cnt - 1;
                            end
                        end
                    end
                end
                
                M4: begin // ⇓ (r1, w0)
                    addr_up <= 0;
                    if (op_cnt == 0) begin
                        mem_read_reg <= 1;
                        if (mem_ready) begin
                            mem_read_reg <= 0;
                            if (mem_rdata != pattern_1) begin
                                error_flag <= 1;
                                error_addr_reg <= addr_cnt;
                                expected_reg <= pattern_1;
                                actual_reg <= mem_rdata;
                            end
                            op_cnt <= 1;
                        end
                    end else begin
                        mem_write_reg <= 1;
                        wdata_reg <= pattern_0;
                        if (mem_ready) begin
                            mem_write_reg <= 0;
                            op_cnt <= 0;
                            if (at_boundary) begin
                                addr_cnt <= MAX_ADDR;
                            end else begin
                                addr_cnt <= addr_cnt - 1;
                            end
                        end
                    end
                end
                
                M5: begin // ⇓ (r0)
                    addr_up <= 0;
                    mem_read_reg <= 1;
                    if (mem_ready) begin
                        mem_read_reg <= 0;
                        if (mem_rdata != pattern_0) begin
                            error_flag <= 1;
                            error_addr_reg <= addr_cnt;
                            expected_reg <= pattern_0;
                            actual_reg <= mem_rdata;
                        end
                        if (at_boundary) begin
                            // Done
                        end else begin
                            addr_cnt <= addr_cnt - 1;
                        end
                    end
                end
                
                ERROR_STATE: begin
                    // Stay here to report error
                end
                
                COMPLETE: begin
                    mem_read_reg <= 0;
                    mem_write_reg <= 0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = M0;
            end
            
            M0: begin
                if (mem_ready && at_boundary) next_state = M1;
            end
            
            M1: begin
                if (error_flag) next_state = ERROR_STATE;
                else if (mem_ready && op_cnt == 1 && at_boundary) next_state = M2;
            end
            
            M2: begin
                if (error_flag) next_state = ERROR_STATE;
                else if (mem_ready && op_cnt == 1 && at_boundary) next_state = M3;
            end
            
            M3: begin
                if (error_flag) next_state = ERROR_STATE;
                else if (mem_ready && op_cnt == 1 && at_boundary) next_state = M4;
            end
            
            M4: begin
                if (error_flag) next_state = ERROR_STATE;
                else if (mem_ready && op_cnt == 1 && at_boundary) next_state = M5;
            end
            
            M5: begin
                if (error_flag) next_state = ERROR_STATE;
                else if (mem_ready && at_boundary) next_state = COMPLETE;
            end
            
            ERROR_STATE: begin
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                if (start) next_state = M0;
            end
        endcase
    end

endmodule
