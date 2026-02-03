# RISC-V RV32I Instruction Format

This document describes the instruction encoding for the RV32I base integer instruction set implemented in this pipelined CPU.

---

## 📋 Table of Contents

- [Instruction Formats Overview](#instruction-formats-overview)
- [R-Type Instructions](#r-type-instructions)
- [I-Type Instructions](#i-type-instructions)
- [S-Type Instructions](#s-type-instructions)
- [B-Type Instructions](#b-type-instructions)
- [U-Type Instructions](#u-type-instructions)
- [J-Type Instructions](#j-type-instructions)
- [Instruction Encoding Reference](#instruction-encoding-reference)
- [Opcode Map](#opcode-map)

---

## 📐 Instruction Formats Overview

RISC-V uses 6 core instruction formats, all 32 bits wide:

```
31          25 24      20 19      15 14  12 11       7 6            0
┌─────────────┬──────────┬──────────┬──────┬──────────┬──────────────┐
│   funct7    │   rs2    │   rs1    │funct3│    rd    │    opcode    │  R-type
├─────────────┴──────────┼──────────┼──────┼──────────┼──────────────┤
│       imm[11:0]        │   rs1    │funct3│    rd    │    opcode    │  I-type
├─────────────┬──────────┼──────────┼──────┼──────────┼──────────────┤
│  imm[11:5]  │   rs2    │   rs1    │funct3│ imm[4:0] │    opcode    │  S-type
├─────────────┼──────────┼──────────┼──────┼──────────┼──────────────┤
│imm[12|10:5] │   rs2    │   rs1    │funct3│imm[4:1|11│    opcode    │  B-type
├─────────────┴──────────┴──────────┴──────┼──────────┼──────────────┤
│              imm[31:12]                  │    rd    │    opcode    │  U-type
├──────────────────────────────────────────┼──────────┼──────────────┤
│         imm[20|10:1|11|19:12]            │    rd    │    opcode    │  J-type
└──────────────────────────────────────────┴──────────┴──────────────┘
```

---

## 🔧 R-Type Instructions

**Register-Register operations**

### Format
```
31       25 24     20 19     15 14  12 11      7 6         0
┌──────────┬─────────┬─────────┬──────┬─────────┬───────────┐
│  funct7  │   rs2   │   rs1   │funct3│   rd    │  opcode   │
│  7 bits  │  5 bits │  5 bits │3 bits│  5 bits │  7 bits   │
└──────────┴─────────┴─────────┴──────┴─────────┴───────────┘
```

### Instructions

| Instruction | funct7 | funct3 | Opcode | Description |
|-------------|--------|--------|--------|-------------|
| `ADD rd, rs1, rs2` | 0000000 | 000 | 0110011 | rd = rs1 + rs2 |
| `SUB rd, rs1, rs2` | 0100000 | 000 | 0110011 | rd = rs1 - rs2 |
| `SLL rd, rs1, rs2` | 0000000 | 001 | 0110011 | rd = rs1 << rs2[4:0] |
| `SLT rd, rs1, rs2` | 0000000 | 010 | 0110011 | rd = (rs1 < rs2) ? 1 : 0 (signed) |
| `SLTU rd, rs1, rs2` | 0000000 | 011 | 0110011 | rd = (rs1 < rs2) ? 1 : 0 (unsigned) |
| `XOR rd, rs1, rs2` | 0000000 | 100 | 0110011 | rd = rs1 ^ rs2 |
| `SRL rd, rs1, rs2` | 0000000 | 101 | 0110011 | rd = rs1 >> rs2[4:0] (logical) |
| `SRA rd, rs1, rs2` | 0100000 | 101 | 0110011 | rd = rs1 >>> rs2[4:0] (arithmetic) |
| `OR rd, rs1, rs2` | 0000000 | 110 | 0110011 | rd = rs1 \| rs2 |
| `AND rd, rs1, rs2` | 0000000 | 111 | 0110011 | rd = rs1 & rs2 |

### Example Encoding
```
ADD x3, x1, x2
─────────────────────────────────────────────────────────
funct7    rs2     rs1   funct3   rd     opcode
0000000   00010   00001   000   00011   0110011
─────────────────────────────────────────────────────────
Binary: 0000000 00010 00001 000 00011 0110011
Hex:    0x002081B3
```

---

## 📥 I-Type Instructions

**Immediate operations, Loads, JALR**

### Format
```
31                  20 19     15 14  12 11      7 6         0
┌──────────────────────┬─────────┬──────┬─────────┬───────────┐
│     imm[11:0]        │   rs1   │funct3│   rd    │  opcode   │
│      12 bits         │  5 bits │3 bits│  5 bits │  7 bits   │
└──────────────────────┴─────────┴──────┴─────────┴───────────┘
```

### Arithmetic Immediate Instructions (Opcode: 0010011)

| Instruction | funct3 | Description |
|-------------|--------|-------------|
| `ADDI rd, rs1, imm` | 000 | rd = rs1 + sext(imm) |
| `SLTI rd, rs1, imm` | 010 | rd = (rs1 < sext(imm)) ? 1 : 0 (signed) |
| `SLTIU rd, rs1, imm` | 011 | rd = (rs1 < sext(imm)) ? 1 : 0 (unsigned) |
| `XORI rd, rs1, imm` | 100 | rd = rs1 ^ sext(imm) |
| `ORI rd, rs1, imm` | 110 | rd = rs1 \| sext(imm) |
| `ANDI rd, rs1, imm` | 111 | rd = rs1 & sext(imm) |

### Shift Immediate Instructions (Opcode: 0010011)

| Instruction | imm[11:5] | funct3 | Description |
|-------------|-----------|--------|-------------|
| `SLLI rd, rs1, shamt` | 0000000 | 001 | rd = rs1 << shamt |
| `SRLI rd, rs1, shamt` | 0000000 | 101 | rd = rs1 >> shamt (logical) |
| `SRAI rd, rs1, shamt` | 0100000 | 101 | rd = rs1 >>> shamt (arithmetic) |

### Load Instructions (Opcode: 0000011)

| Instruction | funct3 | Description |
|-------------|--------|-------------|
| `LB rd, imm(rs1)` | 000 | rd = sext(mem[rs1+imm][7:0]) |
| `LH rd, imm(rs1)` | 001 | rd = sext(mem[rs1+imm][15:0]) |
| `LW rd, imm(rs1)` | 010 | rd = mem[rs1+imm][31:0] |
| `LBU rd, imm(rs1)` | 100 | rd = zext(mem[rs1+imm][7:0]) |
| `LHU rd, imm(rs1)` | 101 | rd = zext(mem[rs1+imm][15:0]) |

### JALR Instruction (Opcode: 1100111)

| Instruction | funct3 | Description |
|-------------|--------|-------------|
| `JALR rd, rs1, imm` | 000 | rd = PC+4; PC = (rs1+imm) & ~1 |

### Example Encoding
```
ADDI x1, x0, 5
─────────────────────────────────────────────────────────
imm[11:0]         rs1   funct3   rd     opcode
000000000101    00000    000    00001   0010011
─────────────────────────────────────────────────────────
Binary: 000000000101 00000 000 00001 0010011
Hex:    0x00500093
```

---

## 📤 S-Type Instructions

**Store operations**

### Format
```
31       25 24     20 19     15 14  12 11      7 6         0
┌──────────┬─────────┬─────────┬──────┬─────────┬───────────┐
│ imm[11:5]│   rs2   │   rs1   │funct3│imm[4:0] │  opcode   │
│  7 bits  │  5 bits │  5 bits │3 bits│  5 bits │  7 bits   │
└──────────┴─────────┴─────────┴──────┴─────────┴───────────┘
```

### Store Instructions (Opcode: 0100011)

| Instruction | funct3 | Description |
|-------------|--------|-------------|
| `SB rs2, imm(rs1)` | 000 | mem[rs1+imm][7:0] = rs2[7:0] |
| `SH rs2, imm(rs1)` | 001 | mem[rs1+imm][15:0] = rs2[15:0] |
| `SW rs2, imm(rs1)` | 010 | mem[rs1+imm][31:0] = rs2[31:0] |

### Immediate Reconstruction
```
imm[11:0] = {inst[31:25], inst[11:7]}
```

### Example Encoding
```
SW x1, 0(x2)
─────────────────────────────────────────────────────────
imm[11:5]   rs2     rs1   funct3  imm[4:0]   opcode
0000000    00001   00010   010     00000    0100011
─────────────────────────────────────────────────────────
Binary: 0000000 00001 00010 010 00000 0100011
Hex:    0x00112023
```

---

## 🔀 B-Type Instructions

**Branch operations**

### Format
```
31       25 24     20 19     15 14  12 11      7 6         0
┌──────────┬─────────┬─────────┬──────┬─────────┬───────────┐
│imm[12|10:5]│  rs2  │   rs1   │funct3│imm[4:1|11]│ opcode  │
│  7 bits  │  5 bits │  5 bits │3 bits│  5 bits │  7 bits   │
└──────────┴─────────┴─────────┴──────┴─────────┴───────────┘
```

### Branch Instructions (Opcode: 1100011)

| Instruction | funct3 | Description |
|-------------|--------|-------------|
| `BEQ rs1, rs2, offset` | 000 | if (rs1 == rs2) PC += sext(offset) |
| `BNE rs1, rs2, offset` | 001 | if (rs1 != rs2) PC += sext(offset) |
| `BLT rs1, rs2, offset` | 100 | if (rs1 < rs2) PC += sext(offset) (signed) |
| `BGE rs1, rs2, offset` | 101 | if (rs1 >= rs2) PC += sext(offset) (signed) |
| `BLTU rs1, rs2, offset` | 110 | if (rs1 < rs2) PC += sext(offset) (unsigned) |
| `BGEU rs1, rs2, offset` | 111 | if (rs1 >= rs2) PC += sext(offset) (unsigned) |

### Immediate Reconstruction
```
imm[12:1] = {inst[31], inst[7], inst[30:25], inst[11:8]}
imm[0] = 0  (always 0, for 2-byte alignment)
```

### Branch Target Calculation
```
target = PC + sign_extend(imm[12:1] << 1)
```

---

## 🔝 U-Type Instructions

**Upper immediate operations**

### Format
```
31                                   12 11      7 6         0
┌───────────────────────────────────────┬─────────┬───────────┐
│             imm[31:12]                │   rd    │  opcode   │
│              20 bits                  │  5 bits │  7 bits   │
└───────────────────────────────────────┴─────────┴───────────┘
```

### Instructions

| Instruction | Opcode | Description |
|-------------|--------|-------------|
| `LUI rd, imm` | 0110111 | rd = imm << 12 |
| `AUIPC rd, imm` | 0010111 | rd = PC + (imm << 12) |

### Example Encoding
```
LUI x1, 0x12345
─────────────────────────────────────────────────────────
imm[31:12]                         rd     opcode
00010010001101000101              00001   0110111
─────────────────────────────────────────────────────────
Hex: 0x123450B7
```

---

## ↩️ J-Type Instructions

**Jump operations**

### Format
```
31                                   12 11      7 6         0
┌───────────────────────────────────────┬─────────┬───────────┐
│      imm[20|10:1|11|19:12]            │   rd    │  opcode   │
│              20 bits                  │  5 bits │  7 bits   │
└───────────────────────────────────────┴─────────┴───────────┘
```

### Instructions

| Instruction | Opcode | Description |
|-------------|--------|-------------|
| `JAL rd, offset` | 1101111 | rd = PC+4; PC += sext(offset) |

### Immediate Reconstruction
```
imm[20:1] = {inst[31], inst[19:12], inst[20], inst[30:21]}
imm[0] = 0  (always 0, for 2-byte alignment)
```

---

## 📊 Instruction Encoding Reference

### Complete Encoding Table

| Instruction | Type | Opcode | funct3 | funct7 | Hex Example |
|-------------|------|--------|--------|--------|-------------|
| ADD | R | 0110011 | 000 | 0000000 | 0x002081B3 |
| SUB | R | 0110011 | 000 | 0100000 | 0x40208233 |
| SLL | R | 0110011 | 001 | 0000000 | 0x00209433 |
| SLT | R | 0110011 | 010 | 0000000 | 0x0020A533 |
| SLTU | R | 0110011 | 011 | 0000000 | 0x0020B5B3 |
| XOR | R | 0110011 | 100 | 0000000 | 0x0020C3B3 |
| SRL | R | 0110011 | 101 | 0000000 | 0x0020D4B3 |
| SRA | R | 0110011 | 101 | 0100000 | 0x4020D4B3 |
| OR | R | 0110011 | 110 | 0000000 | 0x0020E333 |
| AND | R | 0110011 | 111 | 0000000 | 0x0020F2B3 |
| ADDI | I | 0010011 | 000 | - | 0x00500093 |
| LW | I | 0000011 | 010 | - | 0x00012583 |
| SW | S | 0100011 | 010 | - | 0x00112023 |
| BEQ | B | 1100011 | 000 | - | 0x00208663 |
| JAL | J | 1101111 | - | - | 0x008000EF |
| LUI | U | 0110111 | - | - | 0x123450B7 |

---

## 🗺️ Opcode Map

```
┌─────────────────────────────────────────────────────────────┐
│                    RISC-V Opcode Map                        │
├─────────────┬─────────────────┬─────────────────────────────┤
│   Opcode    │     Name        │        Instructions         │
├─────────────┼─────────────────┼─────────────────────────────┤
│   0110111   │     LUI         │  LUI                        │
│   0010111   │     AUIPC       │  AUIPC                      │
│   1101111   │     JAL         │  JAL                        │
│   1100111   │     JALR        │  JALR                       │
│   1100011   │     BRANCH      │  BEQ, BNE, BLT, BGE, etc.   │
│   0000011   │     LOAD        │  LB, LH, LW, LBU, LHU       │
│   0100011   │     STORE       │  SB, SH, SW                 │
│   0010011   │     OP-IMM      │  ADDI, SLTI, ORI, etc.      │
│   0110011   │     OP          │  ADD, SUB, AND, OR, etc.    │
└─────────────┴─────────────────┴─────────────────────────────┘
```

---

## 🔗 References

- [RISC-V Specification](https://riscv.org/specifications/)
- [RISC-V Green Card](https://www.cl.cam.ac.uk/teaching/1617/ECAD+Arch/files/docs/RISCVGreenCardv8-20151013.pdf)
