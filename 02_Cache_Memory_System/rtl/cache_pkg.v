`timescale 1ns/1ps

// Cache Memory Package - Common definitions

// Cache parameters
`define CACHE_SIZE      1024    // 1KB cache
`define BLOCK_SIZE      32      // 32-byte blocks
`define NUM_SETS_DM     32      // Direct-mapped: 32 sets
`define NUM_SETS_2WAY   16      // 2-way: 16 sets
`define NUM_WAYS        2       // 2-way set associative

// Address breakdown for 32-byte blocks (5-bit offset)
// Direct-mapped: 5-bit index, remaining tag
// 2-way: 4-bit index, remaining tag

// Cache line states
`define CACHE_INVALID   1'b0
`define CACHE_VALID     1'b1

// Write policy
`define WRITE_BACK      1'b0
`define WRITE_THROUGH   1'b1
