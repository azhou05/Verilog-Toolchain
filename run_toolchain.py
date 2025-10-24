#!/usr/bin/env python3
import subprocess
import json
import sys
import os
import glob

def print_err(*args, **kwargs):
    """Helper to print status messages to stderr."""
    print("[run_toolchain.py]", *args, file=sys.stderr, **kwargs)

def run_step(command, log_file, step_name):
    """
    Runs a shell command, captures output, and reads its log file.
    (This function remains the same)
    """
    print_err(f"--- Starting: {step_name} ---") # Use print_err for status
    step_result = {}

    try:
        # Run the command, capture stdout and stderr
        proc = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=300)

        step_result['return_code'] = proc.returncode
        step_result['status'] = 'success' if proc.returncode == 0 else 'error'

        # Attempt to read the primary log file first
        log_content = None
        if os.path.exists(log_file):
            try:
                with open(log_file, 'r') as f:
                    log_content = f.read()
            except Exception as e:
                 log_content = f"Error reading log file '{log_file}': {e}"

        # Combine log content (if any) with captured output
        # Prioritize log file content if it exists
        combined_log = ""
        if log_content is not None:
             combined_log += f"--- Log File ({log_file}) ---\n{log_content}\n\n"
        if proc.stdout:
             combined_log += f"--- Captured STDOUT ---\n{proc.stdout}\n\n"
        if proc.stderr:
             combined_log += f"--- Captured STDERR ---\n{proc.stderr}\n"

        step_result['log'] = combined_log.strip()


        if proc.returncode != 0:
             print_err(f"*** ERROR in {step_name}. See combined log in JSON. ***")
             # Optionally print stderr directly for immediate feedback on errors
             if proc.stderr:
                  print_err(f"*** {step_name} STDERR START ***\n{proc.stderr.strip()}\n*** {step_name} STDERR END ***")

    except subprocess.TimeoutExpired:
        print_err(f"*** TIMEOUT ERROR running {step_name} (exceeded 300 seconds) ***")
        step_result['status'] = 'error'
        step_result['return_code'] = -1
        step_result['log'] = f"Timeout Error: Command '{command}' exceeded 300 seconds."
    except Exception as e:
        print_err(f"*** CRITICAL ERROR running {step_name}: {type(e).__name__}: {e} ***")
        step_result['status'] = 'error'
        step_result['return_code'] = -1
        step_result['log'] = f"Critical Error: {type(e).__name__}: {e}"

    print_err(f"--- Finished: {step_name} (Status: {step_result['status']}) ---\n") # Use print_err
    return step_result


def main():
    if len(sys.argv) < 2:
        print_err("Usage: ./run_toolchain.py <tb_module_name>") # Use print_err
        print_err("Example: ./run_toolchain.py aes_tb")      # Use print_err
        sys.exit(1)

    tb_module = sys.argv[1]
    design_top_module = "aes"

    output_data = {} # This dictionary will hold all our results

    # --- Step 0: Detect files ---
    print_err(f"=== Running full toolchain for {tb_module} ===") # Use print_err
    try:
        all_verilog_files = glob.glob("src/*.v")
        tb_file = next((f for f in all_verilog_files if 'tb.v' in os.path.basename(f)), None)
        if not tb_file:
             print_err("Error: Could not find 'tb.v' in src/ directory.") # Use print_err
             sys.exit(1)

        dut_files_list = [f for f in all_verilog_files if f != tb_file]
        sim_files_list = dut_files_list + [tb_file]
        dut_files_str = " ".join(dut_files_list)
        sim_files_str = " ".join(sim_files_list)

        output_data['files'] = {
            'design_files': dut_files_list,
            'testbench_file': tb_file,
            'all_simulation_files': sim_files_list
        }
        print_err("--> Found Verilog files:") # Use print_err
        print_err(f"    Design: {dut_files_list}") # Use print_err
        print_err(f"    Testbench: {tb_file}") # Use print_err

    except Exception as e:
        print_err(f"Error finding Verilog files: {e}") # Use print_err
        sys.exit(1)

    # --- Step 1: Simulation (using simulate.sh or simulate.sh) ---
    # Determine which script runs simulation based on previous context
    # Assuming simulate.sh is the correct one now.
    sim_script = "./simulate.sh" # CHANGE THIS if simulate.sh runs simulation
    sim_log_file = "sim.log"
    sim_command = f"{sim_script} {tb_module} {tb_file}"
    output_data['simulation'] = run_step(sim_command, sim_log_file, "Simulation (iverilog)")

    if output_data['simulation']['status'] == 'error':
        print_err("Simulation failed. Aborting.") # Use print_err
        write_json_output(output_data)
        sys.exit(1)

    # --- Step 2: Synthesis (using synthesis.sh or simulate.sh) ---
    # Determine which script runs synthesis
    # Assuming synthesis.sh is the correct one now.
    synth_script = "./synthesis.sh" # CHANGE THIS if simulate.sh runs synthesis
    synth_log_file = "yosys_out.log"
    synth_command = f"{synth_script} {design_top_module} {dut_files_str}"
    output_data['synthesis'] = run_step(synth_command, synth_log_file, "Synthesis (Yosys)")

    if output_data['synthesis']['status'] == 'error':
        print_err("Synthesis failed. Aborting.") # Use print_err
        write_json_output(output_data)
        sys.exit(1)

    # --- Step 3: VCD Analysis (using parse_vcd.py) ---
    print_err("--- Starting: VCD Analysis ---") # Use print_err
    vcd_file = "top.vcd"
    output_data['vcd_analysis'] = {}
    analysis_stderr_log = "" # Variable to store stderr

    if os.path.exists(vcd_file):
        analysis_command = f"python3 parse_vcd.py {vcd_file} {tb_file}"
        try:
            # Run parse_vcd.py and CAPTURE BOTH stdout and stderr
            proc = subprocess.run(
                analysis_command,
                shell=True,
                capture_output=True, # CAPTURE BOTH
                text=True,
                timeout=60
            )

            # Store stderr regardless of success or failure
            if proc.stderr:
                 analysis_stderr_log = proc.stderr.strip()
                 # Optionally print stderr immediately for debugging
                 # print_err(f"*** VCD Analysis STDERR START ***\n{analysis_stderr_log}\n*** VCD Analysis STDERR END ***")

            # Try to parse JSON from stdout
            if proc.stdout:
                try:
                    analysis_json = json.loads(proc.stdout)
                    output_data['vcd_analysis'] = analysis_json # Store parsed JSON data
                    # Add stderr log to the JSON structure
                    output_data['vcd_analysis']['debug_log'] = analysis_stderr_log

                    # Check if the script reported success but exited non-zero (or vice-versa)
                    script_exit_status = 'success' if proc.returncode == 0 else 'error'
                    json_status = analysis_json.get('analysis_status', 'error') # Default to error if key missing

                    if script_exit_status != json_status:
                         print_err(f"Warning: parse_vcd.py exit code ({proc.returncode}) status '{script_exit_status}' "
                                   f"does not match JSON status '{json_status}'. Using JSON status.")
                         # Keep the status reported *inside* the JSON as the primary indicator
                         # If JSON status is success, but exit code wasn't 0, it will still be marked success here.

                except json.JSONDecodeError:
                    print_err("Error: Failed to parse JSON output from parse_vcd.py.") # Use print_err
                    output_data['vcd_analysis']['analysis_status'] = 'error'
                    output_data['vcd_analysis']['error_message'] = "Failed to parse JSON output from parse_vcd.py"
                    output_data['vcd_analysis']['raw_stdout'] = proc.stdout # Store raw output
                    output_data['vcd_analysis']['debug_log'] = analysis_stderr_log # Still store stderr

            # Handle cases where stdout was empty
            elif proc.returncode == 0:
                 # Script succeeded but printed nothing to stdout
                 print_err("Warning: parse_vcd.py succeeded but produced no JSON output.") # Use print_err
                 output_data['vcd_analysis']['analysis_status'] = 'error'
                 output_data['vcd_analysis']['error_message'] = "Script produced no JSON output."
                 output_data['vcd_analysis']['debug_log'] = analysis_stderr_log
            else:
                 # Script failed and printed nothing to stdout
                 print_err(f"Error: parse_vcd.py failed with return code {proc.returncode} and no JSON output.") # Use print_err
                 output_data['vcd_analysis']['analysis_status'] = 'error'
                 output_data['vcd_analysis']['error_message'] = f"Script failed with return code {proc.returncode}, no JSON."
                 output_data['vcd_analysis']['debug_log'] = analysis_stderr_log


        except subprocess.TimeoutExpired:
             print_err(f"*** TIMEOUT ERROR running VCD Analysis (exceeded 60 seconds) ***") # Use print_err
             output_data['vcd_analysis']['analysis_status'] = 'error'
             output_data['vcd_analysis']['error_message'] = f"Timeout Error: VCD Analysis exceeded 60 seconds."
             # stderr log might be empty in this case
             output_data['vcd_analysis']['debug_log'] = analysis_stderr_log
        except Exception as e:
            # Catches other errors during subprocess execution itself
            print_err(f"*** CRITICAL ERROR running VCD Analysis: {type(e).__name__}: {e} ***") # Use print_err
            output_data['vcd_analysis']['analysis_status'] = 'error'
            output_data['vcd_analysis']['error_message'] = f"Subprocess execution failed: {type(e).__name__}: {e}"
            output_data['vcd_analysis']['debug_log'] = analysis_stderr_log


    else:
        print_err(f"Missing {vcd_file}! Skipping analysis.") # Use print_err
        output_data['vcd_analysis']['analysis_status'] = 'skipped'
        output_data['vcd_analysis']['error_message'] = f"'{vcd_file}' not found."
        output_data['vcd_analysis']['debug_log'] = "" # No stderr if file missing

    print_err(f"--- Finished: VCD Analysis (Status: {output_data.get('vcd_analysis', {}).get('analysis_status', 'error')}) ---\n") # Use print_err

    # --- Final Step: Write JSON ---
    write_json_output(output_data)

def write_json_output(data):
    output_filename = "toolchain_results.json"
    try:
        with open(output_filename, 'w') as f:
            json.dump(data, f, indent=4)
        print_err(f"=== Toolchain finished. All results written to {output_filename} ===") # Use print_err
    except Exception as e:
        print_err(f"*** ERROR: Failed to write JSON output to {output_filename}: {e} ***") # Use print_err

if __name__ == "__main__":
    main()