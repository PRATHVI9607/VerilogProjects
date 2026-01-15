`timescale 1ns/1ps

// Instruction Fetch Stage (IF)
// Fetches instruction from memory and manages PC

module instruction_fetch (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,           // Stall signal from hazard unit
    input  wire        branch_taken,    // Branch/jump taken
    input  wire [31:0] branch_target,   // Branch/jump target address
    output reg  [31:0] pc_out,          // Current PC
    output reg  [31:0] instruction,     // Fetched instruction
    output reg         valid            // Instruction valid
);

    // Program Counter
    reg [31:0] pc;
    
    // Simple instruction memory (ROM) - 1KB
    reg [31:0] imem [0:255];
    
    // Initialize instruction memory with test program
    // Load from program.hex file or use default
    initial begin
        integer i;
        // Try to load from external file first
        if ($fopen("program.hex", "r") != 0) begin
            $readmemh("program.hex", imem);
            $display("INFO: Loaded program from program.hex");
        end else begin
            // Default test program if file not found
            $display("INFO: Using default test program");
            imem[0]  = 32'h00500093;  // addi x1, x0, 5
            imem[1]  = 32'h00A00113;  // addi x2, x0, 10
            imem[2]  = 32'h002081B3;  // add x3, x1, x2
            imem[3]  = 32'h40208233;  // sub x4, x1, x2
            imem[4]  = 32'h0020F2B3;  // and x5, x1, x2
            imem[5]  = 32'h0020E333;  // or x6, x1, x2
            imem[6]  = 32'h0020C3B3;  // xor x7, x1, x2
            imem[7]  = 32'h00209433;  // sll x8, x1, x2
            imem[8]  = 32'h0020D4B3;  // srl x9, x1, x2
            imem[9]  = 32'h0020A533;  // slt x10, x1, x2
            imem[10] = 32'h00112023;  // sw x1, 0(x2)
            imem[11] = 32'h00012583;  // lw x11, 0(x2)
            imem[12] = 32'h00208663;  // beq x1, x2, +12
            imem[13] = 32'h00100613;  // addi x12, x0, 1
            imem[14] = 32'h00200693;  // addi x13, x0, 2
            imem[15] = 32'h00300713;  // addi x14, x0, 3
        end
        // Fill rest with NOPs
        for (i = 16; i < 256; i = i + 1) begin
            imem[i] = 32'h00000013;  // nop (addi x0, x0, 0)
        end
    end
    
    // PC Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h00000000;
        end else if (branch_taken) begin
            pc <= branch_target;
        end else if (!stall) begin
            pc <= pc + 4;
        end
    end
    
    // Instruction fetch
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out <= 32'h00000000;
            instruction <= 32'h00000013;  // NOP
            valid <= 1'b0;
        end else if (branch_taken) begin
            // Insert bubble on branch
            pc_out <= branch_target;
            instruction <= 32'h00000013;  // NOP
            valid <= 1'b0;
        end else if (!stall) begin
            pc_out <= pc;
            instruction <= imem[pc[9:2]];  // Word aligned
            valid <= 1'b1;
        end
    end

endmodule
