#!/bin/bash
# Usage: ./simulate.sh <tb_module> <verilog_files...> <tb_file>

TB_MODULE="$1"
shift
DUT_FILES="$@"

echo "Running simulation for $TB_MODULE..."
# Compile all DUT files + testbench
iverilog -o sim_out $DUT_FILES
SIM_STATUS=$?
if [ $SIM_STATUS -ne 0 ]; then
    echo "Compilation failed!"
    exit $SIM_STATUS
fi

# Run simulation and pipe output to terminal + log
vvp sim_out 2>&1 | tee sim.log
SIM_STATUS=${PIPESTATUS[0]}
if [ $SIM_STATUS -ne 0 ]; then
    echo "Simulation failed! See sim.log above."
    exit $SIM_STATUS
fi
