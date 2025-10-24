# Verilog Toolchain for AES-128

This repository provides a complete toolchain for testing, simulating, synthesizing, and analyzing Verilog modules, demonstrated here with an AES-128 implementation.

The toolchain runs simulation (Icarus Verilog), synthesis (Yosys), and VCD analysis, outputting all logs, status, and cycle counts into a single **`toolchain_results.json`** file. This file is designed to be fed back into other tools, such as an LLM or an evolutionary framework like OpenEvolve.

---

## Repository Structure

```
verilog_toolchain/
├── src/                 # Verilog source files and testbenches
│   ├── aes.v
│   ├── tb.v
│   ├── keyexpansion.v
│   ├── sbox_8bit.v
│   ├── invmap_8bit.v
│   ├── map_8bit.v
│   ├── native_mixcolumns.v
│   ├── bytepermutation.v
│   └── par2ser.v
├── parse_vcd.py         # Python script to parse dump.vcd and calculate clock cycles
├── simulate.sh          # Run simulation with Icarus Verilog and generate dump.vcd
├── synthesis.sh         # Check if Verilog files are synthesizable with Yosys
├── run_toolchain.py     # Runs synthesis → simulation → VCD parsing end-to-end
├── yosys_out.log        # Log file from synthesis
├── top.vcd              # Waveform dump from simulation
└── README.md
```

---

## Requirements

* [Yosys](https://yosyshq.net/yosys/) (synthesis)
* [Icarus Verilog](http://iverilog.icarus.com/) (simulation)
* Python 3.x
* Bash shell (Linux/macOS)

---

## Usage

### 1. Make scripts executable:

You only need to do this once:
```bash
chmod +x run_toolchain.py simulate.sh synthesis.sh parse_vcd.py
```

### 2. Run the full toolchain for a specific top module

Execute the master Python script. The only argument it needs is the name of your top-level testbench module (e.g., aes_tb).

```bash
./run_toolchain.py aes_tb
```

### 3. Check the output

The script will run all steps and generate a toolchain_results.json file. This file contains the pass/fail status and logs for each step, plus the final cycle analysis.

<details> <summary><b>Click to see an example toolchain_results.json output</b></summary>

```json
{
    "files": {
        "design_files": [
            "src/bytepermutation.v",
            "src/aes.v",
            "src/sbox_8bit.v",
            "src/invmap_8bit.v",
            "src/map_8bit.v",
            "src/par2ser.v",
            "src/keyexpansion.v",
            "src/native_mixcolumns.v"
        ],
        "testbench_file": "src/tb.v",
        "all_simulation_files": [
            "src/bytepermutation.v",
            "src/aes.v",
            "src/sbox_8bit.v",
            "src/invmap_8bit.v",
            "src/map_8bit.v",
            "src/par2ser.v",
            "src/keyexpansion.v",
            "src/native_mixcolumns.v",
            "src/tb.v"
        ]
    },
    "simulation": {
        "return_code": 0,
        "status": "success",
        "log": "--- Log File (sim.log) ---\nVCD info: dumpfile top.vcd opened for output.\n2dc1e9df9d4089be86138b9221fb3391\n\n\n--- Captured STDOUT ---\nRunning simulation for aes_tb...\nVCD info: dumpfile top.vcd opened for output.\n2dc1e9df9d4089be86138b9221fb3391"
    },
    "synthesis": {
        "return_code": 0,
        "status": "success",
        "log": "--- Log File (yosys_out.log) ---\n\n /----------------------------------------------------------------------------\\\n | ... (Yosys log content) ... |\n \\----------------------------------------------------------------------------/\n... Synthesis passed."
    },
    "vcd_analysis": {
        "clk_period_ns": 10,
        "start_time_ns": 1005.0,
        "end_time_ns": 2625.0,
        "duration_ns": 1620.0,
        "total_clock_cycles": 162.0,
        "analysis_status": "success",
        "debug_log": "[parse_vcd.py] Attempting to parse clock period from: src/tb.v\n[parse_vcd.py] --> Found 'always #5' on line 43. Clock period: 10 ns\n[parse_vcd.py] Attempting to parse VCD file: top.vcd\n[parse_vcd.py] --> Read 17447 lines from VCD.\n[parse_vcd.py] Searching for 'load_in' symbol definition ($var)...\n[parse_vcd.py] --> Found 'load_in' symbol: '#' on line 13\n[parse_vcd.py] Searching for 'busy_out' symbol definition ($var)...\n[parse_vcd.py] --> Found 'busy_out' symbol: '\"' on line 12\n[parse_vcd.py] ... (VCD parsing log) ...\n[parse_vcd.py] --> Value change for 'load_in' ('#'): '0' -> '1' at time 1005000\n[parse_vcd.py] ----> RISING EDGE DETECTED for 'load_in': Setting start_time = 1005000\n[parse_vcd.py] --> Value change for 'busy_out' ('\"'): '1' -> '0' at time 2625000\n[parse_vcd.py] ----> FALLING EDGE DETECTED for 'busy_out': Setting potential end_time = 2625000\n[parse_vcd.py] Finished parsing VCD lines.\n[parse_vcd.py] --> Calculated Times (ns): Start=1005.000, End=2625.000, Duration=1620.000\n[parse_vcd.py] --> VCD analysis successful."
    }
}
```
</details>

---

## Notes

* **Timescale:** Testbench uses `` `timescale 1ns / 1ps ``.
* **Clock period:** The parse_vcd.py script automatically detects the clock period (10 ns) by parsing the ``always #5 clk = ~clk;`` line from ``src/tb.v.``
* **VCD parsing:** The analysis script measures the total operation time by finding the time between the first rising edge of ``load_in`` and the last falling edge of ``busy_out``.
* **VCD Filename:** The simulation is hardcoded in ``tb.v`` to produce ``top.vcd``, which ``parse_vcd.py`` correctly reads.
