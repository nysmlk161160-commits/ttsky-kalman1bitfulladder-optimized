# v21 stage evidence: input4/X has eight MUX loads, then three antenna diodes
# make eleven after global routing. Split now so later repair retains headroom.
set i4_driver [$block findInst input4]
require {$i4_driver ne "NULL"} "Expected ui_in2 driver input4."
require {[[$i4_driver getMaster] getName] eq "sky130_fd_sc_hd__clkdlybuf4s25_1"} "Unexpected input4 driver."
set i4_net [[$i4_driver findITerm X] getNet]
set i4_terms [input_terms $i4_net]
require {[llength $i4_terms] == 8} "Expected eight original input4 MUX input loads."
require {$::env(MAX_FANOUT_CONSTRAINT) == 10} "Fanout limit must remain ten."
set i4_rows [list]; set i4_xs [list]; set i4_ys [list]
foreach pin $i4_terms {
    set inst [$pin getInst]
    require {[[$inst getMaster] getName] eq "sky130_fd_sc_hd__mux2_1"} "Expected input4 MUX sink."
    require {[$pin getMTerm] ne "NULL"} "Expected named input4 sink."
    lassign [$inst getLocation] x y
    lappend i4_rows [list [$inst getName] $pin $x $y]
    lappend i4_xs $x; lappend i4_ys $y
}
set i4_sx [lsort -integer $i4_xs]; set i4_sy [lsort -integer $i4_ys]
set i4_xspan [expr {[lindex $i4_sx end]-[lindex $i4_sx 0]}]
set i4_yspan [expr {[lindex $i4_sy end]-[lindex $i4_sy 0]}]
set i4_axis [expr {$i4_xspan >= $i4_yspan ? 2 : 3}]
set i4_rows [lsort -integer -index $i4_axis [lsort -index 0 $i4_rows]]
set i4_master [[ord::get_db] findMaster sky130_fd_sc_hd__buf_4]
require {$i4_master ne "NULL"} "Noninverting data buffer master missing."
require {[$block findInst input4_fanout_stage] eq "NULL"} "Data split buffer already exists."
require {[$block findNet input4_fanout_branch] eq "NULL"} "Data split net already exists."
set i4_buf [odb::dbInst_create $block $i4_master input4_fanout_stage]
set i4_newnet [odb::dbNet_create $block input4_fanout_branch]
$i4_newnet setSigType SIGNAL
[$i4_buf findITerm A] connect $i4_net
[$i4_buf findITerm X] connect $i4_newnet
set i4_report [open "$::env(STEP_DIR)/input4_fanout.rpt" w]
puts $i4_report "Original input4/X net [$i4_net getName]: fanout 8; limit 10; later v21 antenna loads 3."
puts $i4_report "Grouping axis: $i4_axis (2=x,3=y); data buffer sky130_fd_sc_hd__buf_4; no Boolean change."
set i4_sumx 0; set i4_sumy 0
foreach row [lrange $i4_rows 4 7] {
    lassign $row instname pin x y
    puts $i4_report "input4_fanout_stage/X -> $instname/[[$pin getMTerm] getName]"
    $pin disconnect
    $pin connect $i4_newnet
    incr i4_sumx $x; incr i4_sumy $y
}
lassign [$i4_driver getLocation] i4_rx i4_ry
set i4_bx [expr {int(($i4_rx+$i4_sumx/4.0)/2.0)}]
set i4_by [expr {int(($i4_ry+$i4_sumy/4.0)/2.0)}]
$i4_buf setOrient R0
$i4_buf setLocation $i4_bx $i4_by
$i4_buf setPlacementStatus PLACED
require {[llength [input_terms $i4_net]] == 5} "Input4 root must have four MUX loads plus buffer."
require {[llength [input_terms $i4_newnet]] == 4} "Input4 branch must have four MUX loads."
puts $i4_report "Post-split root fanout 5; branch fanout 4. Power connection and DPL follow in parent step; standard timing repair follows this step."
close $i4_report
puts "Kalman input4 split complete: original8 -> root5/branch4; fanout10 unchanged."
