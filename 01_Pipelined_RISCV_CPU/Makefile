# Makefile for Pipelined RISC-V CPU

# Verilog compiler
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Directories
RTL_DIR = rtl
TB_DIR = tb

# Source files
RTL_FILES = $(RTL_DIR)/riscv_pkg.v \
            $(RTL_DIR)/instruction_fetch.v \
            $(RTL_DIR)/instruction_decode.v \
            $(RTL_DIR)/execute.v \
            $(RTL_DIR)/memory_stage.v \
            $(RTL_DIR)/writeback.v \
            $(RTL_DIR)/forwarding_unit.v \
            $(RTL_DIR)/hazard_unit.v \
            $(RTL_DIR)/riscv_cpu.v

TB_FILE = $(TB_DIR)/tb_riscv_cpu.v

# Output files
SIM_OUT = riscv_cpu_sim
VCD_FILE = riscv_cpu.vcd

# Default target
all: sim

# Compile
compile:
	$(IVERILOG) -g2012 -o $(SIM_OUT) -I $(RTL_DIR) $(RTL_FILES) $(TB_FILE)

# Run simulation
sim: compile
	$(VVP) $(SIM_OUT)

# View waveforms
wave: sim
	$(GTKWAVE) $(VCD_FILE) &

# Clean
clean:
	rm -f $(SIM_OUT) $(VCD_FILE) *.vvp

.PHONY: all compile sim wave clean
