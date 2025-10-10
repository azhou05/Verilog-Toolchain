#!/bin/bash
# Usage: ./run_all.sh <tb_module>

TB_MODULE="$1"
if [ -z "$TB_MODULE" ]; then
    echo "Usage: ./run_all.sh <tb_module>"
    exit 1
fi

echo "=== Running full toolchain for $TB_MODULE ==="

# Step 0: Detect files (all .v except tb.v)
FILES=$(ls src/*.v | grep -v tb.v)
echo "Synthesis files: $FILES"

continue_run = True;

# Step 1: Synthesis check (all files + testbench)
SIM_FILES="$FILES src/tb.v"
if ! ./synth_check.sh $TB_MODULE $SIM_FILES; then
    echo "Simulation failed! Aborting."
    exit 1
fi

# Step 2: Synthesis
if ! ./synthesis.sh aes $FILES; then
    echo "Synthesis failed! Aborting."
    exit 1
fi

# Step 3: Python VCD analysis
if [ -f dump.vcd ]; then
    echo "Running cycle analysis..."
    python3 parse_vcd.py dump.vcd src/tb.v
else
    echo "Missing dump.vcd! Skipping analysis."
fi
