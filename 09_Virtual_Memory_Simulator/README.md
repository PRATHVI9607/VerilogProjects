# Project 9: Virtual Memory Simulator

## Overview

This project implements a virtual memory system simulator in Verilog. It includes multi-level page tables, a TLB, page frame allocation, and multiple page replacement algorithms.

## Features

- **Two-Level Page Tables** - 10+10 bit VPN splitting
- **32-Entry Direct-Mapped TLB** - Fast address translation
- **Page Frame Allocator** - Physical memory management
- **Multiple Replacement Policies** - FIFO, LRU, Clock
- **Page Fault Handling** - Demand paging support
- **Access/Dirty Bit Tracking** - For replacement decisions

## Architecture

```
+------------------+     +------------------+
|      CPU         |     |    Page Table    |
|  Virtual Addr    |     |    (2-level)     |
+--------+---------+     +--------+---------+
         |                        |
         v                        v
+--------+---------+     +--------+---------+
|       TLB        |---->|  Page Table      |
|   (32 entries)   |miss |    Walker        |
+--------+---------+     +--------+---------+
         | hit                    |
         v                        v
+--------+---------+     +--------+---------+
| Physical Address |     | Frame Allocator  |
+------------------+     +------------------+
                                  |
                         +--------+---------+
                         | Page Replacement |
                         |  (FIFO/LRU/CLK)  |
                         +------------------+
```

## File Structure

```
09_Virtual_Memory_Simulator/
├── rtl/
│   ├── page_table_entry.v        # PTE structure
│   ├── page_frame_allocator.v    # Physical frame management
│   ├── page_replacement.v        # Replacement algorithms
│   └── virtual_memory_controller.v # Main controller
├── tb/
│   └── tb_virtual_memory.v       # Testbench
├── Makefile
└── README.md
```

## Module Descriptions

### page_table_entry.v
Single page table entry with:
- Physical Page Number (PPN)
- Permission flags (R/W/X)
- User/Supervisor mode bit
- Accessed and Dirty bits
- Valid bit

### page_frame_allocator.v
Physical memory management:
- Free frame bitmap
- First-fit allocation
- Deallocation support
- Out-of-memory detection

### page_replacement.v
Multiple replacement algorithms:
- **FIFO**: First-In-First-Out queue
- **LRU**: Timestamp-based Least Recently Used
- **Clock**: Second-chance with reference bits

### virtual_memory_controller.v
Main controller integrating all components:
- TLB management
- Page table walks
- Page fault generation
- Statistics collection

## Address Translation

### Virtual Address Format (32-bit)

```
31        22 21       12 11          0
+----------+-----------+-------------+
|  VPN[1]  |   VPN[0]  | Page Offset |
+----------+-----------+-------------+
   10 bits    10 bits     12 bits
```

### Page Table Entry Format

```
31          10 9  8 7 6 5 4 3 2 1 0
+-------------+----+-+-+-+-+-+-+-+-+
|     PPN     |RSW |D|A|G|U|X|W|R|V|
+-------------+----+-+-+-+-+-+-+-+-+
```

| Field | Bits | Description |
|-------|------|-------------|
| PPN | 31:10 | Physical Page Number |
| RSW | 9:8 | Reserved for Software |
| D | 7 | Dirty |
| A | 6 | Accessed |
| G | 5 | Global |
| U | 4 | User accessible |
| X | 3 | Executable |
| W | 2 | Writable |
| R | 1 | Readable |
| V | 0 | Valid |

## Page Replacement Algorithms

### FIFO (First-In-First-Out)
```
policy = 2'b00
```
- Simple queue-based replacement
- Pages evicted in arrival order
- No access tracking needed

### LRU (Least Recently Used)
```
policy = 2'b01
```
- Timestamp-based tracking
- Evicts page with oldest access time
- Best hit rate, higher overhead

### Clock (Second-Chance)
```
policy = 2'b10
```
- Circular buffer with reference bits
- Clears reference bit on scan
- Evicts first page with ref=0
- Good balance of performance and overhead

## Simulation

### Prerequisites
- Icarus Verilog (`iverilog`)
- VVP
- GTKWave

### Running Tests

```bash
# Compile and simulate
make simulate

# View waveforms
make wave

# Clean build files
make clean
```

## Test Scenarios

1. **Cold TLB Miss** - First access, page table walk
2. **TLB Hit** - Same page, fast translation
3. **Page Fault** - Missing page, allocation
4. **Write Access** - Dirty bit setting
5. **Multiple Pages** - TLB capacity test
6. **Re-access** - LRU/Clock behavior
7. **Policy Comparison** - Different algorithms

## Statistics

The simulator tracks:
- **Page Fault Count**: Total page faults
- **TLB Hit Count**: Successful TLB lookups
- **TLB Miss Count**: TLB misses requiring PT walk
- **Hit Rate**: TLB efficiency percentage

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| VA_WIDTH | 32 | Virtual address bits |
| PA_WIDTH | 32 | Physical address bits |
| PAGE_SIZE | 4096 | Bytes per page |
| NUM_FRAMES | 256 | Physical frames |
| TLB_ENTRIES | 32 | TLB capacity |

## Usage Example

```verilog
virtual_memory_controller #(
    .VA_WIDTH(32),
    .PA_WIDTH(32),
    .PAGE_SIZE(4096),
    .NUM_FRAMES(256)
) u_vm (
    .clk(clk),
    .rst_n(rst_n),
    .virtual_addr(cpu_va),
    .mem_read(cpu_read),
    .mem_write(cpu_write),
    .physical_addr(pa),
    .addr_valid(ready),
    .page_fault(fault),
    .replacement_policy(2'b01), // LRU
    .supervisor_mode(1'b1),
    .page_table_base(32'h80000000),
    ...
);
```

## Page Fault Handling

When a page fault occurs:
1. `page_fault` signal asserts
2. `fault_addr` contains faulting VA
3. `fault_type` indicates read/write
4. Software provides `new_pte`
5. Assert `fault_handled`
6. Translation completes

## Performance Characteristics

| Operation | Cycles |
|-----------|--------|
| TLB Hit | 1 |
| TLB Miss (PT walk) | 3-5 |
| Page Fault | Variable |

## Extensions

Possible enhancements:
- **Multi-level TLB** - L1/L2 hierarchy
- **Huge Pages** - 2MB/1GB support
- **ASID Support** - Process isolation
- **Superpages** - Reduce TLB pressure
- **Hardware PTW** - Memory interface

## License

Educational project for learning virtual memory concepts.
