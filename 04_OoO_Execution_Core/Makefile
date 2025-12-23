# Makefile for Out-of-Order Execution Core

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

RTL_DIR = rtl
TB_DIR = tb

RTL_FILES = $(RTL_DIR)/ooo_pkg.v \
            $(RTL_DIR)/reservation_station.v \
            $(RTL_DIR)/reorder_buffer.v \
            $(RTL_DIR)/alu_unit.v \
            $(RTL_DIR)/cdb_arbiter.v \
            $(RTL_DIR)/ooo_core.v

TB_FILE = $(TB_DIR)/tb_ooo_core.v

SIM_OUT = ooo_sim
VCD_FILE = ooo_core.vcd

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
