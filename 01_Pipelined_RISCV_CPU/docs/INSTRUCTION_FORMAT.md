# RISC-V RV32I Instruction Format

This document describes the instruction encoding for the RV32I base integer instruction set implemented in this pipelined CPU.

---

## 🎯 MASTER TABLE: All 40 RV32I Instructions

**This is the complete list of ALL instructions with their encoding and meaning:**

| # | Instruction | What It Does (Simple) | Type | Opcode | funct3 | funct7 | Example Hex |
|---|-------------|----------------------|------|--------|--------|--------|-------------|
| **ARITHMETIC (Register-Register)** |
| 1 | `ADD rd, rs1, rs2` | rd = rs1 + rs2 | R | 0110011 | 000 | 0000000 | `002081B3` |
| 2 | `SUB rd, rs1, rs2` | rd = rs1 - rs2 | R | 0110011 | 000 | 0100000 | `40208233` |
| 3 | `AND rd, rs1, rs2` | rd = rs1 AND rs2 | R | 0110011 | 111 | 0000000 | `0020F2B3` |
| 4 | `OR rd, rs1, rs2` | rd = rs1 OR rs2 | R | 0110011 | 110 | 0000000 | `0020E333` |
| 5 | `XOR rd, rs1, rs2` | rd = rs1 XOR rs2 | R | 0110011 | 100 | 0000000 | `0020C3B3` |
| 6 | `SLL rd, rs1, rs2` | rd = rs1 << rs2 (shift left) | R | 0110011 | 001 | 0000000 | `00209433` |
| 7 | `SRL rd, rs1, rs2` | rd = rs1 >> rs2 (shift right logical) | R | 0110011 | 101 | 0000000 | `0020D4B3` |
| 8 | `SRA rd, rs1, rs2` | rd = rs1 >> rs2 (shift right arithmetic) | R | 0110011 | 101 | 0100000 | `4020D4B3` |
| 9 | `SLT rd, rs1, rs2` | rd = 1 if rs1 < rs2 (signed), else 0 | R | 0110011 | 010 | 0000000 | `0020A533` |
| 10 | `SLTU rd, rs1, rs2` | rd = 1 if rs1 < rs2 (unsigned), else 0 | R | 0110011 | 011 | 0000000 | `0020B5B3` |
| **ARITHMETIC (Immediate)** |
| 11 | `ADDI rd, rs1, imm` | rd = rs1 + imm | I | 0010011 | 000 | - | `00500093` |
| 12 | `ANDI rd, rs1, imm` | rd = rs1 AND imm | I | 0010011 | 111 | - | `0FF0F693` |
| 13 | `ORI rd, rs1, imm` | rd = rs1 OR imm | I | 0010011 | 110 | - | `01016713` |
| 14 | `XORI rd, rs1, imm` | rd = rs1 XOR imm | I | 0010011 | 100 | - | `00F14793` |
| 15 | `SLTI rd, rs1, imm` | rd = 1 if rs1 < imm (signed), else 0 | I | 0010011 | 010 | - | `00A0A313` |
| 16 | `SLTIU rd, rs1, imm` | rd = 1 if rs1 < imm (unsigned), else 0 | I | 0010011 | 011 | - | `00A0B313` |
| **SHIFT (Immediate)** |
| 17 | `SLLI rd, rs1, shamt` | rd = rs1 << shamt | I | 0010011 | 001 | 0000000 | `00311813` |
| 18 | `SRLI rd, rs1, shamt` | rd = rs1 >> shamt (logical) | I | 0010011 | 101 | 0000000 | `00215893` |
| 19 | `SRAI rd, rs1, shamt` | rd = rs1 >> shamt (arithmetic) | I | 0010011 | 101 | 0100000 | `40215893` |
| **LOAD (Read from Memory)** |
| 20 | `LW rd, imm(rs1)` | rd = memory[rs1+imm] (32-bit word) | I | 0000011 | 010 | - | `00012903` |
| 21 | `LH rd, imm(rs1)` | rd = memory[rs1+imm] (16-bit, sign-extend) | I | 0000011 | 001 | - | `00011083` |
| 22 | `LB rd, imm(rs1)` | rd = memory[rs1+imm] (8-bit, sign-extend) | I | 0000011 | 000 | - | `00010083` |
| 23 | `LHU rd, imm(rs1)` | rd = memory[rs1+imm] (16-bit, zero-extend) | I | 0000011 | 101 | - | `00015083` |
| 24 | `LBU rd, imm(rs1)` | rd = memory[rs1+imm] (8-bit, zero-extend) | I | 0000011 | 100 | - | `00014083` |
| **STORE (Write to Memory)** |
| 25 | `SW rs2, imm(rs1)` | memory[rs1+imm] = rs2 (32-bit word) | S | 0100011 | 010 | - | `00112023` |
| 26 | `SH rs2, imm(rs1)` | memory[rs1+imm] = rs2 (16-bit) | S | 0100011 | 001 | - | `00111023` |
| 27 | `SB rs2, imm(rs1)` | memory[rs1+imm] = rs2 (8-bit) | S | 0100011 | 000 | - | `00110023` |
| **BRANCH (Conditional Jump)** |
| 28 | `BEQ rs1, rs2, offset` | if rs1 == rs2, jump to PC+offset | B | 1100011 | 000 | - | `00208663` |
| 29 | `BNE rs1, rs2, offset` | if rs1 != rs2, jump to PC+offset | B | 1100011 | 001 | - | `00209663` |
| 30 | `BLT rs1, rs2, offset` | if rs1 < rs2 (signed), jump | B | 1100011 | 100 | - | `0020C663` |
| 31 | `BGE rs1, rs2, offset` | if rs1 >= rs2 (signed), jump | B | 1100011 | 101 | - | `0020D663` |
| 32 | `BLTU rs1, rs2, offset` | if rs1 < rs2 (unsigned), jump | B | 1100011 | 110 | - | `0020E663` |
| 33 | `BGEU rs1, rs2, offset` | if rs1 >= rs2 (unsigned), jump | B | 1100011 | 111 | - | `0020F663` |
| **JUMP (Unconditional)** |
| 34 | `JAL rd, offset` | rd = PC+4; jump to PC+offset | J | 1101111 | - | - | `008000EF` |
| 35 | `JALR rd, rs1, imm` | rd = PC+4; jump to rs1+imm | I | 1100111 | 000 | - | `000080E7` |
| **UPPER IMMEDIATE** |
| 36 | `LUI rd, imm` | rd = imm << 12 (load upper 20 bits) | U | 0110111 | - | - | `123450B7` |
| 37 | `AUIPC rd, imm` | rd = PC + (imm << 12) | U | 0010111 | - | - | `12345097` |
| **SPECIAL** |
| 38 | `NOP` | Do nothing (= ADDI x0, x0, 0) | I | 0010011 | 000 | - | `00000013` |

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
Bit:  31        25 24    20 19    15 14  12 11     7 6        0
     +----------+--------+--------+------+--------+----------+
     |  funct7  |  rs2   |  rs1   |funct3|   rd   |  opcode  |  R-type
     +----------+--------+--------+------+--------+----------+
     |       imm[11:0]   |  rs1   |funct3|   rd   |  opcode  |  I-type
     +----------+--------+--------+------+--------+----------+
     |imm[11:5] |  rs2   |  rs1   |funct3|imm[4:0]|  opcode  |  S-type
     +----------+--------+--------+------+--------+----------+
     |imm[12,10:5]| rs2  |  rs1   |funct3|imm[4:1,11]|opcode |  B-type
     +--------------------+-------+------+--------+----------+
     |         imm[31:12]                |   rd   |  opcode  |  U-type
     +-----------------------------------+--------+----------+
     |      imm[20,10:1,11,19:12]        |   rd   |  opcode  |  J-type
     +-----------------------------------+--------+----------+
     |<----- 7 ----->|<- 5 ->|<- 5 ->|<3>|<- 5 -->|<-- 7 --->|
```

---

## 🔧 R-Type Instructions

**Register-Register operations**

### Format
```
Bit:  31        25 24    20 19    15 14  12 11     7 6        0
     +----------+--------+--------+------+--------+----------+
     |  funct7  |  rs2   |  rs1   |funct3|   rd   |  opcode  |
     |  7 bits  | 5 bits | 5 bits |3 bits| 5 bits |  7 bits  |
     +----------+--------+--------+------+--------+----------+
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
---------------------------------------------------------
funct7    rs2     rs1   funct3   rd     opcode
0000000   00010   00001   000   00011   0110011
---------------------------------------------------------
Binary: 0000000 00010 00001 000 00011 0110011
Hex:    0x002081B3
```

---

## 📥 I-Type Instructions

**Immediate operations, Loads, JALR**

### Format
```
Bit:  31          20 19    15 14  12 11     7 6        0
     +-------------+--------+------+--------+----------+
     |  imm[11:0]  |  rs1   |funct3|   rd   |  opcode  |
     |   12 bits   | 5 bits |3 bits| 5 bits |  7 bits  |
     +-------------+--------+------+--------+----------+
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
---------------------------------------------------------
imm[11:0]         rs1   funct3   rd     opcode
000000000101    00000    000    00001   0010011
---------------------------------------------------------
Binary: 000000000101 00000 000 00001 0010011
Hex:    0x00500093
```

---

## 📤 S-Type Instructions

**Store operations**

### Format
```
Bit:  31        25 24    20 19    15 14  12 11     7 6        0
     +----------+--------+--------+------+--------+----------+
     |imm[11:5] |  rs2   |  rs1   |funct3|imm[4:0]|  opcode  |
     |  7 bits  | 5 bits | 5 bits |3 bits| 5 bits |  7 bits  |
     +----------+--------+--------+------+--------+----------+
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
---------------------------------------------------------
imm[11:5]   rs2     rs1   funct3  imm[4:0]   opcode
0000000    00001   00010   010     00000    0100011
---------------------------------------------------------
Binary: 0000000 00001 00010 010 00000 0100011
Hex:    0x00112023
```

---

## 🔀 B-Type Instructions

**Branch operations**

### Format
```
Bit:  31        25 24    20 19    15 14  12 11     7 6        0
     +----------+--------+--------+------+--------+----------+
     |imm[12,10:5]| rs2  |  rs1   |funct3|imm[4:1,11]|opcode |
     |  7 bits  | 5 bits | 5 bits |3 bits| 5 bits |  7 bits  |
     +----------+--------+--------+------+--------+----------+
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
Bit:  31                          12 11     7 6        0
     +----------------------------+--------+----------+
     |        imm[31:12]          |   rd   |  opcode  |
     |         20 bits            | 5 bits |  7 bits  |
     +----------------------------+--------+----------+
```

### Instructions

| Instruction | Opcode | Description |
|-------------|--------|-------------|
| `LUI rd, imm` | 0110111 | rd = imm << 12 |
| `AUIPC rd, imm` | 0010111 | rd = PC + (imm << 12) |

### Example Encoding
```
LUI x1, 0x12345
---------------------------------------------------------
imm[31:12]                         rd     opcode
00010010001101000101              00001   0110111
---------------------------------------------------------
Hex: 0x123450B7
```

---

## ↩️ J-Type Instructions

**Jump operations**

### Format
```
Bit:  31                          12 11     7 6        0
     +----------------------------+--------+----------+
     |   imm[20,10:1,11,19:12]    |   rd   |  opcode  |
     |         20 bits            | 5 bits |  7 bits  |
     +----------------------------+--------+----------+
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

### Complete Encoding Table (ALL RV32I Instructions)

#### R-Type Instructions (Register-Register)
All use **Opcode: 0110011**

| Instruction | What It Does | funct7 | funct3 | Example Hex |
|-------------|--------------|--------|--------|-------------|
| `ADD rd, rs1, rs2` | rd = rs1 + rs2 | 0000000 | 000 | `002081B3` (add x3,x1,x2) |
| `SUB rd, rs1, rs2` | rd = rs1 - rs2 | 0100000 | 000 | `40208233` (sub x4,x1,x2) |
| `SLL rd, rs1, rs2` | rd = rs1 << rs2 | 0000000 | 001 | `00209433` (sll x8,x1,x2) |
| `SLT rd, rs1, rs2` | rd = (rs1 < rs2) ? 1 : 0 (signed) | 0000000 | 010 | `0020A533` (slt x10,x1,x2) |
| `SLTU rd, rs1, rs2` | rd = (rs1 < rs2) ? 1 : 0 (unsigned) | 0000000 | 011 | `0020B5B3` (sltu x11,x1,x2) |
| `XOR rd, rs1, rs2` | rd = rs1 ^ rs2 | 0000000 | 100 | `0020C3B3` (xor x7,x1,x2) |
| `SRL rd, rs1, rs2` | rd = rs1 >> rs2 (logical) | 0000000 | 101 | `0020D4B3` (srl x9,x1,x2) |
| `SRA rd, rs1, rs2` | rd = rs1 >> rs2 (arithmetic) | 0100000 | 101 | `4020D4B3` (sra x9,x1,x2) |
| `OR rd, rs1, rs2` | rd = rs1 \| rs2 | 0000000 | 110 | `0020E333` (or x6,x1,x2) |
| `AND rd, rs1, rs2` | rd = rs1 & rs2 | 0000000 | 111 | `0020F2B3` (and x5,x1,x2) |

---

#### I-Type Arithmetic Instructions (Immediate)
All use **Opcode: 0010011**

| Instruction | What It Does | funct3 | Example Hex |
|-------------|--------------|--------|-------------|
| `ADDI rd, rs1, imm` | rd = rs1 + imm | 000 | `00500093` (addi x1,x0,5) |
| `SLTI rd, rs1, imm` | rd = (rs1 < imm) ? 1 : 0 (signed) | 010 | `00A0A313` (slti x6,x1,10) |
| `SLTIU rd, rs1, imm` | rd = (rs1 < imm) ? 1 : 0 (unsigned) | 011 | `00A0B313` (sltiu x6,x1,10) |
| `XORI rd, rs1, imm` | rd = rs1 ^ imm | 100 | `00F14793` (xori x15,x2,15) |
| `ORI rd, rs1, imm` | rd = rs1 \| imm | 110 | `01016713` (ori x14,x2,16) |
| `ANDI rd, rs1, imm` | rd = rs1 & imm | 111 | `0FF0F693` (andi x13,x1,255) |

---

#### I-Type Shift Instructions (Immediate Shift)
All use **Opcode: 0010011**

| Instruction | What It Does | imm[11:5] | funct3 | Example Hex |
|-------------|--------------|-----------|--------|-------------|
| `SLLI rd, rs1, shamt` | rd = rs1 << shamt | 0000000 | 001 | `00311813` (slli x16,x2,3) |
| `SRLI rd, rs1, shamt` | rd = rs1 >> shamt (logical) | 0000000 | 101 | `00215893` (srli x17,x2,2) |
| `SRAI rd, rs1, shamt` | rd = rs1 >> shamt (arithmetic) | 0100000 | 101 | `40215893` (srai x17,x2,2) |

---

#### Load Instructions
All use **Opcode: 0000011**

| Instruction | What It Does | funct3 | Example Hex |
|-------------|--------------|--------|-------------|
| `LB rd, imm(rs1)` | rd = sign_extend(mem[rs1+imm][7:0]) | 000 | `00010083` (lb x1,0(x2)) |
| `LH rd, imm(rs1)` | rd = sign_extend(mem[rs1+imm][15:0]) | 001 | `00011083` (lh x1,0(x2)) |
| `LW rd, imm(rs1)` | rd = mem[rs1+imm][31:0] | 010 | `00012903` (lw x18,0(x2)) |
| `LBU rd, imm(rs1)` | rd = zero_extend(mem[rs1+imm][7:0]) | 100 | `00014083` (lbu x1,0(x2)) |
| `LHU rd, imm(rs1)` | rd = zero_extend(mem[rs1+imm][15:0]) | 101 | `00015083` (lhu x1,0(x2)) |

---

#### Store Instructions
All use **Opcode: 0100011**

| Instruction | What It Does | funct3 | Example Hex |
|-------------|--------------|--------|-------------|
| `SB rs2, imm(rs1)` | mem[rs1+imm][7:0] = rs2[7:0] | 000 | `00110023` (sb x1,0(x2)) |
| `SH rs2, imm(rs1)` | mem[rs1+imm][15:0] = rs2[15:0] | 001 | `00111023` (sh x1,0(x2)) |
| `SW rs2, imm(rs1)` | mem[rs1+imm][31:0] = rs2[31:0] | 010 | `00112023` (sw x1,0(x2)) |

---

#### Branch Instructions
All use **Opcode: 1100011**

| Instruction | What It Does | funct3 | Example Hex |
|-------------|--------------|--------|-------------|
| `BEQ rs1, rs2, offset` | if (rs1 == rs2) jump to PC+offset | 000 | `00208663` (beq x1,x2,+12) |
| `BNE rs1, rs2, offset` | if (rs1 != rs2) jump to PC+offset | 001 | `00209663` (bne x1,x2,+12) |
| `BLT rs1, rs2, offset` | if (rs1 < rs2) jump (signed) | 100 | `0020C663` (blt x1,x2,+12) |
| `BGE rs1, rs2, offset` | if (rs1 >= rs2) jump (signed) | 101 | `0020D663` (bge x1,x2,+12) |
| `BLTU rs1, rs2, offset` | if (rs1 < rs2) jump (unsigned) | 110 | `0020E663` (bltu x1,x2,+12) |
| `BGEU rs1, rs2, offset` | if (rs1 >= rs2) jump (unsigned) | 111 | `0020F663` (bgeu x1,x2,+12) |

---

#### Upper Immediate Instructions

| Instruction | What It Does | Opcode | Example Hex |
|-------------|--------------|--------|-------------|
| `LUI rd, imm` | rd = imm << 12 (load upper 20 bits) | 0110111 | `123450B7` (lui x1,0x12345) |
| `AUIPC rd, imm` | rd = PC + (imm << 12) | 0010111 | `12345097` (auipc x1,0x12345) |

---

#### Jump Instructions

| Instruction | What It Does | Opcode | funct3 | Example Hex |
|-------------|--------------|--------|--------|-------------|
| `JAL rd, offset` | rd = PC+4; jump to PC+offset | 1101111 | - | `008000EF` (jal x1,+8) |
| `JALR rd, rs1, imm` | rd = PC+4; jump to (rs1+imm) | 1100111 | 000 | `000080E7` (jalr x1,x1,0) |

---

#### Special

| Instruction | What It Does | Opcode | Example Hex |
|-------------|--------------|--------|-------------|
| `NOP` | No operation (actually `addi x0,x0,0`) | 0010011 | `00000013` |

---

### How to Read the Encoding (Step-by-Step)

**Example: Encode `ADD x5, x1, x2`**

```
Step 1: It's R-type (register-register), so use this format:
        [funct7 | rs2 | rs1 | funct3 | rd | opcode]
        [7 bits | 5b  | 5b  | 3 bits | 5b | 7 bits]

Step 2: Look up values:
        - opcode for ADD = 0110011
        - funct3 for ADD = 000
        - funct7 for ADD = 0000000

Step 3: Convert registers to binary (5 bits each):
        - rd  = x5  = 00101
        - rs1 = x1  = 00001
        - rs2 = x2  = 00010

Step 4: Assemble:
        0000000 | 00010 | 00001 | 000 | 00101 | 0110011
        funct7    rs2     rs1   funct3   rd     opcode

Step 5: Group into 4-bit nibbles:
        0000 0000 0010 0000 1000 0010 1011 0011
          0    0    2    0    8    2    B    3

Result: 0x002082B3
```

---

### Quick Reference Card

```
+-----------------------------------------------------------------------------+
|                         RISC-V RV32I QUICK REFERENCE                        |
+-----------------------------------------------------------------------------+
|                                                                             |
|  REGISTERS: x0=0 (always), x1-x31 = general purpose                         |
|                                                                             |
|  R-TYPE (opcode=0110011):  ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
|  I-TYPE (opcode=0010011):  ADDI, ANDI, ORI, XORI, SLTI, SLTIU               |
|  I-SHIFT (opcode=0010011): SLLI, SRLI, SRAI                                 |
|  LOAD (opcode=0000011):    LB, LH, LW, LBU, LHU                             |
|  STORE (opcode=0100011):   SB, SH, SW                                       |
|  BRANCH (opcode=1100011):  BEQ, BNE, BLT, BGE, BLTU, BGEU                   |
|  JUMP:                     JAL (1101111), JALR (1100111)                    |
|  UPPER:                    LUI (0110111), AUIPC (0010111)                   |
|                                                                             |
|  ADD vs SUB:  funct7 = 0000000 (ADD) vs 0100000 (SUB)                       |
|  SRL vs SRA:  funct7 = 0000000 (SRL) vs 0100000 (SRA)                       |
|                                                                             |
+-----------------------------------------------------------------------------+
```

---

## Opcode Map

```
+-------------------------------------------------------------+
|                    RISC-V Opcode Map                        |
+-------------+-----------------+-----------------------------+
|   Opcode    |     Name        |        Instructions         |
+-------------+-----------------+-----------------------------+
|   0110111   |     LUI         |  LUI                        |
|   0010111   |     AUIPC       |  AUIPC                      |
|   1101111   |     JAL         |  JAL                        |
|   1100111   |     JALR        |  JALR                       |
|   1100011   |     BRANCH      |  BEQ, BNE, BLT, BGE, etc.   |
|   0000011   |     LOAD        |  LB, LH, LW, LBU, LHU       |
|   0100011   |     STORE       |  SB, SH, SW                 |
|   0010011   |     OP-IMM      |  ADDI, SLTI, ORI, etc.      |
|   0110011   |     OP          |  ADD, SUB, AND, OR, etc.    |
+-------------+-----------------+-----------------------------+
```

---

## References

- [RISC-V Specification](https://riscv.org/specifications/)
- [RISC-V Green Card](https://www.cl.cam.ac.uk/teaching/1617/ECAD+Arch/files/docs/RISCVGreenCardv8-20151013.pdf)
