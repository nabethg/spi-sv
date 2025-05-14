# Project Params
TB := tb_spi_drv
WAVE_DIR := waves
VCD_PATH := $(WAVE_DIR)/spi_wave.vcd

# Source locations
RTL_SRC := $(wildcard rtl/*.sv)
TB_SRC  := $(wildcard tb/*.sv)

# ModelSim commands
VSIM   := vsim
VLOG   := vlog -sv
VLIB   := vlib

# Default target
.PHONY: all
all: sim

.PHONY: build
build:
	@echo "Compiling sources..."
	$(VLIB) work 2>/dev/null || true
	$(VLOG) $(RTL_SRC) $(TB_SRC)

# Helper to ensure waveform dir exists
$(WAVE_DIR):
	mkdir -p $(WAVE_DIR)

.PHONY: sim
sim: build | $(WAVE_DIR)
	@echo "Running simulation; generating $(VCD_PATH)..."
	$(VSIM) -c $(TB) \
	        -do "vcd file $(VCD_PATH); vcd add -r /*; run -all; quit" 

.PHONY: view
view: $(VCD_PATH)
	@echo "Launching GUI to view waveform $(VCD_PATH)..."
	gtkwave $(VCD_PATH)

.PHONY: clean
clean:
	@echo "Cleaning up build artifacts..."
	rm -rf work $(WAVE_DIR) transcript
