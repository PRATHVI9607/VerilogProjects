# Makefile for Branch Predictor

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

RTL_DIR = rtl
TB_DIR = tb

RTL_FILES = $(RTL_DIR)/gshare_predictor.v \
            $(RTL_DIR)/btb.v \
            $(RTL_DIR)/branch_predictor.v

TB_FILE = $(TB_DIR)/tb_branch_predictor.v

SIM_OUT = branch_pred_sim
VCD_FILE = branch_predictor.vcd

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
