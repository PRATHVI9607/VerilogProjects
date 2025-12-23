# Pipelined RISC-V CPU

## Description
A 5-stage pipelined RV32I CPU implementation with:
- **IF** (Instruction Fetch) - Fetches instructions from memory
- **ID** (Instruction Decode) - Decodes instructions and reads register file
- **EX** (Execute) - ALU operations and branch resolution
- **MEM** (Memory) - Data memory read/write operations
- **WB** (Writeback) - Writes results back to register file

## Features
- Full RV32I base integer instruction set support
- Data forwarding to resolve RAW hazards
- Hazard detection for load-use stalls
- Branch/jump handling with pipeline flush

## Pipeline Diagram
```
     ┌────┐   ┌────┐   ┌────┐   ┌────┐   ┌────┐
     │ IF │──▶│ ID │──▶│ EX │──▶│MEM │──▶│ WB │
     └────┘   └────┘   └────┘   └────┘   └────┘
                         ▲         │
                         └─────────┘
                        Forwarding Path
```

## Forwarding Mux Selections
- `FWD_NONE (00)`: Use register file value
- `FWD_EX_MEM (01)`: Forward from EX/MEM pipeline register
- `FWD_MEM_WB (10)`: Forward from MEM/WB pipeline register

## Running Simulation
```bash
make sim      # Compile and run simulation
make wave     # Open GTKWave to view waveforms
make clean    # Clean generated files
```

## GTKWave Visualization
The VCD file shows:
- Pipeline stages flowing left-to-right
- Forwarding mux selections highlighted
- Stall and flush signals
- Register file updates

## File Structure
```
01_Pipelined_RISCV_CPU/
├── rtl/
│   ├── riscv_pkg.v         # Common definitions
│   ├── instruction_fetch.v  # IF stage
│   ├── instruction_decode.v # ID stage
│   ├── execute.v           # EX stage
│   ├── memory_stage.v      # MEM stage
│   ├── writeback.v         # WB stage
│   ├── forwarding_unit.v   # Data forwarding
│   ├── hazard_unit.v       # Hazard detection
│   └── riscv_cpu.v         # Top module
├── tb/
│   └── tb_riscv_cpu.v      # Testbench
├── Makefile
└── README.md
```
