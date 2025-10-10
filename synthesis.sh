#!/bin/bash
# Usage: ./synth_check.sh <top_module> <verilog_files...>

TOP_MODULE="$1"
shift
VERILOG_FILES="$@"

echo "Running Yosys synthesis on $TOP_MODULE..."
# Pipe output to terminal AND save to log
yosys -p "read_verilog $VERILOG_FILES; synth -top $TOP_MODULE" 2>&1 | tee yosys_out.log

# Check for errors in log
if grep -q "ERROR:" yosys_out.log; then
    echo "Synthesis failed! Check yosys_out.log above."
    exit 1
else
    echo "Synthesis passed."
fi
