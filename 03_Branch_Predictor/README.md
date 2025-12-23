# Branch Predictor Module

## Description
GShare branch predictor with Branch Target Buffer (BTB).

## Features
- 8-bit Global History Register (GHR)
- 256-entry Pattern History Table (PHT)
- 2-bit saturating counters (SN/WN/WT/ST)
- 64-entry Branch Target Buffer
- XOR-based history indexing

## GShare Algorithm
```
PHT_Index = PC[9:2] XOR GHR[7:0]
Prediction = PHT[PHT_Index][1]  // MSB of 2-bit counter
```

## 2-Bit Saturating Counter States
```
SN (00) ──T──▶ WN (01) ──T──▶ WT (10) ──T──▶ ST (11)
   ◀──N──          ◀──N──          ◀──N──
```

## Update on Branch Resolution
1. Shift actual outcome into GHR
2. Update PHT counter at XOR index
3. Update BTB with target address

## Waveform Visualization
- GHR shift register updates
- Counter increment/decrement
- Misprediction flag assertions
- BTB hit/miss signals

## Running Simulation
```bash
make sim      # Run simulation
make wave     # View waveforms
make clean    # Clean files
```

## File Structure
```
03_Branch_Predictor/
├── rtl/
│   ├── gshare_predictor.v
│   ├── btb.v
│   └── branch_predictor.v
├── tb/
│   └── tb_branch_predictor.v
├── Makefile
└── README.md
```
