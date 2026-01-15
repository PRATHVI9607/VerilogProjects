#!/usr/bin/env python3
"""Generate Test Suite 3 - Different instruction patterns"""

def encode_rtype(opcode, rd, funct3, rs1, rs2, funct7):
    return ((funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode) & 0xFFFFFFFF

def encode_itype(opcode, rd, funct3, rs1, imm):
    imm = imm & 0xFFF
    return ((imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode) & 0xFFFFFFFF

def format_instruction(desc, encoding):
    return (desc, encoding)

# Test Suite 3 - Different patterns
tests = []

# === Test Group 1: Small values and combinations ===
tests.append(format_instruction('addi x1, x0, 3', encode_itype(0x13, 1, 0, 0, 3)))
tests.append(format_instruction('addi x2, x0, 7', encode_itype(0x13, 2, 0, 0, 7)))
tests.append(format_instruction('addi x3, x0, 11', encode_itype(0x13, 3, 0, 0, 11)))
tests.append(format_instruction('add x4, x1, x2', encode_rtype(0x33, 4, 0, 1, 2, 0)))
tests.append(format_instruction('add x5, x2, x3', encode_rtype(0x33, 5, 0, 2, 3, 0)))
tests.append(format_instruction('add x6, x1, x3', encode_rtype(0x33, 6, 0, 1, 3, 0)))

# === Test Group 2: Subtraction patterns ===
tests.append(format_instruction('addi x7, x0, 50', encode_itype(0x13, 7, 0, 0, 50)))
tests.append(format_instruction('addi x8, x0, 30', encode_itype(0x13, 8, 0, 0, 30)))
tests.append(format_instruction('sub x9, x7, x8', encode_rtype(0x33, 9, 0, 7, 8, 0x20)))
tests.append(format_instruction('sub x10, x8, x1', encode_rtype(0x33, 10, 0, 8, 1, 0x20)))

# === Test Group 3: Bitwise operations with hex patterns ===
tests.append(format_instruction('addi x11, x0, 0x55', encode_itype(0x13, 11, 0, 0, 0x55)))
tests.append(format_instruction('addi x12, x0, 0xAA', encode_itype(0x13, 12, 0, 0, 0xAA)))
tests.append(format_instruction('and x13, x11, x12', encode_rtype(0x33, 13, 7, 11, 12, 0)))
tests.append(format_instruction('or x14, x11, x12', encode_rtype(0x33, 14, 6, 11, 12, 0)))
tests.append(format_instruction('xor x15, x11, x12', encode_rtype(0x33, 15, 4, 11, 12, 0)))

# === Test Group 4: More bitwise with different patterns ===
tests.append(format_instruction('addi x16, x0, 0x33', encode_itype(0x13, 16, 0, 0, 0x33)))
tests.append(format_instruction('addi x17, x0, 0xCC', encode_itype(0x13, 17, 0, 0, 0xCC)))
tests.append(format_instruction('and x18, x16, x17', encode_rtype(0x33, 18, 7, 16, 17, 0)))
tests.append(format_instruction('or x19, x16, x17', encode_rtype(0x33, 19, 6, 16, 17, 0)))
tests.append(format_instruction('xor x20, x16, x17', encode_rtype(0x33, 20, 4, 16, 17, 0)))

# === Test Group 5: Shift patterns ===
tests.append(format_instruction('addi x21, x0, 64', encode_itype(0x13, 21, 0, 0, 64)))
tests.append(format_instruction('addi x22, x0, 2', encode_itype(0x13, 22, 0, 0, 2)))
tests.append(format_instruction('sll x23, x21, x22', encode_rtype(0x33, 23, 1, 21, 22, 0)))
tests.append(format_instruction('srl x24, x23, x22', encode_rtype(0x33, 24, 5, 23, 22, 0)))

# === Test Group 6: Comparisons ===
tests.append(format_instruction('slt x25, x1, x7', encode_rtype(0x33, 25, 2, 1, 7, 0)))
tests.append(format_instruction('slt x26, x7, x1', encode_rtype(0x33, 26, 2, 7, 1, 0)))
tests.append(format_instruction('sltu x27, x2, x8', encode_rtype(0x33, 27, 3, 2, 8, 0)))

# === Test Group 7: Forwarding chains ===
tests.append(format_instruction('addi x28, x0, 15', encode_itype(0x13, 28, 0, 0, 15)))
tests.append(format_instruction('add x28, x28, x1', encode_rtype(0x33, 28, 0, 28, 1, 0)))
tests.append(format_instruction('add x28, x28, x2', encode_rtype(0x33, 28, 0, 28, 2, 0)))
tests.append(format_instruction('sub x28, x28, x3', encode_rtype(0x33, 28, 0, 28, 3, 0x20)))

# === Test Group 8: Zero register and edge cases ===
tests.append(format_instruction('add x29, x7, x0', encode_rtype(0x33, 29, 0, 7, 0, 0)))
tests.append(format_instruction('sub x30, x0, x1', encode_rtype(0x33, 30, 0, 0, 1, 0x20)))
tests.append(format_instruction('addi x31, x0, 1000', encode_itype(0x13, 31, 0, 0, 1000)))

# Write hex file
with open('program.hex', 'w') as f:
    for desc, encoding in tests:
        f.write(f"{encoding:08X}\n")

# Write readable instruction list
with open('instructions.txt', 'w') as f:
    f.write("=" * 80 + "\n")
    f.write("TEST SUITE 3 - INSTRUCTION LIST\n")
    f.write("=" * 80 + "\n\n")
    
    groups = [
        (0, 6, "Test Group 1: Small values and combinations"),
        (6, 10, "Test Group 2: Subtraction patterns"),
        (10, 15, "Test Group 3: Bitwise operations with hex patterns (0x55 & 0xAA)"),
        (15, 20, "Test Group 4: More bitwise with different patterns (0x33 & 0xCC)"),
        (20, 24, "Test Group 5: Shift patterns"),
        (24, 27, "Test Group 6: Comparisons"),
        (27, 31, "Test Group 7: Forwarding chains"),
        (31, 34, "Test Group 8: Zero register and edge cases"),
    ]
    
    for start, end, title in groups:
        f.write(f"\n### {title}\n")
        f.write("-" * 80 + "\n")
        for i in range(start, end):
            if i < len(tests):
                desc, encoding = tests[i]
                f.write(f"{i:2d}: {encoding:08X}  {desc}\n")
    
    f.write("\n" + "=" * 80 + "\n")
    f.write(f"Total: {len(tests)} instructions\n")
    f.write("=" * 80 + "\n")

print(f"✓ Generated {len(tests)} instructions")
print(f"✓ Created program.hex")
print(f"✓ Created instructions.txt")
