# Makefile for Superscalar Dual-Issue CPU

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

RTL_DIR = rtl
TB_DIR = tb

RTL_FILES = $(RTL_DIR)/register_rename.v \
            $(RTL_DIR)/dual_fetch.v \
            $(RTL_DIR)/dual_decode.v \
            $(RTL_DIR)/dual_alu.v \
            $(RTL_DIR)/superscalar_cpu.v

TB_FILE = $(TB_DIR)/tb_superscalar_cpu.v

SIM_OUT = superscalar_sim
VCD_FILE = superscalar.vcd

all: sim

compile:
	$(IVERILOG) -g2012 -o $(SIM_OUT) $(RTL_FILES) $(TB_FILE)

sim: compile
	$(VVP) $(SIM_OUT)

wave: sim
	$(GTKWAVE) $(VCD_FILE) &

clean:
	rm -f $(SIM_OUT) $(VCD_FILE)

.PHONY: all compile sim wave clean
