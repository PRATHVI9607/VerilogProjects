`timescale 1ns/1ps

// Pipeline Flush Controller
// Controls pipeline flush on exceptions and interrupts

module pipeline_flush_ctrl #(
    parameter XLEN = 32
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Interrupt/Exception signals
    input  wire        interrupt_pending,
    input  wire [XLEN-1:0] interrupt_vector,
    input  wire        exception_valid,
    input  wire [XLEN-1:0] exception_vector,
    
    // Pipeline stage info
    input  wire [XLEN-1:0] if_pc,
    input  wire [XLEN-1:0] id_pc,
    input  wire [XLEN-1:0] ex_pc,
    input  wire [XLEN-1:0] mem_pc,
    input  wire [XLEN-1:0] wb_pc,
    
    // Pipeline valid signals
    input  wire        if_valid,
    input  wire        id_valid,
    input  wire        ex_valid,
    input  wire        mem_valid,
    input  wire        wb_valid,
    
    // Control signals
    input  wire        interrupt_enable,  // Global interrupt enable
    input  wire        pipeline_stall,    // External stall
    
    // Flush outputs
    output wire        flush_if,
    output wire        flush_id,
    output wire        flush_ex,
    output wire        flush_mem,
    output wire        flush_wb,
    output wire        flush_all,
    
    // PC redirect
    output wire        pc_redirect,
    output wire [XLEN-1:0] redirect_pc,
    
    // Pipeline control
    output wire        pipeline_flush_busy,
    output wire [XLEN-1:0] mepc_out,  // PC to save for return
    
    // Interrupt acknowledgment
    output wire        irq_taken,
    output wire        exc_taken
);

    // State machine for precise interrupts
    localparam NORMAL = 2'd0;
    localparam WAIT_DRAIN = 2'd1;  // Wait for pipeline to drain
    localparam TAKE_TRAP = 2'd2;
    localparam FLUSH = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Saved values
    reg [XLEN-1:0] saved_vector;
    reg [XLEN-1:0] saved_mepc;
    reg saved_is_interrupt;
    
    // Find the appropriate PC to save (oldest valid instruction)
    wire [XLEN-1:0] drain_pc = wb_valid ? wb_pc :
                                mem_valid ? mem_pc :
                                ex_valid ? ex_pc :
                                id_valid ? id_pc :
                                if_pc;
    
    // Exception point PC (where exception occurred)
    wire [XLEN-1:0] exception_pc = mem_valid ? mem_pc :  // Most exceptions in MEM
                                   ex_valid ? ex_pc :
                                   id_valid ? id_pc :
                                   if_pc;
    
    // Interrupt can be taken when pipeline can be cleanly interrupted
    wire can_take_interrupt = interrupt_pending && interrupt_enable && 
                              !exception_valid && !pipeline_stall;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= NORMAL;
            saved_vector <= 0;
            saved_mepc <= 0;
            saved_is_interrupt <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                NORMAL: begin
                    if (exception_valid) begin
                        saved_vector <= exception_vector;
                        saved_mepc <= exception_pc;
                        saved_is_interrupt <= 0;
                    end else if (can_take_interrupt) begin
                        saved_vector <= interrupt_vector;
                        saved_mepc <= if_pc;  // Return to next instruction
                        saved_is_interrupt <= 1;
                    end
                end
                
                WAIT_DRAIN: begin
                    // Update mepc as instructions complete
                    if (wb_valid) begin
                        saved_mepc <= wb_pc + 4; // Next instruction after completed one
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            NORMAL: begin
                if (exception_valid) begin
                    next_state = FLUSH;  // Immediate flush for exceptions
                end else if (can_take_interrupt) begin
                    next_state = WAIT_DRAIN;
                end
            end
            
            WAIT_DRAIN: begin
                // Wait until pipeline is mostly drained
                if (!ex_valid && !mem_valid) begin
                    next_state = TAKE_TRAP;
                end
            end
            
            TAKE_TRAP: begin
                next_state = FLUSH;
            end
            
            FLUSH: begin
                next_state = NORMAL;
            end
        endcase
    end
    
    // Flush signals
    wire do_flush = (state == FLUSH) || (exception_valid && state == NORMAL);
    
    assign flush_if = do_flush;
    assign flush_id = do_flush;
    assign flush_ex = do_flush;
    assign flush_mem = do_flush && exception_valid; // Only on exception
    assign flush_wb = 1'b0;  // Never flush WB (let it complete)
    assign flush_all = do_flush;
    
    // PC redirect
    assign pc_redirect = (state == TAKE_TRAP) || (exception_valid && state == NORMAL);
    assign redirect_pc = saved_vector;
    
    // Status
    assign pipeline_flush_busy = (state != NORMAL);
    assign mepc_out = saved_mepc;
    
    // Trap taken signals
    assign irq_taken = (state == TAKE_TRAP) && saved_is_interrupt;
    assign exc_taken = (state == FLUSH) && !saved_is_interrupt;

endmodule
