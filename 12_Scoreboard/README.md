# CDC 6600 Style Scoreboard

A Verilog implementation of the CDC 6600 scoreboard algorithm for dynamic instruction scheduling and out-of-order execution.

## Overview

The scoreboard is a centralized hardware mechanism that:
- Tracks the status of all functional units
- Detects and resolves data hazards (RAW, WAW, WAR)
- Controls instruction issue, operand read, and result write-back
- Enables out-of-order execution while preserving program correctness

## Architecture

```
                    +------------------+
    Instruction --> |   Issue Logic    |
                    +--------+---------+
                             |
                    +--------v---------+
                    |  FU Status Table |
                    +--------+---------+
                             |
         +-------------------+-------------------+
         |         |         |         |
    +----v---+ +---v----+ +--v-----+ +-v------+
    |  ALU0  | |  ALU1  | |  MUL   | |  DIV   |
    | 1 cyc  | | 1 cyc  | | 3 cyc  | | 8 cyc  |
    +----+---+ +---+----+ +--+-----+ +-+------+
         |         |         |         |
         +---------+---------+---------+
                             |
                    +--------v---------+
                    |  Register File   |
                    +------------------+
```

## CDC 6600 Scoreboard Algorithm

### Four Stages of Instruction Processing

1. **Issue**: Decode and check for structural and WAW hazards
   - Wait if required FU is busy (structural hazard)
   - Wait if another instruction writes to same destination (WAW)

2. **Read Operands**: Wait for source operands to be available
   - Read when producing instruction has written to register
   - Resolves RAW (Read After Write) hazards

3. **Execution**: Execute operation in functional unit
   - Functional unit notifies scoreboard when done

4. **Write Result**: Write back and release FU
   - Wait if another FU is reading our source (WAR)
   - Update register file

### Data Hazards

| Hazard | Type | Description | Resolution |
|--------|------|-------------|------------|
| RAW | True Dependency | Read After Write | Stall read until write completes |
| WAW | Output Dependency | Write After Write | Stall issue until first write completes |
| WAR | Anti-Dependency | Write After Read | Stall write until read completes |

## Modules

### fu_status.v
Functional Unit Status Table tracking:
- **Busy**: FU is in use
- **Op**: Operation being performed
- **Fi**: Destination register
- **Fj, Fk**: Source register names
- **Qj, Qk**: FUs producing Fj, Fk
- **Rj, Rk**: Operand ready flags

### scoreboard_issue.v
Issue logic handling:
- WAW hazard detection
- Structural hazard detection
- FU type mapping (ALU, MUL, DIV)
- Free FU selection

### functional_unit.v
Parameterized execution unit:
- Configurable latency
- Pipeline stages for multi-cycle ops
- Operation execution (ADD, SUB, MUL, DIV, etc.)

### register_file.v
32x32-bit register file with:
- 2 read ports (Fj, Fk operands)
- 1 write port (Fi result)
- R0 hardwired to zero

### scoreboard.v
Top-level integration:
- Instantiates all components
- Implements control state machine
- Arbitrates register file access

## Functional Units

| Unit | Type | Latency | Operations |
|------|------|---------|------------|
| ALU0 | Integer | 1 cycle | ADD, SUB, AND, OR, XOR |
| ALU1 | Integer | 1 cycle | ADD, SUB, AND, OR, XOR |
| MUL | Multiply | 3 cycles | MUL |
| DIV | Divide | 8 cycles | DIV |

## Operation Codes

| Code | Operation | Description |
|------|-----------|-------------|
| 0 | ADD | Addition |
| 1 | SUB | Subtraction |
| 2 | AND | Bitwise AND |
| 3 | OR | Bitwise OR |
| 4 | XOR | Bitwise XOR |
| 5 | MUL | Multiplication |
| 6 | DIV | Division |

## Building and Running

```bash
# Compile and simulate
make sim

# View waveforms
make wave

# Lint check
make lint

# Clean generated files
make clean
```

## Testbench Scenarios

1. **Simple ADD**: Basic instruction execution
2. **Independent ops**: Parallel execution on multiple ALUs
3. **RAW hazard**: Instruction depends on previous result
4. **WAW hazard**: Two instructions write same register
5. **WAR hazard**: Write destination read by previous instruction
6. **Structural hazard**: All ALUs busy
7. **Long division**: Mix of long and short latency operations
8. **Dependent chain**: Series of dependent multiplications
9. **Stress test**: Rapid instruction issue

## Example Trace

```
Cycle  Instruction     Issue  Read  Exec  Write
-----  --------------  -----  ----  ----  -----
  1    MUL R1,R2,R3      1      2    2-4     5
  2    ADD R4,R1,R5      -      -     -      -    (RAW on R1)
  3    ADD R4,R1,R5      -      -     -      -    (waiting)
  4    ADD R4,R1,R5      -      -     -      -    (waiting)
  5    ADD R4,R1,R5      5      6     6      7    (R1 ready)
```

## Historical Context

The scoreboard was invented by Seymour Cray for the CDC 6600 (1964), the first supercomputer to use this technique. Key innovations:
- First commercial machine with out-of-order execution
- 10 functional units operated in parallel
- 60-bit word size, ~1 MFLOPS performance
- Influenced all subsequent high-performance processors

## Limitations

Compared to Tomasulo's algorithm:
- No register renaming (limited WAW/WAR handling)
- Single-issue (one instruction per cycle)
- No forwarding between functional units
- Centralized control (potential bottleneck)

## Files

```
12_Scoreboard/
├── rtl/
│   ├── fu_status.v          # FU status table
│   ├── scoreboard_issue.v   # Issue logic
│   ├── functional_unit.v    # Parameterized FU
│   ├── register_file.v      # Register file
│   └── scoreboard.v         # Top module
├── tb/
│   └── tb_scoreboard.v      # Testbench
├── Makefile
└── README.md
```

## References

1. Thornton, J.E. "Design of a Computer: The Control Data 6600" (1970)
2. Hennessy & Patterson "Computer Architecture: A Quantitative Approach"
3. CDC 6600 Reference Manual (1964)

## License

Educational use - Computer Architecture study project.
