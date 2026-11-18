# SFCBuilder Rev.0.7 — integrated RTL v2 (2026-11-18)

This is a **new functional RTL implementation** aligned to the current GitHub
Rev.0.7 memory, boot and communications specifications. No GitHub content was
modified. It supersedes the earlier `sfcbuilder_rev07.v` demonstration file.

## Contents

- `sfcbuilder_rev07.v` — integrated memory decoder, 1MiB ROM mapper, 6-byte
  UDB boot response, host/ARM address and bus control, 12 register addresses,
  one-outstanding-command mailbox, two four-byte **sys_clk-synchronous** FIFO
  behavioral models, and GPIO-switch handshake FSM.
- `tb_sfcbuilder_rev07.v` — SystemVerilog behavioral testbench. Includes
  startup, initial ARM bus ownership, isolation, GPIO acknowledgment, boot ROM,
  SRAM BIOS at $2F:6000, host ROM, all mapper block counts, SFC command mailbox,
  TX and RX FIFOs, and IRQ gating, including the host-quiescence and ARM-owned $5000 checks.
- `verify_models.py` — executed Python reference-oracle and structural checks.
- `verification.txt` — outputs of the actual Python tests and tool availability.

## Changed behavior (v2)

1. Two 4-byte FIFOs use one UDB-side `sys_clk` domain for head/tail pointers
   and FULL/EMPTY, independent of whether SFC transfers are taking place.
   SFC /WR completion captures the data and toggles a request; 2-flop
   synchronizers move requests into sys_clk. SFC /RD assertion snapshots
   the prefetched head byte; /RD completion triggers the subsequent pop.
   ARM's stream interface is presented directly in sys_clk. This is a
   synthesizable **functional stand-in** for PSoC datapath F0/F1; it is not
   by itself a Creator UDB datapath instantiation.
2. The bus owner is managed by a hardware state machine:
   ISO → QUIET → CONFIG → GUARD (4 clocks) → ARM or SFC.
   A running owner requests transfer; SFC→ARM requires `host_quiesced=1`
   (SFC executing WRAM code). During QUIET/CONFIG/GUARD the 3SB is off,
   both /CE inactive, /OE and /WE inactive, and 23 memory address OEs off.
   Firmware changes `PRTx_BYP` and drive modes when `gpio_cfg_request=1`,
   then holds `gpio_cfg_done=1` until ownership is granted. A stale ACK
   already high at entry is not accepted: the state machine requires a low
   followed by a high. Three asynchronous ARM control inputs use 2FF CDC.
3. Both ownership and FIFO logic coexist with Rev.0.7 boot fixed bytes,
   NOR/SRAM exclusivity, HiROM/ExHiROM and 1MiB mirroring, A19 fixed 3SB
   path, communications registers, and mailbox.

## Resource accounting (derived from source, not from Creator)

| Structure | Explicit state bits | Notes |
|---|---:|---|
| Ownership FSM (`state`, `target_arm`, `config_seen_low`, `guard_count`) | 8 | 6 FSM states, 4 clock guard |
| Ownership request/ack synchronizers | 6 | 3 independent 2FF inputs |
| Command mailbox + ACK synchronizers | 17 | 8 data + 3 type + 6 control bits |
| Host FIFO event capture/snapshot | 20 | TX latch, RX read snapshot, toggles/valid |
| FIFO event synchronizers and sticky flags | 11 | 3 event channels x 3 + 2 flags |
| Generic FIFO storage and pointer/control | 78 | 64 storage bits + 14 pointers/counts, to be replaced by native FIFOs |
| **Total in behavioral RTL** | **140** | Static state-bit count, not post-synthesis flip-flops |
| **Total excluding generic FIFO stand-in** | **62** | Does NOT imply 62 PLD macrocells: PSoC controls/data paths may map differently |

FSM and ownership CDC alone occupy **14 storage bits** in this conservative
source count. Given four macrocells per PSoC PLD, **4 PLDs is a theoretical
minimum for 14 separately mapped flip-flops**, *before* combinational decode,
clock routing and other constraints; this is NOT a PLD utilization result.
The prior 34–40 PLD budget for the larger Rev.0.7 circuit was also a
pre-synthesis estimate. Exact resource fits **cannot be established** by
counting source-level logic: PSoC Creator mapping is required. Thus the
claim "the updated entire design is below 48 PLDs" is **not verified**.

The manufacturer's TRM documents **two native four-byte FIFO buffers F0/F1
per UDB datapath** and GPIO port bypass selection; this is why generic RAM
storage is not counted as requiring PSoC PLDs when mapped to datapaths.

## Verification executed here

Run `python3 verify_models.py` to reproduce:

- 384 independent mapper input combinations: **PASS**.
- 512 boot address/enable combinations: **PASS**.
- 48 SRAM addressing boundary checks and BIOS entry: **PASS**.
- 20,000 randomized independent FSM reference transitions: **PASS**.
- 100,000 randomized synchronous FIFO reference operations: **PASS**.
- 192 direct evaluations of the **actual Verilog mapper RHS expressions**: **PASS**.
- 6 actual Verilog fixed boot-byte case entries: **PASS**.
- 12 actual Verilog host address pad OE bits: **PASS**.
- 9 checks for required RTL structures and signal expressions: **PASS**.

The checks above exercise **independent Python models and RTL structural
properties**. They are not HDL simulation or PSoC synthesis. Icarus Verilog,
Verilator, and Yosys were not available in the environment; an attempted
package installation failed because network package sources were unreachable.
**Do not represent the accompanying Verilog testbench as executed.**

HDL simulation command on a machine with Icarus Verilog:

```sh
iverilog -g2012 -s tb_sfcbuilder_rev07 -o rev07sim sfcbuilder_rev07.v tb_sfcbuilder_rev07.v
vvp rev07sim
```

## Implementation contracts and remaining work

- `sys_clk` is nominally 40MHz. SFC DMA accesses (approximately 372.5ns apart)
  allow at least 3 sys_clk periods between host toggle events; the captured
  byte must remain stable across the two-flop request synchronizer.
- Software polls FIFO_STATUS before writing TX; full writes set an overrun
  flag. Empty RX reads return zero and set an underrun flag. RX data is
  sampled on /RD assertion, so no late ARM push changes an in-flight read.
- `gpio_cfg_done` must be a level held until the target owner is active.
  GPIO settings are *not* changed by Verilog; Creator firmware must modify
  `PRTx_BYP` and `PRTx_DM*`. ARM must disable its memory strobes before
  handoff. A true bus-safe implementation also needs pin-level OE and
  reset-state analysis.
- The RTL does not include PSoC-specific F0/F1 microcode and bus-access
  control, pin-route assignment, USB/SPI, DVDAC, or PIC CIC hardware.
- PSoC Creator place-and-route, analog pin routing, STA, CDC sign-off, and
  SFC hardware tests remain distinct implementation/validation steps.