#!/bin/bash
# Usage: ./run_all.sh <tb_module>

TB_MODULE="$1"
if [ -z "$TB_MODULE" ]; then
    echo "Usage: ./run_all.sh <tb_module>"
    exit 1
fi

echo "=== Running full toolchain for $TB_MODULE ==="

# Step 0: Detect files (all .v except tb.v)
DUT_FILES=$(ls src/*.v | grep -v tb.v)
echo "Synthesis files: $DUT_FILES"

# Step 1: Synthesis
./synth_check.sh aes $DUT_FILES

# Step 2: Simulation (all files + testbench)
SIM_FILES="$DUT_FILES src/tb.v"
./simulate.sh $TB_MODULE $SIM_FILES

# Step 3: Python VCD analysis
if [ -f dump.vcd ]; then
    echo "Running cycle analysis..."
    python3 parse_vcd.py dump.vcd src/tb.v
else
    echo "Missing dump.vcd! Skipping analysis."
fi
