MAIN CONTROL BLOCK (SNN chip) - RTL + SYNTHESIS + P&R BUNDLE

Source spec: "Control block.pptx" (slide 1 = chip block diagram,
slide 2 = "Main Control Block - State Machine").

Files:
- main_control_block.sv        RTL
- tb_main_control_block.sv     self-checking testbench (169 checks)
- control_syn.tcl              Design Compiler synthesis script
- .synopsys_dc.setup           Tower 0.18um tsl18fs120 library setup
- innovus/                     Innovus place & route scripts

WHAT THE BLOCK DOES

  Mode 00  Idle / Loop-Back  LB_SPn rising edge arms the receiver; the next
                             5 PE_Pulse edges shift in code N;
                             LB_en[N:0]=0, LB_en[31:N+1]=1
  Mode 01  Program           every 5 PE_Pulse edges shift in code N;
                             WL_Sel[N]=0, others 1; WL_Enable=1
  Mode 10  Erase             every 6 PE_Pulse edges shift in code N (0-63);
                             BL_Sel[N]=0, other 63 are 1; BL_Enable=1
  Reset                      LB_en[15:0]=0, LB_en[31:16]=1, selects cleared

  Bits arrive on S_in MSB first, one per PE_Pulse rising edge.

DESIGN DECISIONS NOT FIXED BY THE SLIDES (please confirm)

1. PE_Pulse is the only clock (the diagram has no system clock pad).
2. rst_n was added as an asynchronous active-low reset pin; the slide has a
   "Reset / Initialization" box but the diagram shows no reset pad.
3. BL_Sel is 64 bits and the Erase code is 6 bits (64 bit-line switches:
   32 positive + 32 negative). The state-machine slide still shows a 5-bit
   code and BL_Sel<31:0> for Erase and should be updated to match.
4. WL_Zero and BL_Zero are tied to 0 ("as defined, usually 0").
5. WL_Sel / BL_Sel reset to all 0 (all switches disabled).
6. Mode 11 is treated as Idle.
7. A frame starts on the first PE_Pulse edge after Mode changes. If Mode
   leaves and returns to the same mode with no PE_Pulse edge in between, a
   half-received code is continued, not discarded.
8. LB_SPn must not toggle close to a PE_Pulse rising edge (it is counted
   in its own clock domain and read without a synchronizer).
9. The Bias shift register / BCode[0:39] / Sd_in of Ctrl2 is not
   implemented - the state-machine slide does not describe it.

SIMULATE (any machine with Icarus Verilog)

  iverilog -g2012 -o tb.vvp main_control_block.sv tb_main_control_block.sv
  vvp tb.vvp          -> "=== ALL 169 CHECKS PASSED ==="

SYNTHESIZE (lab machine)

  cd ~/Desktop/khaled/snn_control_block
  git pull origin main
  design_vision &
  (in Design Vision:)  source control_syn.tcl

  Output: main_control_block_syn.v, control.sdc, reports/{timing,area,power}.rpt

PLACE & ROUTE

  See innovus/INNOVUS_FLOW.txt
