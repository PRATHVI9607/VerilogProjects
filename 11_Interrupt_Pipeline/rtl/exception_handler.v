`timescale 1ns/1ps

// Exception Handler
// Handles synchronous exceptions and traps

module exception_handler #(
    parameter XLEN = 32
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Exception inputs from pipeline stages
    input  wire        exc_illegal_instr,
    input  wire        exc_misaligned_fetch,
    input  wire        exc_misaligned_load,
    input  wire        exc_misaligned_store,
    input  wire        exc_ecall,
    input  wire        exc_ebreak,
    input  wire        exc_page_fault_fetch,
    input  wire        exc_page_fault_load,
    input  wire        exc_page_fault_store,
    
    // Current instruction info
    input  wire [XLEN-1:0] exc_pc,
    input  wire [XLEN-1:0] exc_instr,
    input  wire [XLEN-1:0] exc_addr,  // For memory exceptions
    
    // Current privilege mode
    input  wire [1:0]  priv_mode,  // 00: User, 01: Supervisor, 11: Machine
    
    // Exception output
    output wire        exception_valid,
    output wire [XLEN-1:0] exception_cause,
    output wire [XLEN-1:0] exception_tval,  // Trap value
    output wire [XLEN-1:0] exception_pc,
    output wire [1:0]  target_priv,  // Target privilege mode
    
    // CSR interface
    input  wire [XLEN-1:0] mtvec,    // Machine trap vector
    input  wire [XLEN-1:0] stvec,    // Supervisor trap vector
    input  wire [XLEN-1:0] medeleg,  // Machine exception delegation
    output wire [XLEN-1:0] trap_vector
);

    // Exception codes (RISC-V standard)
    localparam EXC_INSTR_MISALIGN  = 4'd0;
    localparam EXC_INSTR_FAULT     = 4'd1;
    localparam EXC_ILLEGAL_INSTR   = 4'd2;
    localparam EXC_BREAKPOINT      = 4'd3;
    localparam EXC_LOAD_MISALIGN   = 4'd4;
    localparam EXC_LOAD_FAULT      = 4'd5;
    localparam EXC_STORE_MISALIGN  = 4'd6;
    localparam EXC_STORE_FAULT     = 4'd7;
    localparam EXC_ECALL_U         = 4'd8;
    localparam EXC_ECALL_S         = 4'd9;
    localparam EXC_ECALL_M         = 4'd11;
    localparam EXC_INSTR_PAGE_FAULT = 4'd12;
    localparam EXC_LOAD_PAGE_FAULT  = 4'd13;
    localparam EXC_STORE_PAGE_FAULT = 4'd15;
    
    // Exception aggregation (priority encoded)
    wire [15:0] exc_bits = {
        exc_page_fault_store,    // 15
        1'b0,                    // 14 (reserved)
        exc_page_fault_load,     // 13
        exc_page_fault_fetch,    // 12
        1'b0,                    // 11 (ECALL_M - handled separately)
        1'b0,                    // 10 (reserved)
        1'b0,                    // 9  (ECALL_S - handled separately)
        1'b0,                    // 8  (ECALL_U - handled separately)
        exc_misaligned_store,    // 7
        1'b0,                    // 6  (store fault)
        exc_misaligned_load,     // 5
        1'b0,                    // 4  (load fault)
        exc_ebreak,              // 3
        exc_illegal_instr,       // 2
        1'b0,                    // 1  (instr fault)
        exc_misaligned_fetch     // 0
    };
    
    // ECALL generates different codes based on privilege
    wire [3:0] ecall_code = (priv_mode == 2'b00) ? EXC_ECALL_U :
                            (priv_mode == 2'b01) ? EXC_ECALL_S :
                            EXC_ECALL_M;
    
    // Priority encode exception
    reg [3:0] exc_code;
    reg exc_found;
    
    integer i;
    always @(*) begin
        exc_code = 0;
        exc_found = 0;
        
        // Check ECALL first
        if (exc_ecall) begin
            exc_code = ecall_code;
            exc_found = 1;
        end else begin
            // Priority: lower number = higher priority
            for (i = 0; i < 16; i = i + 1) begin
                if (exc_bits[i] && !exc_found) begin
                    exc_code = i[3:0];
                    exc_found = 1;
                end
            end
        end
    end
    
    // Determine trap value based on exception type
    reg [XLEN-1:0] tval;
    always @(*) begin
        case (exc_code)
            EXC_INSTR_MISALIGN, EXC_INSTR_FAULT, EXC_INSTR_PAGE_FAULT:
                tval = exc_pc;
            EXC_ILLEGAL_INSTR:
                tval = exc_instr;
            EXC_LOAD_MISALIGN, EXC_LOAD_FAULT, EXC_LOAD_PAGE_FAULT,
            EXC_STORE_MISALIGN, EXC_STORE_FAULT, EXC_STORE_PAGE_FAULT:
                tval = exc_addr;
            default:
                tval = 0;
        endcase
    end
    
    // Delegation check - does this exception delegate to supervisor?
    wire delegated = (priv_mode <= 2'b01) && medeleg[exc_code];
    
    // Target privilege level
    wire [1:0] trap_priv = delegated ? 2'b01 : 2'b11; // S-mode or M-mode
    
    // Select trap vector based on target privilege
    wire [XLEN-1:0] tvec = delegated ? stvec : mtvec;
    
    // Calculate trap vector (direct or vectored mode)
    wire vectored_mode = tvec[0];
    wire [XLEN-1:0] vector_addr = vectored_mode ? 
                                   {tvec[XLEN-1:2], 2'b00} + {exc_code, 2'b00} :
                                   {tvec[XLEN-1:2], 2'b00};
    
    // Outputs
    assign exception_valid = exc_found;
    assign exception_cause = {{(XLEN-4){1'b0}}, exc_code};
    assign exception_tval = tval;
    assign exception_pc = exc_pc;
    assign target_priv = trap_priv;
    assign trap_vector = vector_addr;

endmodule
