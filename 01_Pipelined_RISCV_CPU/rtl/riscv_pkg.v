`timescale 1ns/1ps

// RISC-V Package - Common definitions
// RV32I Base Integer Instruction Set

// Opcodes
`define OP_LUI      7'b0110111
`define OP_AUIPC    7'b0010111
`define OP_JAL      7'b1101111
`define OP_JALR     7'b1100111
`define OP_BRANCH   7'b1100011
`define OP_LOAD     7'b0000011
`define OP_STORE    7'b0100011
`define OP_IMM      7'b0010011
`define OP_REG      7'b0110011

// ALU Operations
`define ALU_ADD     4'b0000
`define ALU_SUB     4'b0001
`define ALU_SLL     4'b0010
`define ALU_SLT     4'b0011
`define ALU_SLTU    4'b0100
`define ALU_XOR     4'b0101
`define ALU_SRL     4'b0110
`define ALU_SRA     4'b0111
`define ALU_OR      4'b1000
`define ALU_AND     4'b1001
`define ALU_PASS_B  4'b1010

// Branch conditions (funct3)
`define BR_BEQ      3'b000
`define BR_BNE      3'b001
`define BR_BLT      3'b100
`define BR_BGE      3'b101
`define BR_BLTU     3'b110
`define BR_BGEU     3'b111

// Forwarding mux selections
`define FWD_NONE    2'b00
`define FWD_EX_MEM  2'b01
`define FWD_MEM_WB  2'b10
