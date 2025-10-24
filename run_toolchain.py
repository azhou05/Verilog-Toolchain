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

import re # Make sure 'import re' is at the top of the file

def check_simulation_accuracy(log_content):
    """
    Parses the simulation log to find the hex output and check it.
    """
    print_err("--- Starting: Accuracy Check ---")
    
    # This is the "golden" output your tb.v currently produces when correct.
    # We will check against this.
    GOLDEN_CIPHERTEXT = "2dc1e9df9d4089be86138b9221fb3391"
    
    result = {
        "status": "error", # Default to error
        "expected_output": GOLDEN_CIPHERTEXT,
        "found_output": "",
        "message": ""
    }
    
    # Regex to find a 32-character hexadecimal string
    # This matches the '2dc1e9df9d4089be86138b9221fb3391' output
    match = re.search(r'([0-9a-fA-F]{32})', log_content)
    
    if not match:
        result['message'] = "Could not find 32-character hex output string in sim.log."
        print_err(f"*** ERROR: {result['message']} ***")
    else:
        found_hex = match.group(1)
        result['found_output'] = found_hex
        
        if found_hex.lower() == GOLDEN_CIPHERTEXT.lower():
            result['status'] = "success"
            result['message'] = "Simulation output matches golden vector."
            print_err("--> Accuracy Check PASSED.")
        else:
            result['message'] = "Simulation output MISMATCH."
            print_err(f"*** ERROR: {result['message']} ***")
            print_err(f"    Expected: {GOLDEN_CIPHERTEXT}")
            print_err(f"    Found:    {found_hex}")

    print_err(f"--- Finished: Accuracy Check (Status: {result['status']}) ---\n")
    return result


def main():
    if len(sys.argv) < 2:
        print_err("Usage: ./run_toolchain.py <tb_module_name>")
        print_err("Example: ./run_toolchain.py aes_tb")
        sys.exit(1)
        
    tb_module = sys.argv[1]
    design_top_module = "aes" 
    
    output_data = {} 

    # --- Step 0: Detect files ---
    # (This part is unchanged)
    print_err(f"=== Running full toolchain for {tb_module} ===")
    try:
        all_verilog_files = glob.glob("src/*.v")
        tb_file = next((f for f in all_verilog_files if 'tb.v' in os.path.basename(f)), None)
        if not tb_file:
             print_err("Error: Could not find 'tb.v' in src/ directory.")
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
        print_err("--> Found Verilog files:")
        print_err(f"    Design: {dut_files_list}")
        print_err(f"    Testbench: {tb_file}")

    except Exception as e:
        print_err(f"Error finding Verilog files: {e}")
        sys.exit(1)

    # --- Step 1: Simulation (using simulate.sh) ---
    sim_script = "./simulate.sh"
    sim_log_file = "sim.log"
    sim_command = f"{sim_script} {tb_module} {tb_file}" # Pass ONLY the testbench
    output_data['simulation'] = run_step(sim_command, sim_log_file, "Simulation (iverilog)")
    
    if output_data['simulation']['status'] == 'error':
        print_err("Simulation failed. Aborting.")
        write_json_output(output_data)
        sys.exit(1)

    # --- NEW STEP 2: Check Accuracy ---
    output_data['accuracy_check'] = check_simulation_accuracy(output_data['simulation']['log'])
    
    if output_data['accuracy_check']['status'] == 'error':
        print_err("Accuracy check failed. Aborting.")
        write_json_output(output_data)
        sys.exit(1) # Abort if output is wrong

    # --- Renumbered Step 3: Synthesis (using synthesis.sh) ---
    synth_script = "./synthesis.sh"
    synth_log_file = "yosys_out.log"
    synth_command = f"{synth_script} {design_top_module} {dut_files_str}"
    output_data['synthesis'] = run_step(synth_command, synth_log_file, "Synthesis (Yosys)")
    
    if output_data['synthesis']['status'] == 'error':
        print_err("Synthesis failed. Aborting.")
        write_json_output(output_data)
        sys.exit(1)

    # --- Renumbered Step 4: VCD Analysis (using parse_vcd.py) ---
    print_err("--- Starting: VCD Analysis ---")
    vcd_file = "top.vcd" # Make sure this matches your tb.v $dumpfile
    output_data['vcd_analysis'] = {}
    analysis_stderr_log = "" 
    
    if os.path.exists(vcd_file):
        analysis_command = f"python3 parse_vcd.py {vcd_file} {tb_file}"
        try:
            # (The rest of the VCD analysis step remains unchanged)
            proc = subprocess.run(
                analysis_command,
                shell=True,
                capture_output=True, 
                text=True,
                timeout=60
            )
            
            if proc.stderr:
                 analysis_stderr_log = proc.stderr.strip()

            if proc.stdout:
                try:
                    analysis_json = json.loads(proc.stdout)
                    output_data['vcd_analysis'] = analysis_json 
                    output_data['vcd_analysis']['debug_log'] = analysis_stderr_log
                    
                    script_exit_status = 'success' if proc.returncode == 0 else 'error'
                    json_status = analysis_json.get('analysis_status', 'error')

                    if script_exit_status != json_status:
                         print_err(f"Warning: parse_vcd.py exit code ({proc.returncode}) status '{script_exit_status}' "
                                   f"does not match JSON status '{json_status}'. Using JSON status.")

                except json.JSONDecodeError:
                    print_err("Error: Failed to parse JSON output from parse_vcd.py.")
                    output_data['vcd_analysis']['analysis_status'] = 'error'
                    output_data['vcd_analysis']['error_message'] = "Failed to parse JSON output from parse_vcd.py"
                    output_data['vcd_analysis']['raw_stdout'] = proc.stdout
                    output_data['vcd_analysis']['debug_log'] = analysis_stderr_log
            
            elif proc.returncode != 0:
                 print_err(f"Error: parse_vcd.py failed with return code {proc.returncode} and no JSON output.")
                 output_data['vcd_analysis']['analysis_status'] = 'error'
                 output_data['vcd_analysis']['error_message'] = f"Script failed with return code {proc.returncode}, no JSON."
                 output_data['vcd_analysis']['debug_log'] = analysis_stderr_log
            
            else:
                 print_err("Warning: parse_vcd.py succeeded but produced no JSON output.")
                 output_data['vcd_analysis']['analysis_status'] = 'error'
                 output_data['vcd_analysis']['error_message'] = "Script produced no JSON output."
                 output_data['vcd_analysis']['debug_log'] = analysis_stderr_log

        except subprocess.TimeoutExpired:
             print_err(f"*** TIMEOUT ERROR running VCD Analysis (exceeded 60 seconds) ***")
             output_data['vcd_analysis']['analysis_status'] = 'error'
             output_data['vcd_analysis']['error_message'] = f"Timeout Error: VCD Analysis exceeded 60 seconds."
             output_data['vcd_analysis']['debug_log'] = analysis_stderr_log
        except Exception as e:
            print_err(f"*** CRITICAL ERROR running VCD Analysis: {type(e).__name__}: {e} ***")
            output_data['vcd_analysis']['analysis_status'] = 'error'
            output_data['vcd_analysis']['error_message'] = f"Subprocess execution failed: {type(e).__name__}: {e}"
            output_data['vcd_analysis']['debug_log'] = analysis_stderr_log

    else:
        print_err(f"Missing {vcd_file}! Skipping analysis.")
        output_data['vcd_analysis']['analysis_status'] = 'skipped'
        output_data['vcd_analysis']['error_message'] = f"'{vcd_file}' not found."
        output_data['vcd_analysis']['debug_log'] = ""

    print_err(f"--- Finished: VCD Analysis (Status: {output_data.get('vcd_analysis', {}).get('analysis_status', 'error')}) ---\n")
    
    # --- Final Step: Write JSON ---
    write_json_output(output_data)

# (The write_json_output function remains the same)

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