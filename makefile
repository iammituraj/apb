#==================================================================================
# File         : Makefile to compile, simulate Verilog modules
# Developer    : Mitu Raj
# Date         : July-2024
# Dependencies : All source files & VCD & sim directory should be in the same dir
#                Tools reqd = iverilog + gtkwave
#==================================================================================
.ONESHELL:

# DIR paths
SIM_DIR = $(shell pwd)/sim

# Default
VVP = test_apb

# Compile
compile:
	@mkdir -p $(SIM_DIR)
	@echo "| INFO: Compiling all source files..."
	iverilog -g2012 -o $(SIM_DIR)/$(VVP).vvp *.sv

# Simulate
sim:
	@echo "| INFO: Launching simulation..."
	vvp $(SIM_DIR)/$(VVP).vvp
	@mv *.vcd $(SIM_DIR)

# Run
runall: compile sim

# Clean
clean:
	@rm -rf $(SIM_DIR)/*
	@rm -rf *.vcd
	echo "| INFO: Cleaned sim directory!"

# Full clean
full_clean: clean
	@rm -rf $(SIM_DIR)
	echo "| INFO: Wiped off all!"

.PHONY: compile sim runall clean full_clean

