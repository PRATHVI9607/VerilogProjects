# Superscalar Dual-Issue CPU

## Description
Two parallel pipelines fetching/decoding/issuing independent instructions per cycle.

## Features
- Dual fetch: 2 instructions per cycle
- Register renaming: 64 physical registers
- Dual ALUs for parallel integer execution
- WAW hazard elimination via renaming
- RAW dependency detection

## Architecture
```
┌─────────────────────────────────────────────────────────┐
│                    Dual Fetch                           │
│   ┌─────────┐                      ┌─────────┐         │
│   │  PC+0   │                      │  PC+4   │         │
│   └────┬────┘                      └────┬────┘         │
└────────┼────────────────────────────────┼──────────────┘
         │                                │
┌────────▼────────────────────────────────▼──────────────┐
│                   Dual Decode                          │
│   ┌─────────┐                      ┌─────────┐         │
│   │ Decode0 │◄────RAW Check────────│ Decode1 │         │
│   └────┬────┘                      └────┬────┘         │
└────────┼────────────────────────────────┼──────────────┘
         │                                │
┌────────▼────────────────────────────────▼──────────────┐
│                 Register Rename                        │
│        RAT: Arch → Physical Mapping                    │
│        Free List: Available Physical Regs              │
└────────┬────────────────────────────────┬──────────────┘
         │                                │
┌────────▼────────┐              ┌────────▼────────┐
│     ALU 0       │              │     ALU 1       │
└────────┬────────┘              └────────┬────────┘
         │                                │
         └────────────┬───────────────────┘
                      │
              Physical Reg File
```

## Waveform Visualization
- Dual PC increments (PC+0, PC+4)
- Parallel decode waves
- RAW hazard detection signals
- Dual ALU result buses

## Running Simulation
```bash
make sim      # Run simulation
make wave     # View waveforms
make clean    # Clean files
```
