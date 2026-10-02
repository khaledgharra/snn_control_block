#============================================================
# Main Control Block synthesis script - SystemVerilog version
# Tool       : Synopsys Design Vision / Design Compiler
# Top module : main_control_block
# Clock port : PE_Pulse (serial shift clock)
# Output     : main_control_block_syn.v, control.sdc
#============================================================

# Clean old data from this Design Vision session
remove_design -all

# Variables
set DESIGN_NAME main_control_block
set CLK_NAME    PE_Pulse
set CLK_PERIOD  10
set LB_CLK_NAME LB_SPn

# Make includes searchable from the current folder
set_app_var search_path [concat [list . [pwd]] $search_path]

# Create WORK library for analyze/elaborate flow
file mkdir WORK
define_design_lib WORK -path ./WORK

# Read SystemVerilog RTL
analyze -format sverilog {
    ./main_control_block.sv
}

# Build the top design
elaborate $DESIGN_NAME
current_design $DESIGN_NAME
link
uniquify
check_design

# Clock constraints
# PE_Pulse clocks all the shift registers and outputs.
create_clock -name $CLK_NAME -period $CLK_PERIOD -waveform {0 5} [get_ports $CLK_NAME]

# LB_SPn clocks only the 2-bit loop-back event counter. It is unrelated to
# PE_Pulse, so the two clocks are declared asynchronous to each other.
create_clock -name $LB_CLK_NAME -period $CLK_PERIOD -waveform {0 5} [get_ports $LB_CLK_NAME]
set_clock_groups -asynchronous -group $CLK_NAME -group $LB_CLK_NAME

# Basic I/O constraints for backend/floorplan exercise
set_input_delay  0 -clock $CLK_NAME [remove_from_collection [all_inputs] [get_ports [list $CLK_NAME $LB_CLK_NAME]]]
set_output_delay 0 -clock $CLK_NAME [all_outputs]

# Synthesis - same basic idea as the i2c backend lab
compile -exact_map

# Reports
file mkdir reports
redirect -file reports/timing.rpt { report_timing -max_paths 10 }
redirect -file reports/area.rpt   { report_area }
redirect -file reports/power.rpt  { report_power }

# Netlist for Innovus / floorplan
write -hierarchy -format verilog -output main_control_block_syn.v

# SDC for Innovus - generated from this exact session
write_sdc control.sdc

puts "============================================================"
puts "SYNTHESIS FINISHED SUCCESSFULLY"
puts "Generated netlist: main_control_block_syn.v"
puts "Reports folder: reports/"
puts "Top module: main_control_block"
puts "Clock port: PE_Pulse"
puts "============================================================"
