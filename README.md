# SNN Main Control Block

A small digital control block for a spiking-neural-network (SNN) chip whose
synaptic weights are stored in Y-flash memory arrays. The block receives short
serial codes and turns them into the wide select signals that choose which
word line or bit line of the arrays is acted on during programming and erasing.

It is written in SystemVerilog, verified by simulation, and synthesized with
Synopsys Design Compiler on a Tower 0.18 µm standard-cell library.

## Why it exists

The memory arrays need 32 word-line selects and 64 bit-line selects. Bringing
96 select wires out of the chip is not practical, so the selection is sent
**serially**: one bit at a time on a single data pin, clocked by a pulse pin.
This block collects the bits and decodes them.

## Interface

| Signal | Direction | Width | Meaning |
|---|---|---|---|
| `PE_Pulse` | in | 1 | Clock. Each rising edge shifts in one bit of `S_in`. |
| `rst_n` | in | 1 | Asynchronous reset, active low. |
| `Mode` | in | 2 | `00` idle, `01` program, `10` erase (`11` is treated as idle). |
| `S_in` | in | 1 | Serial data, most significant bit first. |
| `WL_Sel` | out | 32 | Word-line switch selects. |
| `WL_Enable` | out | 1 | High in program mode. |
| `WL_Zero` | out | 1 | Tied to 0. |
| `BL_Sel` | out | 64 | Bit-line switch selects (32 positive + 32 negative). |
| `BL_Enable` | out | 1 | High in erase mode. |
| `BL_Zero` | out | 1 | Tied to 0. |

## How it works

| Mode | Code length | What happens when the code N is complete |
|---|---|---|
| `00` Idle | – | Nothing. The current selections are kept, both enables are 0. |
| `01` Program | 5 bits (N = 0..31) | `WL_Sel[N] = 0`, all other `WL_Sel` bits = 1. `WL_Enable = 1`. |
| `10` Erase | 6 bits (N = 0..63) | `BL_Sel[N] = 0`, all other `BL_Sel` bits = 1. `BL_Enable = 1`. |

- The selection only changes when a **complete** code has arrived, and it is
  held until the next complete code.
- Codes can be sent back to back without leaving the mode.
- The first `PE_Pulse` edge after `Mode` changes is the first bit of a new code.
- Reset clears `WL_Sel` and `BL_Sel` to all 0.

The erase code is one bit longer than the program code because there are 64
bit-line switches and only 32 word-line switches.

### Example: program code 5

Code 5 is `00101` in binary, sent most significant bit first:

```
PE_Pulse   _|‾|_|‾|_|‾|_|‾|_|‾|_
S_in         0   0   1   0   1
bit number   1   2   3   4   5
WL_Sel      00000000 ......... | ffffffdf
                               ^ updated on the 5th pulse
```

`ffffffdf` in binary is `1111 1111 1111 1111 1111 1111 1101 1111`: every bit is
1 except bit 5.

## Results

### Simulation

The design is tested with [Icarus Verilog](https://steveicarus.github.io/iverilog/).
The self-checking testbench runs **126 checks and all pass**
([`results/test_output.txt`](results/test_output.txt)). It covers:

- reset values
- every program code, 0 to 31
- every erase code, 0 to 63
- no change until the last bit of a code arrives
- idle mode keeps the selections and ignores pulses
- changing mode in the middle of a code
- the undefined mode `11`

A pulse-by-pulse trace is in
[`results/demo_output.txt`](results/demo_output.txt). An excerpt:

```
ERASE code 40 (101000) - expect BL_Sel bit 40 = 0 after the 6th pulse
  pulse  S_in=1   | Mode=10 WL_En=0 BL_En=1 | WL_Sel=7fffffff | BL_Sel=fffffffffffffffe
  pulse  S_in=0   | Mode=10 WL_En=0 BL_En=1 | WL_Sel=7fffffff | BL_Sel=fffffffffffffffe
  pulse  S_in=1   | Mode=10 WL_En=0 BL_En=1 | WL_Sel=7fffffff | BL_Sel=fffffffffffffffe
  pulse  S_in=0   | Mode=10 WL_En=0 BL_En=1 | WL_Sel=7fffffff | BL_Sel=fffffffffffffffe
  pulse  S_in=0   | Mode=10 WL_En=0 BL_En=1 | WL_Sel=7fffffff | BL_Sel=fffffffffffffffe
  pulse  S_in=0   | Mode=10 WL_En=0 BL_En=1 | WL_Sel=7fffffff | BL_Sel=fffffeffffffffff
```

### Synthesis

Synthesized with Synopsys Design Compiler (R-2020.09-SP2) on the Tower
0.18 µm `tsl18fs120` typical library, with a 10 ns clock on `PE_Pulse`:

| | Result |
|---|---|
| Timing | Met (no negative slack) |
| Flip-flops | 110 (64 `BL_Sel`, 32 `WL_Sel`, 14 for shift registers, bit counter and mode) |
| Cell area | 973 library units |

The only warnings are the two outputs that are deliberately tied to 0
(`WL_Zero`, `BL_Zero`).

Place and route scripts for Cadence Innovus are in `innovus/`. They have not
been run on this design yet.

## Run it yourself

You need Icarus Verilog (`brew install icarus-verilog` on macOS,
`apt install iverilog` on Ubuntu).

Pass/fail test:

```
iverilog -g2012 -o tb.vvp main_control_block.sv tb_main_control_block.sv
vvp tb.vvp
```

Expected last line: `=== ALL 126 CHECKS PASSED ===`

Pulse-by-pulse demo:

```
iverilog -g2012 -o demo.vvp main_control_block.sv tb_demo.sv
vvp demo.vvp
```

To try other codes, edit the calls near the bottom of `tb_demo.sv`
(`program_code(5'd5);`, `erase_code(6'd40);`, ...) and run it again.

Synthesis (needs Design Compiler and the Tower library):

```
design_vision
source control_syn.tcl
```

This writes `main_control_block_syn.v`, `control.sdc` and
`reports/{timing,area,power}.rpt`. The place and route steps are in
[`innovus/INNOVUS_FLOW.txt`](innovus/INNOVUS_FLOW.txt).

## Files

| File | What it is |
|---|---|
| `main_control_block.sv` | The design |
| `tb_main_control_block.sv` | Self-checking testbench (126 checks) |
| `tb_demo.sv` | Prints the outputs pulse by pulse |
| `results/` | Saved simulation output |
| `control_syn.tcl`, `.synopsys_dc.setup` | Design Compiler synthesis script and library setup |
| `innovus/` | Innovus floorplan, pin placement and flow notes |

## Design choices and limits

- `PE_Pulse` is the only clock; there is no separate system clock. Because of
  that, `WL_Enable` and `BL_Enable` are decoded directly from `Mode` instead of
  being registered.
- `WL_Zero` and `BL_Zero` are constant 0.
- If `Mode` leaves a mode and returns to the same mode with no `PE_Pulse` edge
  in between, a half-received code is continued, not discarded.
- A loop-back mode (`LB_SPn` input, `LB_en` output) and the bias shift register
  are part of the wider chip plan and are not implemented here. An earlier
  version with loop-back is in the git history (commit `7bc85a6`).
