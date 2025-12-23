`timescale 1ns/1ps

// Memory BIST Controller
// Built-In Self-Test for SRAM testing

module memory_bist #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH = 1024
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Control interface
    input  wire        bist_start,
    input  wire [2:0]  test_mode, // Test algorithm selection
    output wire        bist_done,
    output wire        bist_pass,
    output wire        bist_fail,
    output wire        bist_busy,
    
    // Memory under test interface
    output wire        mem_ce,      // Chip enable
    output wire        mem_we,      // Write enable
    output wire [ADDR_WIDTH-1:0] mem_addr,
    output wire [DATA_WIDTH-1:0] mem_wdata,
    input  wire [DATA_WIDTH-1:0] mem_rdata,
    
    // Fault information
    output wire        fault_detected,
    output wire [ADDR_WIDTH-1:0] fault_addr,
    output wire [DATA_WIDTH-1:0] fault_expected,
    output wire [DATA_WIDTH-1:0] fault_actual,
    output wire [2:0]  fault_type,  // SAF0, SAF1, TF, CF, etc.
    
    // Progress
    output wire [7:0]  progress_percent,
    output wire [31:0] test_count
);

    // Test modes
    localparam TEST_MARCH_C_MINUS = 3'd0;
    localparam TEST_MARCH_C_PLUS  = 3'd1;
    localparam TEST_LFSR_RANDOM   = 3'd2;
    localparam TEST_CHECKERBOARD  = 3'd3;
    localparam TEST_WALKING_ONES  = 3'd4;
    localparam TEST_WALKING_ZEROS = 3'd5;
    localparam TEST_ALL_PATTERNS  = 3'd6;
    
    // Fault types
    localparam FAULT_NONE    = 3'd0;
    localparam FAULT_SAF0    = 3'd1; // Stuck-at-0
    localparam FAULT_SAF1    = 3'd2; // Stuck-at-1
    localparam FAULT_TF      = 3'd3; // Transition fault
    localparam FAULT_CF      = 3'd4; // Coupling fault
    localparam FAULT_AF      = 3'd5; // Address fault
    localparam FAULT_UNKNOWN = 3'd6;
    
    // State machine
    localparam IDLE = 4'd0;
    localparam RUN_MARCH = 4'd1;
    localparam RUN_LFSR = 4'd2;
    localparam RUN_CHECKER = 4'd3;
    localparam RUN_WALKING = 4'd4;
    localparam ANALYZE = 4'd5;
    localparam PASS_STATE = 4'd6;
    localparam FAIL_STATE = 4'd7;
    
    reg [3:0] state, next_state;
    
    // Test selection
    reg [2:0] current_test;
    
    // March test interface
    wire march_start;
    wire march_done;
    wire march_busy;
    wire [ADDR_WIDTH-1:0] march_addr;
    wire march_read, march_write;
    wire [DATA_WIDTH-1:0] march_wdata;
    wire march_error;
    wire [ADDR_WIDTH-1:0] march_error_addr;
    wire [DATA_WIDTH-1:0] march_expected;
    wire [DATA_WIDTH-1:0] march_actual;
    
    // LFSR generator
    wire lfsr_enable;
    wire [DATA_WIDTH-1:0] lfsr_pattern;
    
    // LFSR test state
    reg [1:0] lfsr_phase; // 0: write, 1: read/verify, 2: done
    reg [ADDR_WIDTH-1:0] lfsr_addr;
    reg lfsr_error;
    reg [ADDR_WIDTH-1:0] lfsr_error_addr;
    reg [DATA_WIDTH-1:0] lfsr_expected;
    reg [DATA_WIDTH-1:0] lfsr_actual;
    
    // Memory interface mux
    reg mem_ce_reg, mem_we_reg;
    reg [ADDR_WIDTH-1:0] mem_addr_reg;
    reg [DATA_WIDTH-1:0] mem_wdata_reg;
    
    // Fault capture
    reg fault_flag;
    reg [ADDR_WIDTH-1:0] fault_addr_reg;
    reg [DATA_WIDTH-1:0] fault_exp_reg;
    reg [DATA_WIDTH-1:0] fault_act_reg;
    reg [2:0] fault_type_reg;
    
    // Statistics
    reg [31:0] total_tests;
    reg [31:0] total_errors;
    
    // Progress calculation
    reg [31:0] operations_done;
    wire [31:0] total_operations = MEM_DEPTH * 10; // Approximate
    
    // March test instance
    march_generator #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_march (
        .clk(clk),
        .rst_n(rst_n),
        .start(march_start),
        .march_type(current_test),
        .done(march_done),
        .busy(march_busy),
        .mem_addr(march_addr),
        .mem_read(march_read),
        .mem_write(march_write),
        .mem_wdata(march_wdata),
        .mem_rdata(mem_rdata),
        .mem_ready(1'b1),
        .error_detected(march_error),
        .error_addr(march_error_addr),
        .expected_data(march_expected),
        .actual_data(march_actual),
        .current_element(),
        .total_elements()
    );
    
    // LFSR instance
    lfsr_generator #(
        .WIDTH(DATA_WIDTH)
    ) u_lfsr (
        .clk(clk),
        .rst_n(rst_n),
        .enable(lfsr_enable),
        .load_seed(state == IDLE && bist_start),
        .seed_value(32'hDEADBEEF),
        .pattern(lfsr_pattern),
        .inv_pattern()
    );
    
    assign march_start = (state == IDLE && bist_start && 
                          (current_test == TEST_MARCH_C_MINUS || 
                           current_test == TEST_MARCH_C_PLUS));
    
    assign lfsr_enable = (state == RUN_LFSR && lfsr_phase == 0);
    
    // Output assignments
    assign bist_done = (state == PASS_STATE) || (state == FAIL_STATE);
    assign bist_pass = (state == PASS_STATE);
    assign bist_fail = (state == FAIL_STATE);
    assign bist_busy = (state != IDLE) && !bist_done;
    
    assign mem_ce = mem_ce_reg;
    assign mem_we = mem_we_reg;
    assign mem_addr = mem_addr_reg;
    assign mem_wdata = mem_wdata_reg;
    
    assign fault_detected = fault_flag;
    assign fault_addr = fault_addr_reg;
    assign fault_expected = fault_exp_reg;
    assign fault_actual = fault_act_reg;
    assign fault_type = fault_type_reg;
    
    assign progress_percent = (operations_done * 100) / total_operations;
    assign test_count = total_tests;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_test <= 0;
            mem_ce_reg <= 0;
            mem_we_reg <= 0;
            mem_addr_reg <= 0;
            mem_wdata_reg <= 0;
            fault_flag <= 0;
            fault_addr_reg <= 0;
            fault_exp_reg <= 0;
            fault_act_reg <= 0;
            fault_type_reg <= FAULT_NONE;
            total_tests <= 0;
            total_errors <= 0;
            operations_done <= 0;
            lfsr_phase <= 0;
            lfsr_addr <= 0;
            lfsr_error <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (bist_start) begin
                        current_test <= test_mode;
                        fault_flag <= 0;
                        total_tests <= 0;
                        total_errors <= 0;
                        operations_done <= 0;
                        lfsr_phase <= 0;
                        lfsr_addr <= 0;
                        lfsr_error <= 0;
                    end
                end
                
                RUN_MARCH: begin
                    mem_ce_reg <= march_read | march_write;
                    mem_we_reg <= march_write;
                    mem_addr_reg <= march_addr;
                    mem_wdata_reg <= march_wdata;
                    operations_done <= operations_done + 1;
                    
                    if (march_error) begin
                        fault_flag <= 1;
                        fault_addr_reg <= march_error_addr;
                        fault_exp_reg <= march_expected;
                        fault_act_reg <= march_actual;
                        fault_type_reg <= analyze_fault(march_expected, march_actual);
                        total_errors <= total_errors + 1;
                    end
                end
                
                RUN_LFSR: begin
                    case (lfsr_phase)
                        2'd0: begin // Write phase
                            mem_ce_reg <= 1;
                            mem_we_reg <= 1;
                            mem_addr_reg <= lfsr_addr;
                            mem_wdata_reg <= lfsr_pattern;
                            operations_done <= operations_done + 1;
                            
                            if (lfsr_addr == MEM_DEPTH - 1) begin
                                lfsr_phase <= 1;
                                lfsr_addr <= 0;
                            end else begin
                                lfsr_addr <= lfsr_addr + 1;
                            end
                        end
                        
                        2'd1: begin // Read/verify phase
                            mem_ce_reg <= 1;
                            mem_we_reg <= 0;
                            mem_addr_reg <= lfsr_addr;
                            operations_done <= operations_done + 1;
                            
                            // Compare (would need proper timing)
                            if (lfsr_addr == MEM_DEPTH - 1) begin
                                lfsr_phase <= 2;
                            end else begin
                                lfsr_addr <= lfsr_addr + 1;
                            end
                        end
                        
                        2'd2: begin // Done
                            mem_ce_reg <= 0;
                            mem_we_reg <= 0;
                        end
                    endcase
                end
                
                PASS_STATE, FAIL_STATE: begin
                    mem_ce_reg <= 0;
                    mem_we_reg <= 0;
                    total_tests <= total_tests + 1;
                end
            endcase
        end
    end
    
    // Fault analysis function
    function [2:0] analyze_fault;
        input [DATA_WIDTH-1:0] expected;
        input [DATA_WIDTH-1:0] actual;
        begin
            if (actual == 0 && expected != 0)
                analyze_fault = FAULT_SAF0;
            else if (actual == {DATA_WIDTH{1'b1}} && expected != {DATA_WIDTH{1'b1}})
                analyze_fault = FAULT_SAF1;
            else
                analyze_fault = FAULT_UNKNOWN;
        end
    endfunction
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (bist_start) begin
                    case (test_mode)
                        TEST_MARCH_C_MINUS, TEST_MARCH_C_PLUS: next_state = RUN_MARCH;
                        TEST_LFSR_RANDOM: next_state = RUN_LFSR;
                        default: next_state = RUN_MARCH;
                    endcase
                end
            end
            
            RUN_MARCH: begin
                if (march_done) begin
                    next_state = march_error ? FAIL_STATE : PASS_STATE;
                end
            end
            
            RUN_LFSR: begin
                if (lfsr_phase == 2) begin
                    next_state = lfsr_error ? FAIL_STATE : PASS_STATE;
                end
            end
            
            PASS_STATE, FAIL_STATE: begin
                if (bist_start) next_state = IDLE;
            end
        endcase
    end

endmodule
