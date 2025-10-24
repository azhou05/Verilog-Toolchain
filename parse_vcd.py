import sys
import re
import json

# --- Helper Functions ---

def print_err(*args, **kwargs):
    """Helper to print debug messages to stderr."""
    print("[parse_vcd.py]", *args, file=sys.stderr, **kwargs)

def find_signal_symbol(lines, signal_name):
    """
    Searches VCD definition lines for a specific signal and returns its symbol.
    """
    print_err(f"Searching for '{signal_name}' symbol definition ($var)...")
    in_definitions_section = True
    for line_num, line in enumerate(lines):
        line_strip = line.strip()
        if not line_strip: continue
        
        if "$enddefinitions" in line_strip:
            in_definitions_section = False
            break # Stop searching after definitions
            
        if in_definitions_section and line_strip.startswith("$var") and signal_name in line_strip:
            parts = line_strip.split()
            # Expecting: $var type width symbol name $end
            if len(parts) >= 5:
                # Check if the signal name is an exact match (handles cases where one name is a substring of another)
                # This splits 'name[bit]' into 'name'
                found_name = parts[4].split('[')[0] 
                if found_name == signal_name:
                    symbol = parts[3]
                    print_err(f"--> Found '{signal_name}' symbol: '{symbol}' on line {line_num+1}")
                    return symbol
                else:
                    print_err(f"--- Found symbol '{parts[3]}' for signal '{parts[4]}' which contains '{signal_name}' but isn't exact match, continuing...")
            else:
                print_err(f"Warning: Skipping malformed VCD $var line {line_num+1}: {line.strip()}")

    raise ValueError(f"Could not find exact '$var ... {signal_name} ...' definition in VCD definitions section.")


def get_clk_period_from_tb(tb_path):
    """
    Parses the testbench file to find the clock period.
    """
    print_err(f"Attempting to parse clock period from: {tb_path}")
    clk_regex = re.compile(r"always\s*#(\d+)\s*clk\s*=\s*~clk", re.IGNORECASE)
    try:
        with open(tb_path, 'r') as f:
            for line_num, line in enumerate(f):
                match = clk_regex.search(line)
                if match:
                    half_period = int(match.group(1))
                    full_period = half_period * 2
                    print_err(f"--> Found 'always #{half_period}' on line {line_num+1}. Clock period: {full_period} ns")
                    return full_period
    except FileNotFoundError:
         raise FileNotFoundError(f"Testbench file not found: {tb_path}")
    except Exception as e:
        raise IOError(f"Error reading testbench file {tb_path}: {e}")

    raise ValueError(f"Could not detect 'always #<n> clk = ~clk;' pattern in {tb_path}")


def parse_load_to_busy_duration(vcd_path):
    """
    Parses the VCD file to find the duration from the first 'load_in' rising edge
    to the last 'busy_out' falling edge.
    """
    print_err(f"Attempting to parse VCD file: {vcd_path}")
    try:
        with open(vcd_path, "r", encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
        print_err(f"--> Read {len(lines)} lines from VCD.")
    except FileNotFoundError:
        raise FileNotFoundError(f"VCD file not found: {vcd_path}")
    except Exception as e:
        raise IOError(f"Error reading VCD file {vcd_path}: {e}")

    # --- Find symbols for both signals ---
    load_symbol = find_signal_symbol(lines, "load_in")
    busy_symbol = find_signal_symbol(lines, "busy_out")

    # --- Parse Timestamps and Value Changes ---
    current_time = 0
    prev_load_val = "x" # Initialize to unknown
    prev_busy_val = "x" # Initialize to unknown
    
    start_time = None # Time in VCD units (e.g., ps)
    end_time = None   # Time in VCD units (e.g., ps)

    time_unit_ps = 1 # Default VCD unit if timescale missing/malformed
    timescale_parsed_successfully = False

    in_definitions = True
    in_dumpvars = False
    first_timestamp_processed = False

    print_err(f"Starting VCD event parsing for 'load_in' ('{load_symbol}') and 'busy_out' ('{busy_symbol}')...")
    
    for line_num, line in enumerate(lines):
        line = line.strip()
        if not line: continue

        # --- Handle Timescale (only in definitions) ---
        if in_definitions and line.startswith("$timescale"):
            parts = line.split()
            if len(parts) >= 2:
                ts_str = parts[1].lower()
                match_num = re.match(r'^(\d+)', ts_str)
                multiplier = 1
                if match_num:
                    try: multiplier = int(match_num.group(1));
                    except ValueError: multiplier = 1
                if multiplier == 0: multiplier = 1
                
                temp_unit_ps = 1 # Default
                if "fs" in ts_str: temp_unit_ps = 0.001
                elif "ps" in ts_str: temp_unit_ps = 1
                elif "ns" in ts_str: temp_unit_ps = 1000
                elif "us" in ts_str: temp_unit_ps = 1000 * 1000
                elif "ms" in ts_str: temp_unit_ps = 1000 * 1000 * 1000
                elif "s" in ts_str: temp_unit_ps = 1000 * 1000 * 1000 * 1000
                else: 
                    print_err(f"Warning: Unknown time unit in $timescale line {line_num+1}: {parts[1]}. Assuming 1 ps base.")
                    multiplier = 1 # Reset multiplier

                time_unit_ps = temp_unit_ps * multiplier
                timescale_parsed_successfully = True
                print_err(f"--> VCD $timescale found: {parts[1]} -> effective unit {time_unit_ps} ps")
            else:
                 print_err(f"Warning: Malformed $timescale line {line_num+1}: {line}")
            continue

        if in_definitions and "$enddefinitions" in line:
             in_definitions = False
             print_err(f"--> End of VCD definitions ($enddefinitions) found at line {line_num+1}.")
             continue
        elif in_definitions:
             continue # Skip lines until end of definitions

        # --- Handle Dumpvars ---
        if line == "$dumpvars": in_dumpvars = True; continue
        if line == "$end" and in_dumpvars:
            in_dumpvars = False
            # Apply initial values if set and no timestamp seen
            if not first_timestamp_processed:
                if prev_load_val == '1' and start_time is None:
                     start_time = 0
                     print_err(f"--> Applying initial high value for 'load_in' from $dumpvars. Setting start_time = 0")
                if prev_busy_val == '1' and start_time is not None and end_time is None:
                     print_err(f"--> 'busy_out' starts high in $dumpvars.")
            continue

        # --- Handle Timestamps ---
        if line.startswith("#"):
            try:
                current_time = int(line[1:])
                if not first_timestamp_processed:
                    first_timestamp_processed = True
            except ValueError:
                 print_err(f"Warning: Malformed timestamp line {line_num+1}: {line}")
                 continue
            continue

        # --- Handle Value Changes (Strict Matching) ---
        if in_dumpvars or first_timestamp_processed:
            symbol_being_checked = None
            if line.endswith(load_symbol): symbol_being_checked = load_symbol
            elif line.endswith(busy_symbol): symbol_being_checked = busy_symbol
            else: continue # Not a signal we care about
            
            val = 'x' # Default
            # Check for exact single-char value match: e.g., 1"
            if len(line) == (len(symbol_being_checked) + 1):
                val_char = line[0]
                if val_char in '01xzXZ':
                    val = val_char
            # Check for binary value match: e.g., b0 "
            elif line.startswith('b') and line.endswith(symbol_being_checked):
                 val_part = line[1:-len(symbol_being_checked)].strip()
                 if len(val_part) == 1 and val_part in '01xzXZ':
                     val = val_part
            else:
                continue # Malformed or multi-bit vector, skip

            # --- Logic for load_in ---
            if symbol_being_checked == load_symbol and val in {'0', '1'} and val != prev_load_val:
                print_err(f"--> Value change for 'load_in' ('{load_symbol}'): '{prev_load_val}' -> '{val}' at time {current_time}")
                # Detect *first* rising edge (0->1 or x->1)
                if (prev_load_val == '0' or prev_load_val == 'x') and val == '1':
                    if start_time is None: # Only capture the *first* time
                        start_time = current_time
                        print_err(f"----> RISING EDGE DETECTED for 'load_in': Setting start_time = {start_time}")
                prev_load_val = val # Update state
            
            # --- Logic for busy_out ---
            elif symbol_being_checked == busy_symbol and val in {'0', '1'} and val != prev_busy_val:
                print_err(f"--> Value change for 'busy_out' ('{busy_symbol}'): '{prev_busy_val}' -> '{val}' at time {current_time}")
                # Detect falling edge (1->0)
                if prev_busy_val == '1' and val == '0':
                    if start_time is not None: # Only record end time if we have started
                        end_time = current_time # This will track the *last* falling edge
                        print_err(f"----> FALLING EDGE DETECTED for 'busy_out': Setting potential end_time = {end_time}")
                    else:
                        print_err(f"----> Ignoring 'busy_out' falling edge, 'load_in' hasn't started yet.")
                prev_busy_val = val # Update state

    # --- Final Checks ---
    print_err("Finished parsing VCD lines.")
    if not timescale_parsed_successfully:
        print_err(f"Warning: Failed to parse $timescale. Using default unit: {time_unit_ps} ps.")

    # If busy_out ended while high, the end_time is the last recorded time
    if start_time is not None and (end_time is None or end_time < start_time) and prev_busy_val == '1':
         end_time = current_time
         print_err(f"--> 'busy_out' ended high. Setting end_time to last timestamp: {end_time} (raw VCD units)")

    # --- Error Checking and Conversion ---
    if start_time is None:
        raise ValueError("Could not detect start of 'load_in' high signal (rising edge). Check VCD/simulation.")

    if end_time is None:
        if prev_busy_val == '1' and start_time is not None:
             end_time = current_time 
             print_err(f"Warning: 'load_in' went high but 'busy_out' never went low. Using last timestamp {end_time} as end time.")
        else:
             raise ValueError("Could not detect end of 'busy_out' high signal (no falling edge found after 'load_in' started).")

    if end_time < start_time:
         raise ValueError(f"Detected end time ({end_time}) is earlier than start time ({start_time}) in VCD units.")

    # Convert from VCD units (e.g., ps) to 'ns'
    start_time_ns = start_time * time_unit_ps / 1000.0
    end_time_ns = end_time * time_unit_ps / 1000.0
    duration_ns = (end_time - start_time) * time_unit_ps / 1000.0

    print_err(f"--> Calculated Times (ns): Start={start_time_ns:.3f}, End={end_time_ns:.3f}, Duration={duration_ns:.3f}")

    if duration_ns < 0:
        raise ValueError(f"Calculated negative duration ({duration_ns:.3f} ns). Start: {start_time_ns:.3f} ns, End: {end_time_ns:.3f} ns.")

    return start_time_ns, end_time_ns, duration_ns


# --- Main Execution ---
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print_err("Usage: python3 parse_vcd.py <vcd_file> <tb_file>")
        print(json.dumps({"analysis_status": "error", "error_message": "Incorrect script arguments."}, indent=4))
        sys.exit(1)

    vcd_file = sys.argv[1]
    tb_file = sys.argv[2]

    results = {}

    try:
        clk_period_ns = get_clk_period_from_tb(tb_file)
        results['clk_period_ns'] = clk_period_ns

        # Call the renamed function
        start, end, duration = parse_load_to_busy_duration(vcd_file)
        results['start_time_ns'] = start
        results['end_time_ns'] = end
        results['duration_ns'] = duration

        if clk_period_ns <= 0:
             raise ValueError("Clock period must be positive.")
        cycles = duration / clk_period_ns
        results['total_clock_cycles'] = cycles 

        results['analysis_status'] = 'success'
        print_err("--> VCD analysis successful.")

    except Exception as e:
        print_err(f"ERROR during analysis: {type(e).__name__}: {e}")
        results['analysis_status'] = 'error'
        results['error_message'] = f"{type(e).__name__}: {e}"
        if 'clk_period_ns' not in results and 'clk_period_ns' in locals():
             results['clk_period_ns'] = clk_period_ns

    # Output Final JSON
    print(json.dumps(results, indent=4))
    sys.exit(0 if results.get('analysis_status') == 'success' else 1)