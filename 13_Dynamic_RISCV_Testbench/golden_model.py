#!/usr/bin/env python3
"""
================================================================================
                    RISC-V RV32I Golden Model Simulator
================================================================================
This script simulates RISC-V instructions and generates expected register values.
The testbench reads these values to dynamically verify the CPU.

Supported Instructions (24):
  R-Type:  ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
  I-Type:  ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI, LW
  S-Type:  SW
  U-Type:  LUI, AUIPC
  B-Type:  BEQ

Usage: python3 golden_model.py program.hex > expected_values.hex
================================================================================
"""

import sys
import re

class RV32ISimulator:
    def __init__(self):
        # 32 registers, x0 is always 0
        self.regs = [0] * 32
        # Memory (word-addressed, 1KB)
        self.memory = {}
        # Program counter
        self.pc = 0
        # Instructions loaded from hex file
        self.instructions = []
        
    def sign_extend(self, value, bits):
        """Sign extend a value from 'bits' to 32 bits"""
        sign_bit = 1 << (bits - 1)
        return (value & (sign_bit - 1)) - (value & sign_bit)
    
    def to_signed32(self, value):
        """Convert to signed 32-bit integer"""
        value = value & 0xFFFFFFFF
        if value >= 0x80000000:
            return value - 0x100000000
        return value
    
    def to_unsigned32(self, value):
        """Keep as unsigned 32-bit integer"""
        return value & 0xFFFFFFFF
    
    def load_program(self, filename):
        """Load hex file and extract instruction words"""
        self.instructions = []
        with open(filename, 'r') as f:
            for line in f:
                # Remove comments and whitespace
                line = line.split('//')[0].strip()
                if line:
                    # Check if it's a valid hex instruction (8 hex chars)
                    if re.match(r'^[0-9A-Fa-f]{8}$', line):
                        self.instructions.append(int(line, 16))
        print(f"// Loaded {len(self.instructions)} instructions", file=sys.stderr)
    
    def decode_r_type(self, instr):
        """Decode R-type instruction"""
        rd = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x7
        rs1 = (instr >> 15) & 0x1F
        rs2 = (instr >> 20) & 0x1F
        funct7 = (instr >> 25) & 0x7F
        return rd, funct3, rs1, rs2, funct7
    
    def decode_i_type(self, instr):
        """Decode I-type instruction"""
        rd = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x7
        rs1 = (instr >> 15) & 0x1F
        imm = (instr >> 20) & 0xFFF
        imm = self.sign_extend(imm, 12)
        return rd, funct3, rs1, imm
    
    def decode_s_type(self, instr):
        """Decode S-type instruction"""
        imm_4_0 = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x7
        rs1 = (instr >> 15) & 0x1F
        rs2 = (instr >> 20) & 0x1F
        imm_11_5 = (instr >> 25) & 0x7F
        imm = (imm_11_5 << 5) | imm_4_0
        imm = self.sign_extend(imm, 12)
        return funct3, rs1, rs2, imm
    
    def decode_b_type(self, instr):
        """Decode B-type instruction"""
        imm_11 = (instr >> 7) & 0x1
        imm_4_1 = (instr >> 8) & 0xF
        funct3 = (instr >> 12) & 0x7
        rs1 = (instr >> 15) & 0x1F
        rs2 = (instr >> 20) & 0x1F
        imm_10_5 = (instr >> 25) & 0x3F
        imm_12 = (instr >> 31) & 0x1
        imm = (imm_12 << 12) | (imm_11 << 11) | (imm_10_5 << 5) | (imm_4_1 << 1)
        imm = self.sign_extend(imm, 13)
        return funct3, rs1, rs2, imm
    
    def decode_u_type(self, instr):
        """Decode U-type instruction"""
        rd = (instr >> 7) & 0x1F
        imm = instr & 0xFFFFF000  # Upper 20 bits already in position
        return rd, imm
    
    def execute(self, instr):
        """Execute a single instruction"""
        opcode = instr & 0x7F
        
        # R-type instructions (opcode = 0110011)
        if opcode == 0b0110011:
            rd, funct3, rs1, rs2, funct7 = self.decode_r_type(instr)
            rs1_val = self.to_signed32(self.regs[rs1])
            rs2_val = self.to_signed32(self.regs[rs2])
            rs1_unsigned = self.to_unsigned32(self.regs[rs1])
            rs2_unsigned = self.to_unsigned32(self.regs[rs2])
            shamt = rs2_unsigned & 0x1F
            
            if funct3 == 0b000:
                if funct7 == 0b0000000:  # ADD
                    result = rs1_val + rs2_val
                elif funct7 == 0b0100000:  # SUB
                    result = rs1_val - rs2_val
            elif funct3 == 0b111:  # AND
                result = rs1_unsigned & rs2_unsigned
            elif funct3 == 0b110:  # OR
                result = rs1_unsigned | rs2_unsigned
            elif funct3 == 0b100:  # XOR
                result = rs1_unsigned ^ rs2_unsigned
            elif funct3 == 0b001:  # SLL
                result = rs1_unsigned << shamt
            elif funct3 == 0b101:
                if funct7 == 0b0000000:  # SRL
                    result = rs1_unsigned >> shamt
                elif funct7 == 0b0100000:  # SRA
                    result = rs1_val >> shamt
            elif funct3 == 0b010:  # SLT
                result = 1 if rs1_val < rs2_val else 0
            elif funct3 == 0b011:  # SLTU
                result = 1 if rs1_unsigned < rs2_unsigned else 0
            
            if rd != 0:
                self.regs[rd] = self.to_unsigned32(result)
            self.pc += 4
        
        # I-type ALU instructions (opcode = 0010011)
        elif opcode == 0b0010011:
            rd, funct3, rs1, imm = self.decode_i_type(instr)
            rs1_val = self.to_signed32(self.regs[rs1])
            rs1_unsigned = self.to_unsigned32(self.regs[rs1])
            shamt = imm & 0x1F
            funct7 = (instr >> 25) & 0x7F
            
            if funct3 == 0b000:  # ADDI
                result = rs1_val + imm
            elif funct3 == 0b111:  # ANDI
                result = rs1_unsigned & self.to_unsigned32(imm)
            elif funct3 == 0b110:  # ORI
                result = rs1_unsigned | self.to_unsigned32(imm)
            elif funct3 == 0b100:  # XORI
                result = rs1_unsigned ^ self.to_unsigned32(imm)
            elif funct3 == 0b010:  # SLTI
                result = 1 if rs1_val < imm else 0
            elif funct3 == 0b011:  # SLTIU
                result = 1 if rs1_unsigned < self.to_unsigned32(imm) else 0
            elif funct3 == 0b001:  # SLLI
                result = rs1_unsigned << shamt
            elif funct3 == 0b101:
                if funct7 == 0b0000000:  # SRLI
                    result = rs1_unsigned >> shamt
                elif funct7 == 0b0100000:  # SRAI
                    result = rs1_val >> shamt
            
            if rd != 0:
                self.regs[rd] = self.to_unsigned32(result)
            self.pc += 4
        
        # Load instructions (opcode = 0000011)
        elif opcode == 0b0000011:
            rd, funct3, rs1, imm = self.decode_i_type(instr)
            addr = (self.regs[rs1] + imm) & 0xFFFFFFFF
            word_addr = addr >> 2  # Word-aligned address
            
            if funct3 == 0b010:  # LW
                result = self.memory.get(word_addr, 0)
            
            if rd != 0:
                self.regs[rd] = self.to_unsigned32(result)
            self.pc += 4
        
        # Store instructions (opcode = 0100011)
        elif opcode == 0b0100011:
            funct3, rs1, rs2, imm = self.decode_s_type(instr)
            addr = (self.regs[rs1] + imm) & 0xFFFFFFFF
            word_addr = addr >> 2  # Word-aligned address
            
            if funct3 == 0b010:  # SW
                self.memory[word_addr] = self.regs[rs2]
            self.pc += 4
        
        # Branch instructions (opcode = 1100011)
        elif opcode == 0b1100011:
            funct3, rs1, rs2, imm = self.decode_b_type(instr)
            rs1_val = self.to_signed32(self.regs[rs1])
            rs2_val = self.to_signed32(self.regs[rs2])
            
            take_branch = False
            if funct3 == 0b000:  # BEQ
                take_branch = (rs1_val == rs2_val)
            elif funct3 == 0b001:  # BNE
                take_branch = (rs1_val != rs2_val)
            elif funct3 == 0b100:  # BLT
                take_branch = (rs1_val < rs2_val)
            elif funct3 == 0b101:  # BGE
                take_branch = (rs1_val >= rs2_val)
            elif funct3 == 0b110:  # BLTU
                take_branch = (self.to_unsigned32(self.regs[rs1]) < self.to_unsigned32(self.regs[rs2]))
            elif funct3 == 0b111:  # BGEU
                take_branch = (self.to_unsigned32(self.regs[rs1]) >= self.to_unsigned32(self.regs[rs2]))
            
            if take_branch:
                self.pc += imm
            else:
                self.pc += 4
        
        # LUI (opcode = 0110111)
        elif opcode == 0b0110111:
            rd, imm = self.decode_u_type(instr)
            if rd != 0:
                self.regs[rd] = self.to_unsigned32(imm)
            self.pc += 4
        
        # AUIPC (opcode = 0010111)
        elif opcode == 0b0010111:
            rd, imm = self.decode_u_type(instr)
            if rd != 0:
                self.regs[rd] = self.to_unsigned32(self.pc + imm)
            self.pc += 4
        
        else:
            # Unknown or NOP
            self.pc += 4
    
    def run(self, max_cycles=1000):
        """Run the simulation"""
        cycles = 0
        while self.pc // 4 < len(self.instructions) and cycles < max_cycles:
            instr_idx = self.pc // 4
            if instr_idx >= len(self.instructions):
                break
            instr = self.instructions[instr_idx]
            self.execute(instr)
            cycles += 1
        print(f"// Simulation completed in {cycles} cycles", file=sys.stderr)
    
    def output_expected_values(self):
        """Output register values in hex format for testbench"""
        print("// ============================================")
        print("// Golden Model Expected Register Values")
        print("// Format: register_index expected_value")
        print("// ============================================")
        for i in range(32):
            print(f"{i:02d} {self.regs[i]:08x}")
    
    def print_summary(self):
        """Print human-readable summary to stderr"""
        print("\n// Register Summary:", file=sys.stderr)
        for i in range(32):
            if self.regs[i] != 0:
                signed_val = self.to_signed32(self.regs[i])
                print(f"//   x{i:2d} = 0x{self.regs[i]:08x} ({signed_val})", file=sys.stderr)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 golden_model.py program.hex", file=sys.stderr)
        print("       Output goes to stdout, use redirection to save", file=sys.stderr)
        sys.exit(1)
    
    sim = RV32ISimulator()
    sim.load_program(sys.argv[1])
    sim.run()
    sim.print_summary()
    sim.output_expected_values()


if __name__ == "__main__":
    main()
