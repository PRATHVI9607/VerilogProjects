# Out-of-Order Execution Core

## Description
Out-of-order execution engine with reservation stations and reorder buffer.

## Features
- **Reorder Buffer (ROB)**: 16-entry circular buffer for in-order commit
- **Reservation Stations**: Hold pending instructions waiting for operands
- **ALU Execution Unit**: 1-cycle latency arithmetic operations
- **CDB Broadcast**: Result forwarding to dependent instructions

## Architecture
```
              ┌──────────────────────────────────────┐
              │            Instruction               │
              └──────────────┬───────────────────────┘
                             │
              ┌──────────────▼───────────────────────┐
              │     ROB Allocate + RS Issue          │
              └──────────────┬───────────────────────┘
                             │
       ┌─────────────────────┼─────────────────────┐
       │                     │                     │
┌──────▼──────┐      ┌───────▼──────┐      ┌──────▼──────┐
│  RS (ALU)   │      │  RS (MUL)    │      │  RS (MEM)   │
└──────┬──────┘      └───────┬──────┘      └──────┬──────┘
       │                     │                     │
       ▼                     ▼                     ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│     ALU     │      │  Multiplier │      │ Load/Store  │
└──────┬──────┘      └───────┬─────┘      └──────┬──────┘
       │                     │                     │
       └─────────────────────┼─────────────────────┘
                             │
              ┌──────────────▼───────────────────────┐
              │        Common Data Bus (CDB)         │
              └──────────────┬───────────────────────┘
                             │
              ┌──────────────▼───────────────────────┐
              │   ROB Complete + RS Wakeup           │
              └──────────────┬───────────────────────┘
                             │
              ┌──────────────▼───────────────────────┐
              │          ROB Commit                  │
              └──────────────────────────────────────┘
```

## Waveform Visualization
- Dispatch queues filling with instructions
- Operand tag matching on CDB broadcast
- Commit pointer advancing through ROB

## Running Simulation
```bash
make sim      # Run simulation
make wave     # View waveforms
make clean    # Clean files
```
