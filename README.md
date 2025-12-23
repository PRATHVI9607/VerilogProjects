# Advanced Digital Logic Design Projects

A collection of 12 Verilog-based computer architecture projects demonstrating various concepts in digital design and processor architecture.

## Projects

| # | Project | Description |
|---|---------|-------------|
| 01 | [Pipelined RISC-V CPU](01_Pipelined_RISCV_CPU/) | 5-stage pipelined processor with hazard detection and forwarding |
| 02 | [Cache Memory System](02_Cache_Memory_System/) | 4-way set-associative cache with LRU replacement |
| 03 | [Branch Predictor](03_Branch_Predictor/) | Tournament predictor combining local and global history |
| 04 | [Out-of-Order Execution Core](04_OoO_Execution_Core/) | Superscalar core with reorder buffer and register renaming |
| 05 | [Tomasulo Processor](05_Tomasulo_Processor/) | Classic Tomasulo algorithm with reservation stations |
| 06 | [Superscalar CPU](06_Superscalar_CPU/) | Dual-issue superscalar processor |
| 07 | [TLB MMU](07_TLB_MMU/) | Translation Lookaside Buffer and Memory Management Unit |
| 08 | [Cache Coherence](08_Cache_Coherence/) | MESI protocol implementation for multi-core systems |
| 09 | [Virtual Memory Simulator](09_Virtual_Memory_Simulator/) | Page table walker with TLB integration |
| 10 | [Memory BIST](10_Memory_BIST/) | Built-In Self-Test using March algorithms |
| 11 | [Interrupt Pipeline](11_Interrupt_Pipeline/) | Priority-based interrupt controller with pipeline integration |
| 12 | [Scoreboard](12_Scoreboard/) | CDC 6600-style scoreboard for dynamic scheduling |

## Requirements

- **Icarus Verilog** (iverilog) with `-g2012` flag for SystemVerilog support
- **GTKWave** for waveform viewing (optional)

### Installation (Ubuntu/Debian)
```bash
sudo apt-get install iverilog gtkwave
```

### Installation (macOS)
```bash
brew install icarus-verilog gtkwave
```

## Usage

Each project has its own directory with the following structure:
```
XX_Project_Name/
├── rtl/          # RTL source files
├── tb/           # Testbench files
├── Makefile      # Build automation
└── README.md     # Project-specific documentation
```

### Running a Simulation

```bash
cd XX_Project_Name
make sim        # For projects 01-06, 12
# OR
make simulate   # For projects 07-11
```

### Viewing Waveforms

```bash
make wave       # Opens GTKWave with generated VCD file
```

### Cleaning Build Files

```bash
make clean
```

## License

This project is for educational purposes.

## Author

ADLD Projects Collection
