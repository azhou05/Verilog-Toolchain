#!/bin/bash
# Usage: ./synth_check.sh <tb_module> <verilog_files...> 

TB_MODULE="$1"
shift
# The rest of the arguments are all the verilog files including tb.v
VERILOG_FILES="$@"

echo "Running simulation for $TB_MODULE..."
# Compile all files + testbench
# ADD -I src to tell iverilog where to find included files
iverilog -I src -o sim_out $VERILOG_FILES 
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
    # Don't exit immediately on simulation failure in tb if return code is expected
    # Let run_toolchain.py handle the exit code interpretation
    # exit $SIM_STATUS 
fi

# Exit with the simulation status code (0 for success, non-zero for failure)
exit $SIM_STATUS