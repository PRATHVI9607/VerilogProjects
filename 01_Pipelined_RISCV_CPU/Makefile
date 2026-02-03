# Pipelined RISC-V CPU - Makefile
# Uses program.hex directly - just edit it and run!
# Commands: make check, make sim, make run, make wave, make clean

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

RTL = rtl/riscv_pkg.v rtl/instruction_fetch.v rtl/instruction_decode.v \
      rtl/execute.v rtl/memory_stage.v rtl/writeback.v \
      rtl/forwarding_unit.v rtl/hazard_unit.v rtl/riscv_cpu.v

# ============ MAIN TARGETS ============

# Check for errors and warnings (strict mode)
check:
	@echo "=== Checking for errors and warnings ==="
	@$(IVERILOG) -g2012 -Wall -o .check_tmp -I rtl $(RTL) tb/tb_riscv_cpu.v && \
		echo "✓ No errors or warnings!" && rm -f .check_tmp || \
		(rm -f .check_tmp && exit 1)

# Compile and run simulation (shows cycle-by-cycle pipeline status)
sim:
	@echo "=== Compiling ==="
	$(IVERILOG) -g2012 -o cpu_sim -I rtl $(RTL) tb/tb_riscv_cpu.v
	@echo "=== Running simulation (cycle-by-cycle) ==="
	$(VVP) cpu_sim

# Compile and run (quiet - just shows final results)
run:
	@echo "=== Compiling ==="
	@$(IVERILOG) -g2012 -o cpu_sim -I rtl $(RTL) tb/tb_riscv_cpu.v
	@echo "=== Running simulation ==="
	@$(VVP) cpu_sim 2>&1 | grep -E "(^x[0-9]|PASS|FAIL|ALL TESTS|Testing with|Final|====)"

# View waveforms
wave: sim
	$(GTKWAVE) riscv_cpu.vcd &

# Clean all generated files
clean:
	@rm -f cpu_sim .check_tmp *.vcd
	@echo "✓ Cleaned"

# ============ DIAGRAM ============

# Generate block diagram
diagram:
	@cd synth && yosys -s yosys_diagram.ys

# ============ QUICK COMMANDS ============

# Quick syntax check only (no warnings)
syntax:
	@$(IVERILOG) -g2012 -o /dev/null -I rtl $(RTL) tb/tb_riscv_cpu.v && \
		echo "✓ Syntax OK" || echo "✗ Syntax errors found"

# Show help
help:
	@echo "Available targets:"
	@echo "  make check   - Check for errors & warnings"
	@echo "  make sim     - Compile and run (cycle-by-cycle output)"
	@echo "  make run     - Compile and run (summary output)"
	@echo "  make wave    - Run and open waveforms"
	@echo "  make clean   - Remove generated files"
	@echo "  make syntax  - Quick syntax check"
	@echo "  make diagram - Generate block diagram"
	@echo ""
	@echo "Usage: Edit program.hex with your instructions, then run 'make sim'"

.PHONY: check sim run wave clean diagram syntax help
