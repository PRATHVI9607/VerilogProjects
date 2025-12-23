# Makefile for Tomasulo Algorithm Processor

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

RTL_DIR = rtl
TB_DIR = tb

RTL_FILES = $(RTL_DIR)/tomasulo_pkg.v \
            $(RTL_DIR)/tomasulo_rs.v \
            $(RTL_DIR)/fp_adder.v \
            $(RTL_DIR)/fp_multiplier.v \
            $(RTL_DIR)/register_status.v \
            $(RTL_DIR)/common_data_bus.v \
            $(RTL_DIR)/tomasulo_processor.v

TB_FILE = $(TB_DIR)/tb_tomasulo.v

SIM_OUT = tomasulo_sim
VCD_FILE = tomasulo.vcd

all: sim

compile:
	$(IVERILOG) -g2012 -o $(SIM_OUT) -I $(RTL_DIR) $(RTL_FILES) $(TB_FILE)

sim: compile
	$(VVP) $(SIM_OUT)

wave: sim
	$(GTKWAVE) $(VCD_FILE) &

clean:
	rm -f $(SIM_OUT) $(VCD_FILE)

.PHONY: all compile sim wave clean
