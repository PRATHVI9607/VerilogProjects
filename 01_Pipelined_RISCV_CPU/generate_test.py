#!/usr/bin/env python3
def encode_rtype(opcode, rd, funct3, rs1, rs2, funct7):
    return ((funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode) & 0xFFFFFFFF

def encode_itype(opcode, rd, funct3, rs1, imm):
    imm = imm & 0xFFF
    return ((imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode) & 0xFFFFFFFF

instructions = []
instructions.append(('addi x1, x0, 25', encode_itype(0x13, 1, 0, 0, 25)))
instructions.append(('addi x2, x0, 17', encode_itype(0x13, 2, 0, 0, 17)))
instructions.append(('addi x3, x0, 100', encode_itype(0x13, 3, 0, 0, 100)))
instructions.append(('add x4, x1, x2', encode_rtype(0x33, 4, 0, 1, 2, 0)))
instructions.append(('add x5, x2, x3', encode_rtype(0x33, 5, 0, 2, 3, 0)))
instructions.append(('sub x6, x3, x1', encode_rtype(0x33, 6, 0, 3, 1, 0x20)))
instructions.append(('sub x7, x5, x4', encode_rtype(0x33, 7, 0, 5, 4, 0x20)))
instructions.append(('addi x8, x0, 0x1F5', encode_itype(0x13, 8, 0, 0, 0x1F5)))
instructions.append(('addi x9, x0, 0x0FF', encode_itype(0x13, 9, 0, 0, 0x0FF)))
instructions.append(('and x10, x8, x9', encode_rtype(0x33, 10, 7, 8, 9, 0)))
instructions.append(('addi x11, x0, 0xF0', encode_itype(0x13, 11, 0, 0, 0xF0)))
instructions.append(('or x12, x9, x11', encode_rtype(0x33, 12, 6, 9, 11, 0)))
instructions.append(('addi x13, x0, 0xAA', encode_itype(0x13, 13, 0, 0, 0xAA)))
instructions.append(('xor x14, x13, x9', encode_rtype(0x33, 14, 4, 13, 9, 0)))
instructions.append(('addi x15, x0, 16', encode_itype(0x13, 15, 0, 0, 16)))
instructions.append(('addi x16, x0, 3', encode_itype(0x13, 16, 0, 0, 3)))
instructions.append(('sll x17, x15, x16', encode_rtype(0x33, 17, 1, 15, 16, 0)))
instructions.append(('srl x18, x17, x16', encode_rtype(0x33, 18, 5, 17, 16, 0)))
instructions.append(('slt x19, x1, x2', encode_rtype(0x33, 19, 2, 1, 2, 0)))
instructions.append(('slt x20, x2, x1', encode_rtype(0x33, 20, 2, 2, 1, 0)))
instructions.append(('sltu x21, x1, x2', encode_rtype(0x33, 21, 3, 1, 2, 0)))
instructions.append(('addi x22, x0, 7', encode_itype(0x13, 22, 0, 0, 7)))
instructions.append(('addi x23, x0, 13', encode_itype(0x13, 23, 0, 0, 13)))
instructions.append(('add x22, x22, x23', encode_rtype(0x33, 22, 0, 22, 23, 0)))
instructions.append(('add x23, x22, x23', encode_rtype(0x33, 23, 0, 22, 23, 0)))
instructions.append(('add x24, x1, x0', encode_rtype(0x33, 24, 0, 1, 0, 0)))
instructions.append(('add x25, x0, x0', encode_rtype(0x33, 25, 0, 0, 0, 0)))
instructions.append(('addi x26, x0, 2047', encode_itype(0x13, 26, 0, 0, 2047)))
instructions.append(('addi x27, x0, -2048', encode_itype(0x13, 27, 0, 0, -2048)))
instructions.append(('addi x28, x0, 50', encode_itype(0x13, 28, 0, 0, 50)))
instructions.append(('addi x28, x28, -20', encode_itype(0x13, 28, 0, 28, -20)))
instructions.append(('addi x28, x28, 5', encode_itype(0x13, 28, 0, 28, 5)))
instructions.append(('addi x29, x0, 99', encode_itype(0x13, 29, 0, 0, 99)))
instructions.append(('sub x30, x29, x28', encode_rtype(0x33, 30, 0, 29, 28, 0x20)))
instructions.append(('add x31, x29, x30', encode_rtype(0x33, 31, 0, 29, 30, 0)))

with open('program.hex', 'w') as f:
    for desc, instr in instructions:
        f.write(f"{instr:08X}\n")

print(f"Created {len(instructions)} instructions")
