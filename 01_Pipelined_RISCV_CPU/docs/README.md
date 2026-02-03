# Pipelined RISC-V CPU

A fully functional **5-stage pipelined RV32I CPU** implementation in Verilog.

## Features

- ✅ Full RV32I base integer instruction set
- ✅ 5-stage pipeline (IF/ID/EX/MEM/WB)
- ✅ Data forwarding (EX→EX, MEM→EX)
- ✅ Load-use hazard detection with stalling
- ✅ Branch/jump handling with pipeline flush
- ✅ Flag registers: Zero (Z), Negative (N), Carry (C), Overflow (V)
- ✅ Automated test verification

## Quick Start

```bash
make check    # Check for errors & warnings
make run      # Compile and run simulation
make wave     # Run and open waveforms
make help     # Show all commands
```

## Documentation

- 📖 [README](docs/README.md) - Complete project documentation
- 📐 [Instruction Format](docs/INSTRUCTION_FORMAT.md) - RV32I encoding details
- 🏗️ [Design Architecture](docs/DESIGN_ARCHITECTURE.md) - Pipeline architecture

## Pipeline Architecture

```
┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐
│  IF  │───▶│  ID  │───▶│  EX  │───▶│ MEM  │───▶│  WB  │
│ IMEM │    │RegFile│   │ ALU  │    │ DMEM │    │ MUX  │
│  PC  │    │Decode │   │FLAGS │    │      │    │      │
└──────┘    └──────┘    └──────┘    └──────┘    └──────┘
                            ▲           │           │
                            └───────────┴───────────┘
                               Forwarding Paths
```

## File Structure

```
01_Pipelined_RISCV_CPU/
├── docs/                      # Documentation
│   ├── README.md
│   ├── INSTRUCTION_FORMAT.md
│   └── DESIGN_ARCHITECTURE.md
├── rtl/                       # Verilog RTL
│   ├── riscv_pkg.v           # Definitions
│   ├── instruction_fetch.v   # IF stage
│   ├── instruction_decode.v  # ID stage
│   ├── execute.v             # EX stage + flags
│   ├── memory_stage.v        # MEM stage
│   ├── writeback.v           # WB stage
│   ├── forwarding_unit.v     # Data forwarding
│   ├── hazard_unit.v         # Hazard detection
│   └── riscv_cpu.v           # Top-level
├── tb/                        # Testbenches
├── synth/                     # Block diagrams
├── Makefile                   # Build automation
└── program.hex                # Test program
```

## Test Results

```
PASS: x3 = 15 (ADD)
PASS: x4 = -5 (SUB)
PASS: x5 = 0 (AND)
PASS: x6 = 15 (OR)
PASS: x7 = 15 (XOR)
ALL TESTS PASSED!
```

## Author

Created for Advanced Digital Logic Design course.
