# Asynchronous FIFO — RTL Design & UVM Verification

A parameterized, dual-clock asynchronous FIFO built in Verilog, with a self-checking UVM 1.2 verification environment targeting Xilinx Vivado `xsim`.

This repo contains both the RTL design and the full verification environment used to find and fix real CDC (clock-domain-crossing) bugs, exercise directed edge cases, and confirm correctness across varying clock ratios and randomized stimulus.

---

## Overview

An async FIFO is a classic CDC building block: data is written in one clock domain and read in a completely independent, unrelated clock domain. Getting this right requires Gray-code pointer encoding, properly synchronized reset domains, and two-flop synchronizers on every signal crossing between clocks — and it's a design that's deceptively easy to get *almost* right while still harboring real bugs.

This project implements that FIFO from scratch, then builds a full UVM verification environment around it — not just to confirm it works, but to deliberately hunt for the kind of subtle bugs that only show up under specific timing conditions.

## Design (RTL)

| Module | Purpose |
|---|---|
| `top_module.v` | Top-level FIFO, ties everything together |
| `two_port_ram.v` | Dual-port memory array (independent write/read clocks) |
| `reset_synchroniser.v` | Two-flop, assert-async/deassert-sync reset synchronizer (one instance per clock domain) |
| `two_ff_synchroniser.v` | Two-flop synchronizer for crossing Gray-code pointers between clock domains |
| `b2g_converter.v` | Binary-to-Gray code converter |
| `fifo_full.v` / `fifo_empty.v` | Gray-code comparison logic for full/empty flag generation |

**Parameters:** `DATA_WIDTH` (default 8), `PTR_WIDTH` (default 4, giving a depth of 8).

## Verification Environment

A complete UVM 1.2 environment, consolidated into a single file (`top_tb_uvm.sv`) for readability, containing:

- **Interface** (`fifo_if`) with four clocking blocks — separate driver-side and monitor-side blocks per clock domain, required by `xsim`'s restrictions on shared clocking block access
- **Write/read agents** — independent sequencer, driver, and monitor per clock domain
- **Self-checking scoreboard** — exact in-order comparison of every write against every read
- **Directed and randomized sequences** — including deliberate full/empty/wraparound-forcing sequences
- **Multiple test classes**, selectable at runtime via `+UVM_TESTNAME`

### Tests included

| Test | What it verifies |
|---|---|
| `fifo_test` | Basic randomized write/read data integrity |
| `fifo_full_test` | Directed: FIFO correctly fills and refuses writes past depth |
| `fifo_empty_test` | Directed: FIFO correctly refuses reads while empty |
| `fifo_wraparound_test` | Multiple pointer wraps around the depth boundary |
| `fifo_reset_midtraffic_test` | Reset asserted mid-burst correctly flushes the FIFO and recovers |

### What's been confirmed

- Zero data mismatches across all directed and randomized tests
- Correct behavior across **three different write/read clock ratios** (write-fast, read-fast, near-equal) — the actual generality an async FIFO is supposed to guarantee
- Correct behavior across **multiple random seeds**, confirming genuine stimulus variation rather than one repeated pattern
- Correct reset recovery when reset is asserted with unread data actively in the FIFO
- Correct full/empty boundary behavior at both the default depth (8) and a reduced depth (4)

## Real Bugs Found

This wasn't just "write a testbench and it passed" — the process surfaced two genuine, independent bugs:

1. **RTL: unsynchronized reset across clock domains.** The original design fed a single reset signal directly into both clock domains with no synchronization — a real CDC hazard. Fixed with a proper two-flop, assert-async/deassert-sync synchronizer per domain.

2. **Testbench: a reset-domain mismatch between the monitor and the DUT.** A directed test at the `full` boundary revealed the scoreboard's write count was off by one. Root-caused (via direct waveform inspection *and* independent hand-derivation of the expected Gray-code value) to the write monitor gating on the raw testbench reset signal instead of the same internally-synchronized reset the DUT actually used — causing it to briefly miscount a write the DUT had correctly refused.

Full details, including every debugging step, tool-specific quirks encountered, and dead ends, are documented in [`AsyncFIFO_Complete_Project_Report.md`](./AsyncFIFO_Complete_Project_Report.md).

## Repository Structure

```
├── AsyncFIFO.srcs/
│   ├── sources_1/new/          # RTL design files
│   └── uvm_sim/new/            # UVM testbench (top_tb_uvm.sv)
├── AsyncFIFO_Complete_Project_Report.md   # Full development history, bugs, and fixes
└── README.md
```

## Running the Simulation

Environment: Xilinx Vivado 2024.1, `xsim` simulator.

```tcl
open_project AsyncFIFO.xpr

# Run a specific test
set_property -name {xsim.simulate.xsim.more_options} \
    -value "-testplusarg UVM_TESTNAME=fifo_full_test" \
    -objects [get_filesets uvm_sim]
launch_simulation -simset uvm_sim -mode behavioral
```

**Run the full regression:**
```tcl
set test_list {fifo_test fifo_full_test fifo_empty_test fifo_wraparound_test fifo_reset_midtraffic_test}
foreach t $test_list {
    set_property -name {xsim.simulate.xsim.more_options} -value "-testplusarg UVM_TESTNAME=$t" -objects [get_filesets uvm_sim]
    launch_simulation -simset uvm_sim -mode behavioral
    close_sim
}
```

**Vary the clock ratio** (write/read periods in ns, overridable at elaboration time):
```tcl
set_property -name {xsim.elaborate.xelab.more_options} \
    -value {-generic "W_CLK_PERIOD=10.0" -generic "R_CLK_PERIOD=12.0"} \
    -objects [get_filesets uvm_sim]
```

**Vary the random seed:**
```tcl
set_property -name {xsim.simulate.xsim.more_options} \
    -value "-testplusarg UVM_TESTNAME=fifo_wraparound_test -sv_seed 42" \
    -objects [get_filesets uvm_sim]
```

## What's Next

- SystemVerilog Assertions (SVA) for protocol-level checking (no-write-when-full, no-read-when-empty, full/empty never simultaneous)
- Functional coverage model (previously built and confirmed working, currently removed for simplicity — see the project report for details)
- `DATA_WIDTH` parameter sweep

## Skills Demonstrated

RTL design · CDC (clock-domain-crossing) design and debug · UVM 1.2 (agents, sequencers, scoreboards, virtual interfaces, `uvm_config_db`) · Gray-code pointer arithmetic · directed and constrained-random verification · root-cause debugging via waveform and first-principles analysis · Vivado/xsim toolchain
