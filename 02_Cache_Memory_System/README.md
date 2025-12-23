# Cache Memory System

## Description
Implements both direct-mapped and 2-way set-associative cache with write-back policy.

## Features
- **Direct-Mapped Cache**: 1KB, 32-byte blocks, 32 sets
- **Set-Associative Cache**: 1KB, 32-byte blocks, 16 sets, 2 ways
- Write-back policy with dirty bits
- LRU replacement for set-associative
- Tag/index/offset address decoding

## Cache Organization
```
Direct-Mapped (32 sets):
Address: [31:10 Tag][9:5 Index][4:0 Offset]

Set-Associative (16 sets, 2 ways):
Address: [31:9 Tag][8:5 Index][4:0 Offset]
```

## State Machine
```
IDLE → COMPARE → [HIT] → IDLE
              ↓
       [MISS+DIRTY] → WRITEBACK → ALLOCATE → UPDATE → IDLE
              ↓
       [MISS+CLEAN] → ALLOCATE → UPDATE → IDLE
```

## Waveform Visualization
- Tag match signals
- Valid/dirty bit assertions
- LRU counter updates
- Writeback events

## Running Simulation
```bash
make sim      # Run simulation
make wave     # View in GTKWave
make clean    # Clean files
```

## File Structure
```
02_Cache_Memory_System/
├── rtl/
│   ├── cache_pkg.v
│   ├── direct_mapped_cache.v
│   ├── set_associative_cache.v
│   └── main_memory.v
├── tb/
│   └── tb_cache_system.v
├── Makefile
└── README.md
```
