# Virtual Memory Simulator Makefile

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Directories
RTL_DIR = rtl
TB_DIR = tb

# Source files
RTL_SRCS = $(RTL_DIR)/page_table_entry.v \
           $(RTL_DIR)/page_frame_allocator.v \
           $(RTL_DIR)/page_replacement.v \
           $(RTL_DIR)/virtual_memory_controller.v

TB_SRCS = $(TB_DIR)/tb_virtual_memory.v

# Output files
SIM_OUT = virtual_memory_sim
VCD_FILE = virtual_memory_tb.vcd

# Default target
all: simulate

# Compile
compile: $(RTL_SRCS) $(TB_SRCS)
	$(IVERILOG) -o $(SIM_OUT) -g2012 $(TB_SRCS) $(RTL_SRCS)

# Simulate
simulate: compile
	$(VVP) $(SIM_OUT)

# View waveforms
wave: simulate
	$(GTKWAVE) $(VCD_FILE) &

# Clean
clean:
	rm -f $(SIM_OUT) $(VCD_FILE)

# Lint check
lint:
	verilator --lint-only -Wall $(RTL_SRCS)

.PHONY: all compile simulate wave clean lint
