# Project 11: Interrupt-Enabled Pipeline

## Overview

This project implements a 5-stage RISC-V pipeline with full interrupt and exception support. It includes a vectored interrupt controller, exception handling, and precise interrupt support with proper pipeline flushing.

## Features

- **5-Stage Pipeline** - IF, ID, EX, MEM, WB
- **Vectored Interrupts** - 16 external + timer + software
- **Priority Encoding** - Configurable interrupt priorities
- **Exception Handling** - RISC-V standard exceptions
- **Privilege Modes** - Machine, Supervisor, User
- **Precise Interrupts** - Clean pipeline state on trap
- **CSR Support** - mstatus, mtvec, mepc, mcause, etc.

## Architecture

```
               +------------------+
               | Interrupt Lines  |
               | (16 external)    |
               +--------+---------+
                        |
               +--------v---------+
               |   Interrupt      |
               |   Controller     |
               |  (Priority Enc)  |
               +--------+---------+
                        |
                        v
+-----+  +----+  +----+  +----+  +----+
| IF  |->| ID |->| EX |->|MEM |->| WB |
+-----+  +----+  +----+  +----+  +----+
   ^        |       |       |       |
   |        v       v       v       v
   |    +--------------------------------+
   |    |     Exception Handler          |
   |    |   (Illegal, ECALL, EBREAK)    |
   |    +---------------+----------------+
   |                    |
   |    +---------------v----------------+
   +----+    Pipeline Flush Control      |
        |    (Precise Interrupts)        |
        +--------------------------------+
```

## File Structure

```
11_Interrupt_Pipeline/
├── rtl/
│   ├── interrupt_controller.v   # IRQ prioritization
│   ├── exception_handler.v      # Exception processing
│   ├── pipeline_flush_ctrl.v    # Flush management
│   └── interrupt_pipeline.v     # Top-level pipeline
├── tb/
│   └── tb_interrupt_pipeline.v  # Testbench
├── Makefile
└── README.md
```

## Module Descriptions

### interrupt_controller.v
Vectored interrupt controller:
- 16 external interrupt lines
- Priority-based selection
- Edge/level triggering
- Interrupt masking

### exception_handler.v
RISC-V exception handling:
- Illegal instruction detection
- ECALL/EBREAK
- Page faults
- Misalignment exceptions
- Exception delegation

### pipeline_flush_ctrl.v
Precise interrupt support:
- Pipeline draining
- State saving
- PC redirection
- Clean interrupt entry

### interrupt_pipeline.v
Complete pipeline integration:
- 5-stage pipeline
- CSR implementation
- Privilege modes
- Trap handling

## Interrupt Sources

| Source | Priority | Description |
|--------|----------|-------------|
| External 0-15 | Configurable | External IRQ lines |
| Timer | High | Timer interrupt |
| Software | Medium | Software interrupt |

## Exception Types

| Code | Name | Cause |
|------|------|-------|
| 0 | Misaligned Fetch | PC not aligned |
| 2 | Illegal Instruction | Invalid opcode |
| 3 | Breakpoint | EBREAK instruction |
| 4 | Misaligned Load | Load address |
| 6 | Misaligned Store | Store address |
| 8-11 | ECALL | System call |
| 12 | Instruction Page Fault | No execute permission |
| 13 | Load Page Fault | No read permission |
| 15 | Store Page Fault | No write permission |

## CSR Registers

| CSR | Address | Description |
|-----|---------|-------------|
| mstatus | 0x300 | Machine status |
| mie | 0x304 | Interrupt enable |
| mtvec | 0x305 | Trap vector base |
| mepc | 0x341 | Exception PC |
| mcause | 0x342 | Trap cause |
| mtval | 0x343 | Trap value |
| mip | 0x344 | Interrupt pending |

## Privilege Modes

| Mode | Encoding | Description |
|------|----------|-------------|
| Machine | 11 | Highest privilege |
| Supervisor | 01 | OS kernel |
| User | 00 | Applications |

## Trap Flow

1. **Exception/Interrupt Detected**
2. **Pipeline Drain** - Let in-flight complete
3. **State Save** - PC to mepc, cause to mcause
4. **Mode Change** - Update mstatus.MPP
5. **PC Redirect** - Jump to mtvec
6. **Handler Execute** - Service trap
7. **MRET** - Return to original code

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

1. **Basic Execution** - Pipeline operation
2. **External Interrupt** - IRQ assertion
3. **Multiple Interrupts** - Priority handling
4. **Timer Interrupt** - Periodic interrupt
5. **Software Interrupt** - IPI simulation
6. **Exception** - ECALL handling

## mstatus Layout

```
31      22 21   20   19   18   17 16:15 14:13 12:11  7    3    1    0
+--------+----+----+----+----+----+-----+-----+-----+----+----+----+
| WPRI   |TSR |TW  |TVM |MXR |SUM |MPRV | FS  | MPP |MPIE| MIE|SPIE|SIE|
+--------+----+----+----+----+----+-----+-----+-----+----+----+----+
```

Key fields:
- **MIE** (bit 3): Machine interrupt enable
- **MPIE** (bit 7): Previous MIE value
- **MPP** (bits 12:11): Previous privilege mode

## Usage Example

```verilog
interrupt_pipeline #(
    .XLEN(32),
    .NUM_IRQS(16)
) u_cpu (
    .clk(clk),
    .rst_n(rst_n),
    .imem_addr(imem_addr),
    .imem_req(imem_req),
    .imem_rdata(imem_data),
    .imem_ready(imem_valid),
    .dmem_addr(dmem_addr),
    .dmem_read(dmem_rd),
    .dmem_write(dmem_wr),
    .dmem_wdata(dmem_wdata),
    .dmem_rdata(dmem_rdata),
    .dmem_ready(dmem_valid),
    .irq_lines(external_irqs),
    .timer_irq(timer_expired),
    .sw_irq(ipi),
    .priv_mode(current_priv),
    .pc_out(pc),
    .halted(cpu_halt)
);
```

## Interrupt Handler Example

```assembly
# Handler at mtvec address
handler:
    # Save context
    csrrw sp, mscratch, sp  # Swap sp with mscratch
    sw ra, 0(sp)
    sw t0, 4(sp)
    
    # Read cause
    csrr t0, mcause
    
    # Handle interrupt
    # ...
    
    # Restore context
    lw t0, 4(sp)
    lw ra, 0(sp)
    csrrw sp, mscratch, sp
    
    mret                     # Return from interrupt
```

## Performance

| Metric | Value |
|--------|-------|
| Pipeline Stages | 5 |
| Interrupt Latency | 3-5 cycles |
| Context Save | Software |

## Extensions

Possible enhancements:
- **Nested Interrupts** - mstatus.MIE handling
- **Fast Interrupt** - Hardware context save
- **CLIC** - Core Local Interrupt Controller
- **PLIC** - Platform Level Interrupt Controller

## License

Educational project for learning interrupt handling concepts.
