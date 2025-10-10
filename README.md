# Verilog Toolchain for AES-128

This repository provides a complete **toolchain for testing, synthesizing, simulating, and analyzing Verilog modules**, demonstrated here with an AES-128 implementation. It is designed to be **used standalone** but work is currently underway for it to be used in combination with evolutionary tools like OpenEvolve.

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
├── synth_check.sh       # Check if Verilog files are synthesizable with Yosys
├── simulate.sh          # Run simulation with Icarus Verilog and generate dump.vcd
├── run_all.sh           # Runs synthesis → simulation → VCD parsing end-to-end
├── yosys_out.log        # Log file from synthesis
├── dump.vcd             # Waveform dump from simulation
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

### 1. Manual End-to-End

1. Make scripts executable:

```bash
chmod +x synth_check.sh simulate.sh run_all.sh
```

2. Run the full toolchain for a specific top module:

```bash
./run_all.sh aes_tb src/aes.v src/tb.v
```

**Output:**

* Synthesizability check in `yosys_out.log`
* Simulation produces `dump.vcd`
* Python analysis outputs encryption duration and total clock cycles

Example output:

```
Detected 'busy_out' symbol: "
AES encryption start: 1035000
AES encryption end: 2795000
AES total encryption time: 1760000 ns
AES total clock cycles: 176.0
```

---

## Notes

* **Timescale:** Testbench uses `` `timescale 1ns / 1ps ``.
* **Clock period:** Default is 10 ns (100 MHz) in `parse_vcd.py`. Adjust if using a different clock.
* **VCD parsing:** Only requires the `busy_out` signal for AES cycle measurement.
