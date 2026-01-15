#!/usr/bin/env python3
"""
New Test Suite Verification for Pipelined RISC-V CPU
Tests a different set of instructions and values
"""

import subprocess
import re
import sys

# Expected register values after executing new test program
expected_values = {
    'x1': (0x00000019, 25, "addi x1, x0, 25"),
    'x2': (0x00000011, 17, "addi x2, x0, 17"),
    'x3': (0x00000064, 100, "addi x3, x0, 100"),
    'x4': (0x0000002A, 42, "add x4, x1, x2 (25+17)"),
    'x5': (0x00000075, 117, "add x5, x2, x3 (17+100)"),
    'x6': (0x0000004B, 75, "sub x6, x3, x1 (100-25)"),
    'x7': (0x0000004B, 75, "sub x7, x5, x4 (117-42=75)"),
    'x8': (0x000001F5, 501, "addi x8, x0, 501"),
    'x9': (0x000000FF, 255, "addi x9, x0, 255"),
    'x10': (0x000000F5, 245, "and x10, x8, x9 (501&255)"),
    'x11': (0x000000F0, 240, "addi x11, x0, 240"),
    'x12': (0x000000FF, 255, "or x12, x9, x11 (255|240)"),
    'x13': (0x000000AA, 170, "addi x13, x0, 170"),
    'x14': (0x00000055, 85, "xor x14, x13, x9 (170^255)"),
    'x15': (0x00000010, 16, "addi x15, x0, 16"),
    'x16': (0x00000003, 3, "addi x16, x0, 3"),
    'x17': (0x00000080, 128, "sll x17, x15, x16 (16<<3)"),
    'x18': (0x00000010, 16, "srl x18, x17, x16 (128>>3)"),
    'x19': (0x00000000, 0, "slt x19, x1, x2 (25<17=0)"),
    'x20': (0x00000001, 1, "slt x20, x2, x1 (17<25=1)"),
    'x21': (0x00000000, 0, "sltu x21, x1, x2 (25<17 unsigned, false)"),
    'x22': (0x00000014, 20, "add x22, x22, x23 (7+13) with forwarding"),
    'x23': (0x00000021, 33, "add x23, x22, x23 (20+13) with forwarding"),
    'x24': (0x00000019, 25, "add x24, x1, x0 (25+0)"),
    'x25': (0x00000000, 0, "add x25, x0, x0 (0+0)"),
    'x26': (0x000007FF, 2047, "addi x26, x0, 2047"),
    'x27': (0xFFFFF800, -2048, "addi x27, x0, -2048"),
    'x28': (0x00000023, 35, "addi chain: 50-20+5"),
    'x29': (0x00000063, 99, "addi x29, x0, 99"),
    'x30': (0x00000040, 64, "sub x30, x29, x28 (99-35)"),
    'x31': (0x000000A3, 163, "add x31, x29, x30 (99+64)"),
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
    
    # Pattern matches: x1  = 00000005 (5)
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
    print("NEW TEST SUITE VERIFICATION - Different Instructions & Values")
    print("=" * 80)
    print()
    
    for reg_name in sorted(expected_values.keys(), key=lambda x: int(x[1:])):
        expected_hex, expected_dec, description = expected_values[reg_name]
        
        if reg_name in registers:
            actual = registers[reg_name]
            
            # Handle signed comparison for display
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
        print("\n🎉 ALL NEW TESTS PASSED! CPU validated with different instruction set.")
    
    return failed == 0

def main():
    print("Running new test suite simulation...")
    output = run_simulation()
    
    registers = parse_register_values(output)
    
    if not registers:
        print("ERROR: No register values found in simulation output")
        sys.exit(1)
    
    success = verify_tests(registers)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
