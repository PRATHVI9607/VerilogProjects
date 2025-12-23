`timescale 1ns/1ps

// Out-of-Order Execution Core - Common Definitions

// Operation types
`define OP_ADD   3'd0
`define OP_SUB   3'd1
`define OP_MUL   3'd2
`define OP_DIV   3'd3
`define OP_AND   3'd4
`define OP_OR    3'd5
`define OP_XOR   3'd6
`define OP_LOAD  3'd7

// ROB entry states
`define ROB_EMPTY    2'd0
`define ROB_ISSUED   2'd1
`define ROB_COMPLETE 2'd2
`define ROB_COMMIT   2'd3

// RS entry states
`define RS_EMPTY     1'b0
`define RS_BUSY      1'b1

// Number of physical registers
`define NUM_PHYS_REGS 64
`define NUM_ARCH_REGS 32

// ROB size
`define ROB_SIZE 16

// RS sizes
`define RS_ALU_SIZE  4
`define RS_MUL_SIZE  2
`define RS_MEM_SIZE  4
