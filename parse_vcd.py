def parse_busy_out_duration(vcd_path):
    with open(vcd_path, "r") as f:
        lines = f.readlines()

    # find the symbol for 'busy_out'
    busy_symbol = None
    for line in lines:
        if "$var" in line and "busy_out" in line:
            parts = line.split()
            busy_symbol = parts[3]
            print(f"Detected 'busy_out' symbol: {busy_symbol}")
            break

    if not busy_symbol:
        raise ValueError("Could not find 'busy_out' signal in VCD file.")

    current_time = 0
    prev_val = "0"  # assume idle initially
    start_time = None
    end_time = None

    in_dumpvars = False
    for line in lines:
        line = line.strip()
        if line == "$dumpvars":
            in_dumpvars = True
            continue
        if line == "$end" and in_dumpvars:
            in_dumpvars = False
            continue
        if line.startswith("#"):
            current_time = int(line[1:])
        elif line.endswith(busy_symbol):
            val = line[0]
            if val not in {'0', '1'}:
                continue
            # First rising edge marks start
            if prev_val == "0" and val == "1" and start_time is None:
                start_time = current_time
            # Every falling edge updates end_time; final one is last falling edge
            if prev_val == "1" and val == "0" and start_time is not None:
                end_time = current_time
            prev_val = val

    if start_time is None or end_time is None:
        raise ValueError("Could not detect start or end of encryption.")

    duration = end_time - start_time
    return start_time, end_time, duration


# Example usage
if __name__ == "__main__":
    import sys
    vcd_file = "./top.vcd"  # default
    if len(sys.argv) > 1:
        vcd_file = sys.argv[1]
    start, end, duration = parse_busy_out_duration(vcd_file)
    print(f"AES encryption start: {start}")
    print(f"AES encryption end: {end}")
    print(f"AES total encryption time: {duration} ns")
    print(f"AES total clock cycles: {duration/10000}")