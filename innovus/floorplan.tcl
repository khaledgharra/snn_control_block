#============================================================
# main_control_block — Floorplan + Pins + Power (core-only, no pad ring)
# Usage:  source floorplan.tcl
#============================================================

puts "=== STEP 1: Floorplan ==="
# -r <aspect ratio> <utilization> <left> <bottom> <right> <top> core-to-die margins.
# Square core, 40% utilization (small block - leaves boundary length for the
# ~140 pins), 12um margin on each side for the power ring.
floorPlan -site CoreSite -r 1.0 0.4 12 12 12 12

puts "=== STEP 2: Place I/O pins on the boundary ==="
# No pad ring, so pins must be placed explicitly - otherwise they all stay
# stacked at the origin and no names show around the block.
# Sides follow the block diagram: inputs on the left, BL (top), WL (right),
# loop-back enables (bottom).
proc bus_pins {name msb} {
    set pins {}
    for {set i 0} {$i <= $msb} {incr i} { lappend pins "${name}\[$i\]" }
    return $pins
}
set left_pins   [concat {rst_n PE_Pulse S_in LB_SPn} [bus_pins Mode 1]]
set top_pins    [concat {BL_Enable BL_Zero} [bus_pins BL_Sel 63]]
set right_pins  [concat {WL_Enable WL_Zero} [bus_pins WL_Sel 31]]
set bottom_pins [bus_pins LB_en 31]

editPin -side Left   -layer 3 -spreadType center -spacing 4.0 -unit MICRON -fixOverlap 1 -pin $left_pins
# 66 pins on the top edge - tighter spacing so they fit.
editPin -side Top    -layer 2 -spreadType center -spacing 2.0 -unit MICRON -fixOverlap 1 -pin $top_pins
editPin -side Right  -layer 3 -spreadType center -spacing 4.0 -unit MICRON -fixOverlap 1 -pin $right_pins
editPin -side Bottom -layer 2 -spreadType center -spacing 4.0 -unit MICRON -fixOverlap 1 -pin $bottom_pins

puts "=== STEP 3: Connect global power/ground nets ==="
# -module {} registers this as a persistent connect RULE (matches
# des/innovus/glnets.src in the snn repo), so cells added later by
# optDesign/filler also get a PG connection.
globalNetConnect VDD -type pgpin -pin VDD -inst * -module {}
globalNetConnect VSS -type pgpin -pin VSS -inst * -module {}
globalNetConnect VDD -type tiehi -module {}
globalNetConnect VSS -type tielo -module {}
deselectAll

puts "=== STEP 4: Add core power ring ==="
# -around default_power_domain is the form Innovus 23.33 accepts
# ("-around core" is rejected with IMPTCM-23).
setAddRingMode \
    -ring_target default \
    -extend_over_row 0 \
    -ignore_rows 0 \
    -avoid_short 0 \
    -skip_crossing_trunks none \
    -stacked_via_top_layer M5 \
    -stacked_via_bottom_layer M1 \
    -orthogonal_only true \
    -skip_via_on_pin { standardcell } \
    -skip_via_on_wire_shape { noshape }

addRing \
    -nets {VDD VSS} \
    -around default_power_domain \
    -layer {top M5 bottom M5 left M4 right M4} \
    -width 2 \
    -spacing 1 \
    -center 1

puts "=== STEP 5: Route power to standard cell pins ==="
# Block is small enough that the ring alone feeds the rows - no stripes.
setSrouteMode -padPinLayerRange {M1 M5}
sroute \
    -connect { corePin } \
    -layerChangeRange { M1 M5 } \
    -nets { VDD VSS }

puts "=== Floorplan + Pins + Power DONE ==="
puts "Next: placeDesign, optDesign -preCTS, routeDesign"
