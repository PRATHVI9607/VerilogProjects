`timescale 1ns/1ps

// Tomasulo Algorithm Package - Common Definitions
// Based on IBM 360/91 floating-point unit design

// Operation types
`define FP_ADD   3'd0
`define FP_SUB   3'd1
`define FP_MUL   3'd2
`define FP_DIV   3'd3
`define FP_LOAD  3'd4
`define FP_STORE 3'd5

// Reservation station tags (0 = ready/no tag)
`define TAG_NONE     4'd0
`define TAG_ADD1     4'd1
`define TAG_ADD2     4'd2
`define TAG_ADD3     4'd3
`define TAG_MUL1     4'd4
`define TAG_MUL2     4'd5
`define TAG_LOAD1    4'd6
`define TAG_LOAD2    4'd7
`define TAG_STORE1   4'd8
`define TAG_STORE2   4'd9

// FP register file size
`define NUM_FP_REGS  16

// Execution latencies (cycles)
`define ADD_LATENCY  2
`define MUL_LATENCY  4
`define DIV_LATENCY  8
`define LOAD_LATENCY 2
