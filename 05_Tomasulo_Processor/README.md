# Tomasulo Algorithm Processor

## Description
Implementation of Tomasulo's algorithm as used in IBM 360/91 floating-point unit.

## Features
- **Reservation Stations**: 2 for adder, 2 for multiplier
- **Tag-based Renaming**: Eliminates WAR/WAW hazards
- **Common Data Bus**: Broadcasts results to all waiting RS
- **CAM Matching**: Tag comparison for operand wakeup

## Reservation Station Entry
```
┌────────┬────────┬────────┬────────┬────────┬────────┐
│  Busy  │   Op   │   Vj   │   Vk   │   Qj   │   Qk   │
└────────┴────────┴────────┴────────┴────────┴────────┘
```
- Vj, Vk: Source operand values
- Qj, Qk: Tags of RS producing values (0 if ready)

## Execution Flow
1. **Issue**: Instruction enters RS, reads register file/status
2. **Execute**: When operands ready, dispatch to FU
3. **Write Result**: Broadcast on CDB, wakeup dependents

## CDB Broadcast
```
         ┌──────────────────────────────────┐
         │      Common Data Bus (CDB)       │
         └───┬────────┬────────┬───────┬───┘
             │        │        │       │
         ┌───▼───┐┌───▼───┐┌───▼───┐┌──▼──┐
         │ADD RS1││ADD RS2││MUL RS1││Regs │
         └───────┘└───────┘└───────┘└─────┘
```

## Latencies
- ADD/SUB: 2 cycles
- MUL: 4 cycles
- DIV: 8 cycles

## Waveform Visualization
- RS entries (op/tag1/tag2 fields)
- CDB broadcasts with tag matching
- Structural hazard stalls

## Running Simulation
```bash
make sim      # Run simulation
make wave     # View waveforms
make clean    # Clean files
```
