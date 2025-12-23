# Project 7: TLB and MMU Implementation

## Overview

This project implements a Translation Lookaside Buffer (TLB) and Memory Management Unit (MMU) in Verilog. The design follows the RISC-V Sv32 virtual memory scheme with a 2-level page table structure.

## Features

- **16-entry fully associative TLB**
- **Sv32 Page Table Format** (2-level, 4KB pages)
- **Pseudo-LRU replacement policy**
- **ASID (Address Space Identifier) support**
- **Global page support**
- **Page Table Walker (PTW)** for TLB miss handling
- **SFENCE.VMA support** for TLB invalidation
- **Permission checking** (R/W/X, User/Supervisor)

## Architecture

```
                    +------------------+
                    |       CPU        |
                    +--------+---------+
                             |
                    Virtual Address
                             |
                    +--------v---------+
                    |       MMU        |
                    |  +------------+  |
                    |  |    TLB     |  |
                    |  | (16 entry) |  |
                    |  +-----+------+  |
                    |        |         |
                    |    Hit | Miss    |
                    |        v         |
                    |  +------------+  |
                    |  |    PTW     |  |
                    |  | (2-level)  |  |
                    |  +-----+------+  |
                    +--------+---------+
                             |
                    Physical Address
                             |
                    +--------v---------+
                    |   Main Memory    |
                    +------------------+
```

## File Structure

```
07_TLB_MMU/
├── rtl/
│   ├── tlb_entry.v        # Single TLB entry
│   ├── tlb.v              # Full TLB with LRU
│   ├── page_table_walker.v # PTW FSM
│   └── mmu.v              # Top-level MMU
├── tb/
│   └── tb_mmu.v           # Testbench
├── Makefile
└── README.md
```

## Module Descriptions

### tlb_entry.v
Single TLB entry storing:
- Virtual Page Number (VPN) - 20 bits
- Physical Page Number (PPN) - 20 bits
- Address Space ID (ASID) - 8 bits
- Page flags (R, W, X, U)
- Global bit
- Valid bit

### tlb.v
16-entry fully associative TLB with:
- Parallel tag matching
- Pseudo-LRU replacement
- ASID-aware invalidation
- Global page support (ignores ASID)

### page_table_walker.v
Hardware PTW implementing Sv32 2-level page table walk:
- Level 1 (1024 entries × 4 bytes = 4KB)
- Level 0 (1024 entries × 4 bytes = 4KB)
- Superpage support (4MB pages)
- Fault detection

### mmu.v
Top-level MMU integrating all components:
- TLB lookup
- PTW management
- Permission checking
- SFENCE.VMA handling

## Page Table Entry Format (Sv32)

```
31          10 9  8 7 6 5 4 3 2 1 0
+-------------+----+-+-+-+-+-+-+-+-+
|     PPN     |RSW |D|A|G|U|X|W|R|V|
+-------------+----+-+-+-+-+-+-+-+-+
```

- **PPN**: Physical Page Number
- **RSW**: Reserved for Software
- **D**: Dirty
- **A**: Accessed
- **G**: Global
- **U**: User accessible
- **X**: Execute permission
- **W**: Write permission
- **R**: Read permission
- **V**: Valid

## Virtual Address Format

```
31        22 21       12 11         0
+----------+-----------+------------+
|  VPN[1]  |   VPN[0]  | Page Offset|
+----------+-----------+------------+
```

## Simulation

### Prerequisites
- Icarus Verilog (`iverilog`)
- VVP (Verilog simulator)
- GTKWave (waveform viewer)

### Running Tests

```bash
# Compile and simulate
make simulate

# View waveforms
make wave

# Clean build files
make clean
```

## Test Cases

1. **Pass-through Mode**: MMU disabled, virtual = physical
2. **TLB Miss/Hit**: First access misses, second hits
3. **Page Table Walk**: PTW fetches from memory
4. **SFENCE.VMA**: TLB invalidation
5. **Multiple Pages**: Fill TLB with entries
6. **Write Permissions**: Check R/W/X flags
7. **LRU Replacement**: Test entry eviction

## Performance Characteristics

| Parameter | Value |
|-----------|-------|
| TLB Entries | 16 |
| TLB Associativity | Fully Associative |
| Page Size | 4KB |
| Virtual Address | 32 bits |
| Physical Address | 32 bits |
| TLB Hit Latency | 1 cycle |
| TLB Miss Latency | ~10 cycles (PTW) |

## SATP Register Format

```
31    30        22 21                 0
+-----+----------+--------------------+
|MODE |   ASID   |        PPN         |
+-----+----------+--------------------+
```

- **MODE**: 0 = bare (no translation), 1 = Sv32
- **ASID**: Address Space Identifier
- **PPN**: Physical Page Number of root page table

## Usage Example

```verilog
mmu #(
    .TLB_ENTRIES(16),
    .VPN_WIDTH(20),
    .PPN_WIDTH(20),
    .ASID_WIDTH(8)
) u_mmu (
    .clk(clk),
    .rst_n(rst_n),
    .cpu_addr(virtual_addr),
    .cpu_read(mem_read),
    .cpu_write(mem_write),
    .cpu_asid(current_asid),
    .cpu_supervisor(priv_mode),
    .cpu_ready(addr_ready),
    .phys_addr(physical_addr),
    .page_fault(page_fault),
    .access_violation(access_fault),
    .satp(satp_reg),
    .mmu_enable(mmu_on),
    ...
);
```

## License

Educational project for learning computer architecture concepts.
