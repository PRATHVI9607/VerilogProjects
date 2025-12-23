# Interrupt-Enabled Pipeline Makefile

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Directories
RTL_DIR = rtl
TB_DIR = tb

# Source files
RTL_SRCS = $(RTL_DIR)/interrupt_controller.v \
           $(RTL_DIR)/exception_handler.v \
           $(RTL_DIR)/pipeline_flush_ctrl.v \
           $(RTL_DIR)/interrupt_pipeline.v

TB_SRCS = $(TB_DIR)/tb_interrupt_pipeline.v

# Output files
SIM_OUT = interrupt_pipeline_sim
VCD_FILE = interrupt_pipeline_tb.vcd

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
