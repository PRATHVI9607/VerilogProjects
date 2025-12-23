# Project 8: Cache Coherence Protocol (MESI)

## Overview

This project implements a MESI (Modified, Exclusive, Shared, Invalid) cache coherence protocol for a multi-processor system. The design supports up to 4 CPUs with private caches connected via a snoop bus.

## Features

- **MESI Protocol** - Full 4-state coherence protocol
- **Snoop Bus** - Broadcast-based coherence mechanism
- **Round-Robin Arbitration** - Fair bus access
- **Write-Back Policy** - Reduced memory bandwidth
- **Multi-Processor Support** - Up to 4 CPUs

## MESI Protocol States

```
+----------+     BusRd     +----------+
| Modified | ------------> |  Shared  |
+----------+               +----------+
     ^                          |
     | Write                    | BusRdX/BusUpgr
     |                          v
+----------+               +----------+
| Exclusive| <------------ | Invalid  |
+----------+    BusRd      +----------+
     |         (exclusive)      ^
     |                          |
     +--------------------------+
            BusRdX
```

### State Descriptions

| State | Description | Data | Shared |
|-------|-------------|------|--------|
| Modified (M) | Dirty, exclusive owner | Valid | No |
| Exclusive (E) | Clean, exclusive owner | Valid | No |
| Shared (S) | Clean, may have copies | Valid | Yes |
| Invalid (I) | No valid data | Invalid | N/A |

## Architecture

```
    CPU0       CPU1       CPU2       CPU3
      |          |          |          |
  +-------+  +-------+  +-------+  +-------+
  | Cache |  | Cache |  | Cache |  | Cache |
  | MESI  |  | MESI  |  | MESI  |  | MESI  |
  +---+---+  +---+---+  +---+---+  +---+---+
      |          |          |          |
      +----------+----------+----------+
                     |
              +------+------+
              |  Snoop Bus  |
              | (Arbiter)   |
              +------+------+
                     |
              +------+------+
              | Main Memory |
              +-------------+
```

## File Structure

```
08_Cache_Coherence/
├── rtl/
│   ├── mesi_cache_line.v      # Single MESI cache line
│   ├── mesi_cache.v           # Per-CPU cache controller
│   ├── snoop_bus.v            # Bus arbiter and snoop logic
│   └── coherent_cache_system.v # Top-level system
├── tb/
│   └── tb_cache_coherence.v   # Testbench
├── Makefile
└── README.md
```

## Module Descriptions

### mesi_cache_line.v
Single cache line with MESI state machine:
- Tag and data storage
- State transitions based on CPU and snoop requests
- Dirty bit tracking

### mesi_cache.v
Per-processor cache controller:
- Hit/miss detection
- Bus transaction generation
- Cache line array management

### snoop_bus.v
Shared bus with snoop support:
- Round-robin arbitration
- Snoop request broadcasting
- Memory interface

### coherent_cache_system.v
Top-level integration:
- Multiple cache instances
- Bus interconnection
- Memory interface

## Bus Transactions

| Transaction | Trigger | Action |
|-------------|---------|--------|
| BusRd | Read miss | Request line for reading |
| BusRdX | Write miss | Request line with exclusive access |
| BusUpgr | Write hit in Shared | Invalidate other copies |

## State Transitions

### CPU Actions
- **Read Hit**: No state change
- **Read Miss**: I→S (shared) or I→E (exclusive)
- **Write Hit (E/M)**: E→M, M stays M
- **Write Hit (S)**: S→M (with BusUpgr)
- **Write Miss**: I→M (with BusRdX)

### Snoop Actions
- **BusRd (M)**: M→S, supply data
- **BusRd (E)**: E→S
- **BusRdX (M/E/S)**: →I
- **BusUpgr (S)**: S→I

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

1. **Cold Read Miss** - First access, I→E transition
2. **Read Hit** - Data in Exclusive state
3. **Read Sharing** - E→S transition when another CPU reads
4. **Write Invalidation** - S→I transitions in other caches
5. **Modified Read** - M→S with data supply
6. **Parallel Access** - Multiple CPUs, different addresses
7. **False Sharing** - Different words, same cache line

## Performance Characteristics

| Parameter | Value |
|-----------|-------|
| Cache Lines | 64 per CPU |
| Line Size | 32 bytes |
| Associativity | Direct-mapped |
| Number of CPUs | 4 |
| Bus Width | 256 bits (1 line) |

## Coherence Guarantees

1. **Single-Writer**: Only one cache can have M state
2. **Multiple-Reader**: Multiple caches can share S state
3. **Data Consistency**: Modified data is always current
4. **Write Propagation**: Writes visible to all processors

## Protocol Correctness

The MESI protocol ensures:
- No two caches have conflicting copies
- Writes are serialized through bus transactions
- Reads always return most recent write
- Memory is updated before eviction (write-back)

## Usage Example

```verilog
coherent_cache_system #(
    .NUM_CPUS(4),
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .CACHE_LINES(64),
    .LINE_SIZE(32)
) u_system (
    .clk(clk),
    .rst_n(rst_n),
    .cpu_addr({addr3, addr2, addr1, addr0}),
    .cpu_read({rd3, rd2, rd1, rd0}),
    .cpu_write({wr3, wr2, wr1, wr0}),
    .cpu_write_data({wdata3, wdata2, wdata1, wdata0}),
    .cpu_read_data({rdata3, rdata2, rdata1, rdata0}),
    .cpu_ready({ready3, ready2, ready1, ready0}),
    ...
);
```

## Extensions

Possible enhancements:
- **MOESI Protocol** - Add Owned state
- **Directory-Based** - Replace snoop bus
- **Set-Associative** - More cache capacity
- **Write Buffer** - Hide write latency

## License

Educational project for learning cache coherence concepts.
