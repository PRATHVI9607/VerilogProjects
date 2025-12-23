# Makefile for Cache Memory System

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

RTL_DIR = rtl
TB_DIR = tb

RTL_FILES = $(RTL_DIR)/cache_pkg.v \
            $(RTL_DIR)/direct_mapped_cache.v \
            $(RTL_DIR)/set_associative_cache.v \
            $(RTL_DIR)/main_memory.v

TB_FILE = $(TB_DIR)/tb_cache_system.v

SIM_OUT = cache_sim
VCD_FILE = cache_system.vcd

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
