#!/usr/bin/env python3
"""Test Suite 3 Verification - Different instruction patterns"""

import subprocess
import re
import sys

# Expected register values - carefully calculated
expected_values = {
    'x1': (0x00000003, 3, "addi x1, x0, 3"),
    'x2': (0x00000007, 7, "addi x2, x0, 7"),
    'x3': (0x0000000B, 11, "addi x3, x0, 11"),
    'x4': (0x0000000A, 10, "add x4, x1, x2 (3+7)"),
    'x5': (0x00000012, 18, "add x5, x2, x3 (7+11)"),
    'x6': (0x0000000E, 14, "add x6, x1, x3 (3+11)"),
    'x7': (0x00000032, 50, "addi x7, x0, 50"),
    'x8': (0x0000001E, 30, "addi x8, x0, 30"),
    'x9': (0x00000014, 20, "sub x9, x7, x8 (50-30)"),
    'x10': (0x0000001B, 27, "sub x10, x8, x1 (30-3)"),
    'x11': (0x00000055, 85, "addi x11, x0, 0x55"),
    'x12': (0x000000AA, 170, "addi x12, x0, 0xAA"),
    'x13': (0x00000000, 0, "and x13, x11, x12 (0x55&0xAA)"),
    'x14': (0x000000FF, 255, "or x14, x11, x12 (0x55|0xAA)"),
    'x15': (0x000000FF, 255, "xor x15, x11, x12 (0x55^0xAA)"),
    'x16': (0x00000033, 51, "addi x16, x0, 0x33"),
    'x17': (0x000000CC, 204, "addi x17, x0, 0xCC"),
    'x18': (0x00000000, 0, "and x18, x16, x17 (0x33&0xCC)"),
    'x19': (0x000000FF, 255, "or x19, x16, x17 (0x33|0xCC)"),
    'x20': (0x000000FF, 255, "xor x20, x16, x17 (0x33^0xCC)"),
    'x21': (0x00000040, 64, "addi x21, x0, 64"),
    'x22': (0x00000002, 2, "addi x22, x0, 2"),
    'x23': (0x00000100, 256, "sll x23, x21, x22 (64<<2)"),
    'x24': (0x00000040, 64, "srl x24, x23, x22 (256>>2)"),
    'x25': (0x00000001, 1, "slt x25, x1, x7 (3<50=1)"),
    'x26': (0x00000000, 0, "slt x26, x7, x1 (50<3=0)"),
    'x27': (0x00000001, 1, "sltu x27, x2, x8 (7<30=1)"),
    'x28': (0x0000000E, 14, "chain: 15+3+7-11"),
    'x29': (0x00000032, 50, "add x29, x7, x0 (50+0)"),
    'x30': (0xFFFFFFFD, -3, "sub x30, x0, x1 (0-3=-3)"),
    'x31': (0x000003E8, 1000, "addi x31, x0, 1000"),
}

def run_simulation():
    """Run the CPU simulation and capture output"""
    try:
        result = subprocess.run(
            ['make', 'sim'],
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        print("ERROR: Simulation timed out")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Failed to run simulation: {e}")
        sys.exit(1)

def parse_register_values(output):
    """Extract register values from simulation output"""
    registers = {}
    pattern = r'x(\d+)\s*=\s*([0-9a-fA-F]{8})\s*\((-?\d+)\)'
    
    for match in re.finditer(pattern, output):
        reg_num = int(match.group(1))
        hex_val = int(match.group(2), 16)
        reg_name = f'x{reg_num}'
        registers[reg_name] = hex_val
    
    return registers

def verify_tests(registers):
    """Compare actual vs expected register values"""
    passed = 0
    failed = 0
    
    print("=" * 80)
    print("TEST SUITE 3 VERIFICATION - Different Instruction Patterns")
    print("=" * 80)
    print()
    
    for reg_name in sorted(expected_values.keys(), key=lambda x: int(x[1:])):
        expected_hex, expected_dec, description = expected_values[reg_name]
        
        if reg_name in registers:
            actual = registers[reg_name]
            actual_signed = actual if actual < 0x80000000 else actual - 0x100000000
            
            if actual == expected_hex:
                print(f"✓ {reg_name:3s}: 0x{actual:08X} ({actual_signed:10d}) - {description}")
                passed += 1
            else:
                print(f"✗ {reg_name:3s}: 0x{actual:08X} ({actual_signed:10d}) EXPECTED: 0x{expected_hex:08X} ({expected_dec})")
                print(f"        {description}")
                failed += 1
        else:
            print(f"✗ {reg_name:3s}: NOT FOUND - {description}")
            failed += 1
    
    print()
    print("=" * 80)
    print(f"Results: {passed} passed, {failed} failed out of {passed + failed} tests")
    print("=" * 80)
    
    if failed == 0:
        print("\n🎉 ALL TESTS PASSED! Test Suite 3 validated successfully.")
    
    return failed == 0

def main():
    print("Running Test Suite 3 simulation...")
    output = run_simulation()
    
    registers = parse_register_values(output)
    
    if not registers:
        print("ERROR: No register values found in simulation output")
        sys.exit(1)
    
    success = verify_tests(registers)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
