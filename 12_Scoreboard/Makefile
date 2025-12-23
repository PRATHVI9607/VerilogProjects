# Makefile for Scoreboard Project
# CDC 6600 Style Scoreboard Mechanism

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Directories
RTL_DIR = rtl
TB_DIR = tb

# Source files
RTL_SRCS = \
    $(RTL_DIR)/functional_unit.v \
    $(RTL_DIR)/register_file.v \
    $(RTL_DIR)/fu_status.v \
    $(RTL_DIR)/scoreboard_issue.v \
    $(RTL_DIR)/scoreboard.v

TB_SRCS = $(TB_DIR)/tb_scoreboard.v

# Output files
TB_OUT = scoreboard_tb.vvp
VCD_FILE = scoreboard.vcd

# Flags
IVERILOG_FLAGS = -g2012 -Wall

# Default target
all: sim

# Compile testbench
compile: $(RTL_SRCS) $(TB_SRCS)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(TB_OUT) $(TB_SRCS) $(RTL_SRCS)

# Run simulation
sim: compile
	$(VVP) $(TB_OUT)

# View waveforms
wave: sim
	$(GTKWAVE) $(VCD_FILE) &

# Run specific test
test: compile
	$(VVP) $(TB_OUT) +test=$(TEST)

# Lint check
lint: $(RTL_SRCS)
	$(IVERILOG) $(IVERILOG_FLAGS) -tnull $(RTL_SRCS)

# Clean
clean:
	rm -f $(TB_OUT) $(VCD_FILE)
	rm -f *.vvp *.vcd

# Help
help:
	@echo "Scoreboard Makefile Targets:"
	@echo "  all     - Compile and run simulation (default)"
	@echo "  compile - Compile Verilog sources"
	@echo "  sim     - Run simulation"
	@echo "  wave    - View waveforms in GTKWave"
	@echo "  lint    - Check for syntax errors"
	@echo "  clean   - Remove generated files"
	@echo "  help    - Show this help"

.PHONY: all compile sim wave test lint clean help
