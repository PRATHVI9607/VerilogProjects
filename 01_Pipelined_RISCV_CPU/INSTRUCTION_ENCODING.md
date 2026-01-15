# RISC-V CPU Architecture Details

## Register File

### Number of Registers: **32 registers**

The CPU has **32 general-purpose registers** (x0 to x31), each 32 bits wide.

**Why 32 and not a power of 2?**  
Actually, **32 IS a power of 2!** (2^5 = 32)

This is the standard RISC-V specification:
- 32 registers total
- Requires 5 bits to address any register (2^5 = 32)
- Register x0 is hardwired to 0 (always reads as 0, writes are ignored)
- Registers x1-x31 are general-purpose

**Register Addressing:**
- Uses 5-bit fields in instructions (bits can represent 0-31)
- rs1: source register 1 (bits 19:15)
- rs2: source register 2 (bits 24:20)  
- rd: destination register (bits 11:7)

**Implementation in Code:**
```verilog
// From instruction_decode.v line 43:
reg [31:0] regfile [0:31];  // 32 registers, each 32 bits
```

---

## 32-Bit Instruction Encoding

RISC-V uses **fixed 32-bit instruction encoding** for all instructions. Different instruction types have different field layouts:

### **R-Type (Register-Register operations)**
Used for: ADD, SUB, AND, OR, XOR, SLL, SRL, SLT, SLTU

```
31      25|24    20|19    15|14  12|11     7|6      0
[funct7   ][  rs2 ][  rs1  ][funct3][   rd  ][opcode ]
  7 bits     5 bits   5 bits  3 bits  5 bits  7 bits
```

**Example: ADD x4, x1, x2**
```
Instruction: 00208233
Binary: 0000000_00010_00001_000_00100_0110011

funct7  = 0000000 (0x00) - ADD operation
rs2     = 00010   (2)    - x2
rs1     = 00001   (1)    - x1  
funct3  = 000     (0)    - ADD/SUB selector
rd      = 00100   (4)    - x4
opcode  = 0110011 (0x33) - R-type opcode
```

**Example: SUB x9, x7, x8**
```
Instruction: 408384B3
Binary: 0100000_01000_00111_000_01001_0110011

funct7  = 0100000 (0x20) - SUB operation (note: different from ADD!)
rs2     = 01000   (8)    - x8
rs1     = 00111   (7)    - x7
funct3  = 000     (0)    - ADD/SUB selector
rd      = 01001   (9)    - x9
opcode  = 0110011 (0x33) - R-type opcode
```

---

### **I-Type (Immediate operations)**
Used for: ADDI, SLLI, SRLI, LW, etc.

```
31            20|19    15|14  12|11     7|6      0
[   imm[11:0]  ][  rs1  ][funct3][   rd  ][opcode ]
    12 bits       5 bits  3 bits  5 bits  7 bits
```

**Example: ADDI x1, x0, 25**
```
Instruction: 01900093
Binary: 000000011001_00000_000_00001_0010011

imm     = 000000011001 (25 in decimal, 0x19)
rs1     = 00000   (0)    - x0
funct3  = 000     (0)    - ADDI
rd      = 00001   (1)    - x1
opcode  = 0010011 (0x13) - I-type opcode
```

**Example: ADDI x11, x0, 0x55 (85 decimal)**
```
Instruction: 05500593
Binary: 000001010101_00000_000_01011_0010011

imm     = 000001010101 (0x55 = 85 decimal)
rs1     = 00000   (0)    - x0
funct3  = 000     (0)    - ADDI
rd      = 01011   (11)   - x11
opcode  = 0010011 (0x13) - I-type opcode
```

**Negative Immediates:**
The 12-bit immediate is sign-extended to 32 bits.

**Example: ADDI x30, x0, -2048**
```
Instruction: 80000F33
Binary: 100000000000_00000_000_11110_0010011

imm     = 100000000000 (-2048 in 12-bit two's complement)
          Sign bit is 1, so extends to 0xFFFFF800 in 32 bits
rs1     = 00000   (0)    - x0
funct3  = 000     (0)    - ADDI
rd      = 11110   (30)   - x30
opcode  = 0010011 (0x13) - I-type opcode

Result: x30 = 0xFFFFF800 = -2048 in signed 32-bit
```

---

## Opcode Table

| Instruction Type | Opcode (7 bits) | Hex   |
|------------------|-----------------|-------|
| R-type (ADD, SUB, AND, OR, etc.) | 0110011 | 0x33  |
| I-type (ADDI, loads) | 0010011 | 0x13  |
| S-type (stores)  | 0100011 | 0x23  |
| B-type (branches)| 1100011 | 0x63  |
| U-type (LUI)     | 0110111 | 0x37  |
| J-type (JAL)     | 1101111 | 0x6F  |

---

## Funct3 and Funct7 Table

### R-Type Operations (opcode = 0x33)

| Operation | funct7  | funct3 | Description |
|-----------|---------|--------|-------------|
| ADD       | 0000000 | 000    | rd = rs1 + rs2 |
| SUB       | 0100000 | 000    | rd = rs1 - rs2 |
| SLL       | 0000000 | 001    | rd = rs1 << rs2 |
| SLT       | 0000000 | 010    | rd = (rs1 < rs2) signed |
| SLTU      | 0000000 | 011    | rd = (rs1 < rs2) unsigned |
| XOR       | 0000000 | 100    | rd = rs1 ^ rs2 |
| SRL       | 0000000 | 101    | rd = rs1 >> rs2 (logical) |
| OR        | 0000000 | 110    | rd = rs1 | rs2 |
| AND       | 0000000 | 111    | rd = rs1 & rs2 |

### I-Type Operations (opcode = 0x13)

| Operation | funct3 | Description |
|-----------|--------|-------------|
| ADDI      | 000    | rd = rs1 + imm |
| SLLI      | 001    | rd = rs1 << imm[4:0] |
| SLTI      | 010    | rd = (rs1 < imm) signed |
| SLTIU     | 011    | rd = (rs1 < imm) unsigned |
| XORI      | 100    | rd = rs1 ^ imm |
| SRLI/SRAI | 101    | rd = rs1 >> imm[4:0] |
| ORI       | 110    | rd = rs1 | imm |
| ANDI      | 111    | rd = rs1 & imm |

---

## Complete Instruction Encoding Examples from Test Suite 3

```
# Test Group 1: Small values
00300093 = addi x1, x0, 3       → x1 = 3
00700113 = addi x2, x0, 7       → x2 = 7
00208233 = add x4, x1, x2       → x4 = 3+7 = 10

# Test Group 3: Bitwise (0x55 & 0xAA)
05500593 = addi x11, x0, 0x55   → x11 = 0x55 (01010101)
0AA00613 = addi x12, x0, 0xAA   → x12 = 0xAA (10101010)
00C5F6B3 = and x13, x11, x12    → x13 = 0x00 (no common bits)
00C5E733 = or x14, x11, x12     → x14 = 0xFF (all bits set)
00C5C7B3 = xor x15, x11, x12    → x15 = 0xFF (all bits differ)

# Test Group 5: Shifts
04000A93 = addi x21, x0, 64     → x21 = 64
00200B13 = addi x22, x0, 2      → x22 = 2
016A9BB3 = sll x23, x21, x22    → x23 = 64 << 2 = 256
016BDC33 = srl x24, x23, x22    → x24 = 256 >> 2 = 64
```

---

## Why This Encoding?

1. **Fixed 32-bit length**: Simplifies instruction fetch and decode
2. **Consistent field positions**: rs1, rs2, rd mostly in same positions across types
3. **5-bit register fields**: Allows addressing all 32 registers
4. **Opcode in bits [6:0]**: Easy to decode instruction type
5. **funct3/funct7**: Distinguishes between operations of same type

This is the **official RISC-V ISA specification** - your CPU implements it correctly! ✓
