# Project 10: Memory BIST (Built-In Self-Test)

## Overview

This project implements a Memory Built-In Self-Test (MBIST) controller in Verilog. It provides automated testing of SRAM memories using various test algorithms including March tests and pseudo-random patterns.

## Features

- **March Test Algorithms** - March C-, March C+, March B
- **LFSR Pattern Generator** - Pseudo-random test patterns
- **Fault Detection** - Stuck-at, transition, coupling faults
- **Fault Diagnosis** - Identifies fault type and location
- **Progress Reporting** - Real-time test progress
- **Configurable Memory Size** - Parameterized design

## Architecture

```
+------------------+     +------------------+
|   BIST Control   |---->| March Generator  |
|                  |     +------------------+
|   - Start/Stop   |            |
|   - Mode Select  |     +------------------+
|   - Status       |---->| LFSR Generator   |
+--------+---------+     +------------------+
         |                       |
         v                       v
+--------+-----------------------+--------+
|            Memory Interface             |
|  (CE, WE, ADDR, WDATA, RDATA)          |
+--------+--------------------------------+
         |
         v
+--------+---------+
| Memory Under Test|
|      (MUT)       |
+------------------+
```

## File Structure

```
10_Memory_BIST/
├── rtl/
│   ├── lfsr_generator.v    # PRBS pattern generator
│   ├── march_generator.v   # March test controller
│   └── memory_bist.v       # Top-level BIST
├── tb/
│   └── tb_memory_bist.v    # Testbench
├── Makefile
└── README.md
```

## Module Descriptions

### lfsr_generator.v
32-bit LFSR for pseudo-random patterns:
- Maximal-length sequence
- Configurable seed
- Pattern and inverted pattern outputs

### march_generator.v
March test algorithm implementation:
- March C- (detects all stuck-at faults)
- Ascending/descending address sequences
- Read-modify-write operations

### memory_bist.v
Top-level BIST controller:
- Test mode selection
- Memory interface multiplexing
- Fault analysis and reporting
- Progress tracking

## March C- Algorithm

March C- is a 10N complexity test that detects:
- All stuck-at faults (SAF)
- All transition faults (TF)
- All coupling faults (CF)

### March Elements

```
M0: ⇑ (w0)      - Write 0, ascending
M1: ⇑ (r0, w1)  - Read 0, write 1, ascending
M2: ⇑ (r1, w0)  - Read 1, write 0, ascending
M3: ⇓ (r0, w1)  - Read 0, write 1, descending
M4: ⇓ (r1, w0)  - Read 1, write 0, descending
M5: ⇓ (r0)      - Read 0, descending
```

### Notation
- ⇑ : Ascending address order
- ⇓ : Descending address order
- w0/w1 : Write 0/1
- r0/r1 : Read and expect 0/1

## Fault Types

| Fault | Code | Description |
|-------|------|-------------|
| SAF-0 | 001 | Stuck-at-0: Cell always reads 0 |
| SAF-1 | 010 | Stuck-at-1: Cell always reads 1 |
| TF | 011 | Transition: Can't switch 0→1 or 1→0 |
| CF | 100 | Coupling: One cell affects another |
| AF | 101 | Address: Decoder fault |

## LFSR Specification

- **Polynomial**: x³² + x²² + x² + x + 1
- **Period**: 2³² - 1 cycles
- **Seed**: 0xACE1CAFE (configurable)

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

1. **Good Memory** - March C- passes
2. **SAF-0 Fault** - Stuck-at-0 detection
3. **SAF-1 Fault** - Stuck-at-1 detection
4. **Random Patterns** - LFSR-based test
5. **Multiple Algorithms** - Different test modes

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| ADDR_WIDTH | 10 | Address bus width |
| DATA_WIDTH | 32 | Data bus width |
| MEM_DEPTH | 1024 | Memory depth |

## Usage Example

```verilog
memory_bist #(
    .ADDR_WIDTH(10),
    .DATA_WIDTH(32),
    .MEM_DEPTH(1024)
) u_bist (
    .clk(clk),
    .rst_n(rst_n),
    .bist_start(start),
    .test_mode(3'd0), // March C-
    .bist_done(done),
    .bist_pass(pass),
    .bist_fail(fail),
    .mem_ce(sram_ce),
    .mem_we(sram_we),
    .mem_addr(sram_addr),
    .mem_wdata(sram_din),
    .mem_rdata(sram_dout),
    ...
);
```

## Test Modes

| Mode | Code | Algorithm |
|------|------|-----------|
| 0 | 000 | March C- |
| 1 | 001 | March C+ |
| 2 | 010 | LFSR Random |
| 3 | 011 | Checkerboard |
| 4 | 100 | Walking Ones |
| 5 | 101 | Walking Zeros |
| 6 | 110 | All Patterns |

## Test Complexity

| Algorithm | Complexity | Coverage |
|-----------|------------|----------|
| March C- | 10N | SAF, TF, CF |
| March C+ | 10N | SAF, TF, CF |
| March B | 17N | SAF, TF, CF, NPSF |
| LFSR | 2N | Random patterns |

Where N = number of memory words.

## Performance

| Memory Size | March C- Time |
|-------------|---------------|
| 256 words | ~2,560 cycles |
| 1K words | ~10,240 cycles |
| 4K words | ~40,960 cycles |

## Fault Coverage

March C- provides:
- 100% stuck-at fault coverage
- 100% transition fault coverage
- 100% coupling fault coverage

## Applications

- **Manufacturing Test** - Production testing
- **At-Speed Test** - Timing verification
- **Field Diagnosis** - Failure analysis
- **Reliability** - Periodic memory check

## License

Educational project for learning memory testing concepts.
