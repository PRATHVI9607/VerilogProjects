# Design Architecture

Detailed architecture documentation for the 5-stage Pipelined RISC-V CPU.

---

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Pipeline Stages](#pipeline-stages)
- [Data Path](#data-path)
- [Control Path](#control-path)
- [Hazard Handling](#hazard-handling)
- [Forwarding Unit](#forwarding-unit)
- [Flag Registers](#flag-registers)
- [Memory Architecture](#memory-architecture)
- [Module Descriptions](#module-descriptions)
- [Signal Reference](#signal-reference)

---

## 🏗️ Architecture Overview

### Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                  PIPELINED RISC-V CPU                                           │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│  ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐              │
│  │   IF    │      │   ID    │      │   EX    │      │   MEM   │      │   WB    │              │
│  │         │      │         │      │         │      │         │      │         │              │
│  │ ┌─────┐ │ ────▶│ ┌─────┐ │ ────▶│ ┌─────┐ │ ────▶│ ┌─────┐ │ ────▶│ ┌─────┐ │              │
│  │ │ PC  │ │ IF/ID│ │Decode│ │ID/EX│ │ ALU │ │EX/MEM│ │DMEM │ │MEM/WB│ │ MUX │ │              │
│  │ └─────┘ │      │ └─────┘ │      │ └─────┘ │      │ └─────┘ │      │ └─────┘ │              │
│  │ ┌─────┐ │      │ ┌─────┐ │      │ ┌─────┐ │      │         │      │         │              │
│  │ │IMEM │ │      │ │RegF │ │      │ │FLAGS│ │      │         │      │    │    │              │
│  │ └─────┘ │      │ └─────┘ │      │ └─────┘ │      │         │      │    │    │              │
│  └─────────┘      └─────────┘      └─────────┘      └─────────┘      └────│────┘              │
│       ▲                │                ▲                │                │                   │
│       │                │                │                │                │                   │
│       │                │    ┌───────────┴────────────────┴────────────────┘                   │
│       │                │    │           FORWARDING UNIT                                       │
│       │                │    └──────────────────────────────────                               │
│       │                │                                                                      │
│       └────────────────┴────────────────┬─────────────────────────                            │
│                                         │     HAZARD UNIT                                     │
│                                         └─────────────────────────                            │
│                                                                                               │
│  Outputs: flags[3:0] = {V, C, N, Z}, flags_valid                                              │
│                                                                                               │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Key Specifications

| Parameter | Value |
|-----------|-------|
| **Architecture** | RISC-V RV32I |
| **Pipeline Stages** | 5 (IF, ID, EX, MEM, WB) |
| **Data Width** | 32 bits |
| **Address Width** | 32 bits |
| **Register File** | 32 registers × 32 bits |
| **Instruction Memory** | 256 words × 32 bits (1 KB) |
| **Data Memory** | 1024 bytes (1 KB) |
| **Forwarding Paths** | 2 (EX→EX, MEM→EX) |
| **Flag Bits** | 4 (Z, N, C, V) |

---

## ⚙️ Pipeline Stages

### Stage 1: Instruction Fetch (IF)

```
                    ┌───────────────────────────────────┐
                    │        INSTRUCTION FETCH          │
                    ├───────────────────────────────────┤
                    │                                   │
   branch_target ──▶│  ┌─────────┐      ┌──────────┐   │
   branch_taken ───▶│  │   PC    │─────▶│   IMEM   │   │──▶ instruction
                    │  │  Logic  │      │ 256x32   │   │
         stall ────▶│  └─────────┘      └──────────┘   │──▶ pc_out
                    │       │                          │
                    │       ▼                          │──▶ valid
                    │  ┌─────────┐                     │
                    │  │   PC    │                     │
                    │  │ Register│                     │
                    │  └─────────┘                     │
                    │                                   │
                    └───────────────────────────────────┘
```

**Functions:**
- Maintains Program Counter (PC)
- Fetches instruction from Instruction Memory
- Handles PC update: PC+4, branch target, or stall
- Generates bubble on branch taken

**Key Signals:**
| Signal | Direction | Description |
|--------|-----------|-------------|
| `stall` | Input | Hold current instruction |
| `branch_taken` | Input | Redirect PC to branch target |
| `branch_target` | Input | Target address for branch/jump |
| `pc_out` | Output | Current PC value |
| `instruction` | Output | Fetched 32-bit instruction |
| `valid` | Output | Instruction is valid |

---

### Stage 2: Instruction Decode (ID)

```
                    ┌───────────────────────────────────┐
                    │        INSTRUCTION DECODE         │
                    ├───────────────────────────────────┤
                    │                                   │
  instruction ─────▶│  ┌─────────┐                     │
                    │  │ Decoder │──▶ opcode, funct3   │──▶ alu_op
                    │  └─────────┘    funct7, rd, etc. │──▶ control
                    │       │                          │    signals
                    │       ▼                          │
                    │  ┌─────────┐                     │
                    │  │ Imm Gen │─────────────────────│──▶ imm_out
                    │  └─────────┘                     │
                    │                                   │
     wb_data ──────▶│  ┌─────────┐                     │
     wb_rd ────────▶│  │  Reg    │─────────────────────│──▶ rs1_data
     wb_enable ────▶│  │  File   │─────────────────────│──▶ rs2_data
                    │  │ 32x32   │                     │
                    │  └─────────┘                     │
                    │                                   │
                    └───────────────────────────────────┘
```

**Functions:**
- Decodes instruction fields (opcode, rd, rs1, rs2, funct3, funct7)
- Generates immediate values for all instruction types
- Reads source registers from register file
- Generates control signals for pipeline
- Handles register file writeback (on negedge for forwarding)

**Immediate Generation:**
| Type | Immediate Format |
|------|------------------|
| I-type | `{20{inst[31]}, inst[31:20]}` |
| S-type | `{20{inst[31]}, inst[31:25], inst[11:7]}` |
| B-type | `{19{inst[31]}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}` |
| U-type | `{inst[31:12], 12'b0}` |
| J-type | `{11{inst[31]}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}` |

---

### Stage 3: Execute (EX)

```
                    ┌───────────────────────────────────────────────────┐
                    │                    EXECUTE                         │
                    ├───────────────────────────────────────────────────┤
                    │                                                   │
                    │  ┌─────────┐                                      │
   rs1_data ───────▶│  │ Forward │                                      │
   ex_mem_result ──▶│  │  MUX A  │──┐                                   │
   mem_wb_result ──▶│  └─────────┘  │                                   │
                    │               ▼                                   │
                    │            ┌─────┐      ┌─────────┐               │
                    │            │     │─────▶│  FLAGS  │───────────────│──▶ flags_out
                    │            │ ALU │      │ Z N C V │               │──▶ flags_valid
                    │            │     │─────────────────────────────────│──▶ alu_result
                    │            └─────┘                                │
                    │               ▲                                   │
                    │  ┌─────────┐  │  ┌─────────┐                      │
   rs2_data ───────▶│  │ Forward │──┴──│ ALU Src │◀── imm_in            │
   ex_mem_result ──▶│  │  MUX B  │     │   MUX   │                      │
   mem_wb_result ──▶│  └─────────┘     └─────────┘                      │
                    │                                                   │
                    │  ┌─────────┐                                      │
   rs1_data ───────▶│  │ Branch  │──────────────────────────────────────│──▶ branch_taken
   rs2_data ───────▶│  │ Compare │──────────────────────────────────────│──▶ branch_target
                    │  └─────────┘                                      │
                    │                                                   │
                    └───────────────────────────────────────────────────┘
```

**Functions:**
- Performs ALU operations (ADD, SUB, AND, OR, XOR, shifts, comparisons)
- Handles data forwarding via forwarding MUXes
- Computes branch conditions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
- Calculates branch/jump target addresses
- Updates flag registers (Zero, Negative, Carry, Overflow)

**ALU Operations:**
| ALU_OP | Operation | Description |
|--------|-----------|-------------|
| 0000 | ADD | A + B |
| 0001 | SUB | A - B |
| 0010 | SLL | A << B[4:0] |
| 0011 | SLT | A < B (signed) |
| 0100 | SLTU | A < B (unsigned) |
| 0101 | XOR | A ^ B |
| 0110 | SRL | A >> B[4:0] |
| 0111 | SRA | A >>> B[4:0] |
| 1000 | OR | A \| B |
| 1001 | AND | A & B |
| 1010 | PASS_B | B (for LUI) |

---

### Stage 4: Memory (MEM)

```
                    ┌───────────────────────────────────┐
                    │             MEMORY                │
                    ├───────────────────────────────────┤
                    │                                   │
  alu_result ──────▶│       ┌──────────────┐           │
                    │       │              │           │
   rs2_data ───────▶│       │     DMEM     │───────────│──▶ mem_data
                    │       │    1024B     │           │
   mem_read ───────▶│       │              │           │
   mem_write ──────▶│       └──────────────┘           │
   funct3 ─────────▶│              │                   │
                    │              ▼                   │
                    │       ┌──────────────┐           │
                    │       │  Size Sel    │           │
                    │       │ B/H/W/BU/HU  │           │
                    │       └──────────────┘           │
                    │                                   │
                    │  alu_result ─────────────────────│──▶ alu_result_out
                    │                                   │──▶ mem_result (fwd)
                    └───────────────────────────────────┘
```

**Functions:**
- Performs data memory read/write operations
- Supports byte (B), halfword (H), and word (W) access
- Supports unsigned loads (LBU, LHU)
- Provides forwarding path for load data

**Memory Access Types:**
| funct3 | Load | Store | Description |
|--------|------|-------|-------------|
| 000 | LB | SB | Byte (signed) |
| 001 | LH | SH | Halfword (signed) |
| 010 | LW | SW | Word |
| 100 | LBU | - | Byte (unsigned) |
| 101 | LHU | - | Halfword (unsigned) |

---

### Stage 5: Writeback (WB)

```
                    ┌───────────────────────────────────┐
                    │            WRITEBACK              │
                    ├───────────────────────────────────┤
                    │                                   │
  alu_result ──────▶│       ┌──────────────┐           │
                    │       │              │           │
   mem_data ───────▶│       │   Result     │───────────│──▶ wb_data
                    │       │     MUX      │           │
  mem_to_reg ──────▶│       │              │           │
                    │       └──────────────┘           │
                    │                                   │
        rd ────────▶│ ─────────────────────────────────│──▶ wb_rd
  reg_write ───────▶│ ─────────────────────────────────│──▶ wb_enable
                    │                                   │
                    └───────────────────────────────────┘
```

**Functions:**
- Selects between ALU result and memory data
- Generates writeback enable signal
- Prevents writes to x0 (hardwired zero)

---

## 🔄 Hazard Handling

### Hazard Detection Unit

```
                    ┌───────────────────────────────────┐
                    │         HAZARD DETECTION          │
                    ├───────────────────────────────────┤
                    │                                   │
  if_id_rs1 ───────▶│                                   │
  if_id_rs2 ───────▶│    Load-Use Hazard Detection     │──▶ stall_if
                    │                                   │──▶ stall_id
  id_ex_rd ────────▶│    if (id_ex_mem_read &&         │──▶ flush_ex
  id_ex_mem_read ──▶│        id_ex_rd != 0 &&          │
  id_ex_valid ─────▶│        (id_ex_rd == if_id_rs1 || │
                    │         id_ex_rd == if_id_rs2))  │
                    │                                   │
                    └───────────────────────────────────┘
```

**Load-Use Hazard:**
When a LOAD is in EX and the next instruction uses the loaded value:
1. Stall IF stage (hold PC)
2. Stall ID stage (hold instruction)
3. Insert bubble in EX stage (flush control signals)

---

## ➡️ Forwarding Unit

```
                    ┌───────────────────────────────────┐
                    │          FORWARDING UNIT          │
                    ├───────────────────────────────────┤
                    │                                   │
  id_ex_rs1 ───────▶│                                   │
  id_ex_rs2 ───────▶│                                   │
                    │   Priority: EX/MEM > MEM/WB       │
  ex_mem_rd ───────▶│                                   │──▶ forward_a[1:0]
  ex_mem_reg_write ▶│   if (ex_mem_rd == id_ex_rs1)    │
  ex_mem_valid ────▶│       forward_a = FWD_EX_MEM     │
                    │   else if (mem_wb_rd == id_ex_rs1)│──▶ forward_b[1:0]
  mem_wb_rd ───────▶│       forward_a = FWD_MEM_WB     │
  mem_wb_reg_write ▶│   else                           │
  mem_wb_valid ────▶│       forward_a = FWD_NONE       │
                    │                                   │
                    └───────────────────────────────────┘
```

**Forwarding Paths:**
| Source | forward_a/b | Data Path |
|--------|-------------|-----------|
| FWD_NONE (00) | Register File | No forwarding needed |
| FWD_EX_MEM (01) | EX/MEM Register | Forward from ALU result |
| FWD_MEM_WB (10) | MEM/WB Register | Forward from WB data |

---

## 🚩 Flag Registers

### Flag Computation

```
                    ┌───────────────────────────────────┐
                    │         FLAG COMPUTATION          │
                    ├───────────────────────────────────┤
                    │                                   │
   alu_result ─────▶│  Z = (result == 0)               │──▶ flag_zero
                    │                                   │
   alu_result ─────▶│  N = result[31]                  │──▶ flag_negative
                    │                                   │
   alu_extended ───▶│  C = extended[32] (ADD)          │──▶ flag_carry
   alu_op ─────────▶│  C = (A < B) (SUB, borrow)       │
                    │                                   │
   operand_a ──────▶│  V = signed overflow             │──▶ flag_overflow
   operand_b ──────▶│      detection for ADD/SUB       │
   alu_result ─────▶│                                  │
                    │                                   │
                    └───────────────────────────────────┘
```

### Flag Definitions

| Flag | Bit | Computation | Description |
|------|-----|-------------|-------------|
| **Z** (Zero) | 0 | `result == 0` | Set if result is zero |
| **N** (Negative) | 1 | `result[31]` | Set if result MSB is 1 |
| **C** (Carry) | 2 | ADD: `carry_out`; SUB: `A < B` | Carry/Borrow flag |
| **V** (Overflow) | 3 | Signed overflow | Set on signed overflow |

### Overflow Detection

**For ADD:**
```
V = (A[31] == B[31]) && (result[31] != A[31])
```
Both operands same sign, but result has different sign.

**For SUB:**
```
V = (A[31] != B[31]) && (result[31] != A[31])
```
Operands have different signs, result sign differs from A.

### Carry Convention (for SUB)
- **Carry = 1**: Borrow occurred (A < B for unsigned)
- **Carry = 0**: No borrow (A >= B for unsigned)

---

## 💾 Memory Architecture

### Instruction Memory (IMEM)

| Parameter | Value |
|-----------|-------|
| Size | 256 words × 32 bits |
| Total | 1 KB |
| Access | Word-aligned only |
| Addressing | `imem[pc[9:2]]` |
| Type | ROM (initialized from file) |

### Data Memory (DMEM)

| Parameter | Value |
|-----------|-------|
| Size | 1024 bytes |
| Total | 1 KB |
| Access | Byte, Halfword, Word |
| Addressing | `dmem[addr[9:0]]` |
| Type | RAM |
| Endianness | Little-endian |

---

## 📦 Module Descriptions

### Top-Level: riscv_cpu.v

```verilog
module riscv_cpu (
    input  wire        clk,
    input  wire        rst_n,
    output wire [3:0]  flags,        // {V, C, N, Z}
    output wire        flags_valid
);
```

Instantiates and connects all pipeline stages, forwarding unit, and hazard unit.

### instruction_fetch.v
- PC register and update logic
- Instruction memory (256x32)
- Stall and branch handling

### instruction_decode.v
- Instruction decoder
- Register file (32x32)
- Immediate generator
- Control signal generation

### execute.v
- ALU (10 operations)
- Forwarding MUXes
- Branch comparator
- Flag register computation

### memory_stage.v
- Data memory (1024 bytes)
- Load/store handling
- Byte/halfword/word access

### writeback.v
- Result MUX (ALU/memory)
- Writeback enable generation

### forwarding_unit.v
- Data hazard detection
- Forwarding control signals

### hazard_unit.v
- Load-use hazard detection
- Pipeline stall generation

### riscv_pkg.v
- Opcode definitions
- ALU operation codes
- Branch condition codes
- Forwarding MUX codes
- Flag bit positions

---

## 📡 Signal Reference

### Pipeline Control Signals

| Signal | Source | Description |
|--------|--------|-------------|
| `stall_if` | Hazard Unit | Stall IF stage |
| `stall_id` | Hazard Unit | Stall ID stage |
| `flush_ex` | Hazard Unit | Insert bubble in EX |
| `branch_taken` | EX Stage | Branch/jump is taken |
| `branch_target` | EX Stage | Target PC for branch |

### Forwarding Signals

| Signal | Width | Values |
|--------|-------|--------|
| `forward_a` | 2 bits | 00=NONE, 01=EX_MEM, 10=MEM_WB |
| `forward_b` | 2 bits | 00=NONE, 01=EX_MEM, 10=MEM_WB |

### Control Signals

| Signal | Description |
|--------|-------------|
| `alu_op[3:0]` | ALU operation select |
| `alu_src` | 0=rs2, 1=immediate |
| `mem_read` | Load instruction |
| `mem_write` | Store instruction |
| `reg_write` | Write to register file |
| `mem_to_reg` | Select memory data for WB |
| `branch` | Branch instruction |
| `jump` | Jump instruction |

---

## 📊 Performance Characteristics

### Pipeline Timing

| Metric | Value |
|--------|-------|
| CPI (ideal) | 1.0 |
| Branch penalty | 2 cycles |
| Load-use penalty | 1 cycle |
| Clock period | 10 ns (100 MHz) |

### Hazard Statistics (typical)

| Hazard Type | Handling | Penalty |
|-------------|----------|---------|
| RAW (ALU→ALU) | Forwarding | 0 cycles |
| RAW (Load→Use) | Stall | 1 cycle |
| Control (Branch) | Flush | 2 cycles |
| WAW | None | N/A (in-order) |
| WAR | None | N/A (in-order) |

---

## 🔧 Design Decisions

1. **Negedge Register Write**: Register file writes on falling edge to enable same-cycle forwarding without structural hazard.

2. **Static Branch Prediction**: Always predict not-taken. Simple but effective for short forward branches.

3. **Borrow Convention for Carry**: SUB sets carry on borrow (A < B), matching common ISA conventions.

4. **JALR LSB Clear**: Target address LSB cleared per RISC-V specification for instruction alignment.

5. **Combined Forwarding MUX**: Single MUX handles EX/MEM and MEM/WB forwarding with priority.

---

## 📈 Block Diagram Files

Visual architecture diagrams are available in the `synth/` directory:

- `riscv_pipeline_clean.svg` - Clean pipeline block diagram
- `riscv_pipeline_clean.png` - PNG version
- `riscv_cpu_clean.svg` - Detailed Yosys-generated diagram
