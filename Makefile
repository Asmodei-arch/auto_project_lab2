IVERILOG := iverilog
VVP := vvp
GTKWAVE := gtkwave

TOP := APB_top_tb

BUILD_DIR := build
SIM_FILE := $(BUILD_DIR)/sim.vvp

SV_SOURCES := $(wildcard *.sv)

.PHONY: all sim wave clean

all: sim

$(SIM_FILE): $(SV_SOURCES)
	mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s $(TOP) -o $(SIM_FILE) $(SV_SOURCES)

sim: $(SIM_FILE)
	$(VVP) $(SIM_FILE)

wave: sim
	$(GTKWAVE) wave.vcd

clean:
	rm -rf $(BUILD_DIR) wave.vcd
