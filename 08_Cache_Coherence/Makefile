# Cache Coherence System Makefile

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Directories
RTL_DIR = rtl
TB_DIR = tb

# Source files
RTL_SRCS = $(RTL_DIR)/mesi_cache_line.v \
           $(RTL_DIR)/mesi_cache.v \
           $(RTL_DIR)/snoop_bus.v \
           $(RTL_DIR)/coherent_cache_system.v

TB_SRCS = $(TB_DIR)/tb_cache_coherence.v

# Output files
SIM_OUT = cache_coherence_sim
VCD_FILE = cache_coherence_tb.vcd

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
