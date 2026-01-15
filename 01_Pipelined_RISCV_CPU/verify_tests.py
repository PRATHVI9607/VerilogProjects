#!/usr/bin/env python3
"""
Test verification script for RISC-V CPU
Checks if all computed values are correct
"""

expected = {
    'x1': (0x00000005, 5, "addi x1, x0, 5"),
    'x2': (0x0000000A, 10, "addi x2, x0, 10"),
    'x3': (0x0000000F, 15, "add x3, x1, x2 (5+10)"),
    'x4': (0xFFFFFFFB, -5, "sub x4, x1, x2 (5-10)"),
    'x5': (0x000000FF, 255, "addi x5, x0, 255"),
    'x6': (0x000000F0, 240, "addi x6, x0, 240"),
    'x7': (0x000000F0, 240, "and x7, x6, x6 (240&240)"),
    'x8': (0x000000FF, 255, "or x8, x6, x5 (240|255)"),
    'x9': (0x0000000F, 15, "xor x9, x6, x5 (240^255)"),
    'x10': (0x00000008, 8, "addi x10, x0, 8"),
    'x11': (0x00000002, 2, "addi x11, x0, 2"),
    'x12': (0x00000020, 32, "sll x12, x10, x11 (8<<2)"),
    'x13': (0x00000020, 32, "addi x13, x0, 32"),
    'x14': (0x00000008, 8, "srl x14, x13, x11 (32>>2)"),
    'x15': (0x00000001, 1, "slt x15, x1, x2 (5<10)"),
    'x16': (0x00000000, 0, "slt x16, x2, x1 (10<5)"),
    'x17': (0x00000000, 0, "sltu x17, x3, x3 (x3<x3)"),
    'x18': (0x00000008, 8, "add x18, x18, x19 (3+5) with forwarding"),
    'x19': (0x0000000D, 13, "add x19, x18, x19 (8+5) with forwarding"),
    'x20': (0x00000005, 5, "add x20, x1, x0 (5+0)"),
    'x21': (0x00000000, 0, "add x21, x0, x0 (0+0)"),
    'x22': (0x000007FF, 2047, "addi x22, x0, 2047"),
    'x23': (0xFFFFF800, -2048, "addi x23, x0, -2048"),
    'x24': (0x00000004, 4, "chained addi operations (1+1+1+1)"),
    'x25': (0x0000000E, 14, "addi chain (10+5-1)"),
    'x26': (0x00000000, 0, "boundary test (0-1+1)"),
}

# Read actual values from simulation output
import subprocess
import re

result = subprocess.run(
    ['make', 'sim'],
    cwd='/home/ippo/Desktop/ADLDProjects/01_Pipelined_RISCV_CPU',
    capture_output=True,
    text=True
)

# Parse register values
actual = {}
for line in result.stdout.split('\n'):
    match = re.match(r'x(\d+)\s*=\s*([0-9a-f]+)', line)
    if match:
        reg_num = int(match.group(1))
        value = int(match.group(2), 16)
        actual[f'x{reg_num}'] = value

print("=" * 80)
print("RISC-V CPU TEST VERIFICATION")
print("=" * 80)
print()

errors = 0
passed = 0

for reg, (expected_val, signed_val, desc) in expected.items():
    if reg in actual:
        actual_val = actual[reg]
        # Convert to signed for comparison
        actual_signed = actual_val if actual_val < 0x80000000 else actual_val - 0x100000000
        expected_signed = expected_val if expected_val < 0x80000000 else expected_val - 0x100000000
        
        if actual_val == expected_val:
            print(f"✓ {reg:3s}: 0x{actual_val:08X} ({actual_signed:11d}) - {desc}")
            passed += 1
        else:
            print(f"✗ {reg:3s}: 0x{actual_val:08X} ({actual_signed:11d}) EXPECTED: 0x{expected_val:08X} ({expected_signed:d})")
            print(f"        {desc}")
            errors += 1
    else:
        print(f"✗ {reg:3s}: NOT FOUND - {desc}")
        errors += 1

print()
print("=" * 80)
print(f"Results: {passed} passed, {errors} failed out of {len(expected)} tests")
print("=" * 80)

if errors > 0:
    exit(1)
else:
    print("\n🎉 ALL TESTS PASSED! CPU is working correctly.")
    exit(0)
