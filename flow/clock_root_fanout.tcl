# Post-CTS physical change only. Never alter the SDC fanout/clock constraints.
source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
read_current_odb
source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
set_propagated_clock [all_clocks]

proc require {condition message} {
    if {![uplevel 1 [list expr $condition]]} { error $message }
}
proc input_terms {net} {
    set terms [list]
    foreach pin [$net getITerms] {
        if {[$pin getIoType] eq "INPUT"} { lappend terms $pin }
    }
    return $terms
}

set block [ord::get_db_block]
set root [$block findInst clkbuf_0_clk]
require {$root ne "NULL"} "Expected the original CTS root clkbuf_0_clk."
set root_net [[$root findITerm X] getNet]
set old_terms [input_terms $root_net]
require {[llength $old_terms] == 16} "Expected precisely 16 original root loads."
require {$::env(MAX_FANOUT_CONSTRAINT) == 10} "The fanout limit must remain 10."
set master [[ord::get_db] findMaster sky130_fd_sc_hd__clkbuf_8]
require {$master ne "NULL"} "Clock buffer master is not available."

# Split the branch buffers spatially along their longest spread. Both groups
# contain eight identical input loads; names and placement make the choice repeatable.
set xs [list]; set ys [list]; set rows [list]
foreach pin $old_terms {
    set inst [$pin getInst]
    require {[[$inst getMaster] getName] eq "sky130_fd_sc_hd__clkbuf_8"} "Unexpected root load cell."
    lassign [$inst getLocation] x y
    lappend xs $x; lappend ys $y
    lappend rows [list [$inst getName] $pin $x $y]
}
set sx [lsort -integer $xs]; set sy [lsort -integer $ys]
set xspan [expr {[lindex $sx end]-[lindex $sx 0]}]
set yspan [expr {[lindex $sy end]-[lindex $sy 0]}]
set axis [expr {$xspan >= $yspan ? 2 : 3}]
set rows [lsort -integer -index $axis [lsort -index 0 $rows]]
lassign [$root getLocation] rx ry
set report [open "$::env(STEP_DIR)/clock_root_fanout.rpt" w]
puts $report "Original root: [$root getName]/X; net [$root_net getName]; fanout [llength $old_terms]; limit 10"
puts $report "Grouping axis: $axis (2=x,3=y), root master [[$root getMaster] getName]"
for {set group 0} {$group < 2} {incr group} {
    set name "clk_fanout_stage_$group"
    set netname "clk_fanout_branch_$group"
    require {[$block findInst $name] eq "NULL"} "Experiment buffer already exists."
    require {[$block findNet $netname] eq "NULL"} "Experiment net already exists."
    set buf [odb::dbInst_create $block $master $name]
    set new_net [odb::dbNet_create $block $netname]
    $new_net setSigType CLOCK
    [$buf findITerm A] connect $root_net
    [$buf findITerm X] connect $new_net
    set start [expr {$group*8}]
    set members [lrange $rows $start [expr {$start+7}]]
    set sumx 0; set sumy 0
    foreach row $members {
        lassign $row instname pin x y
        $pin disconnect
        $pin connect $new_net
        incr sumx $x; incr sumy $y
        puts $report "$name/X -> $instname/A"
    }
    # Begin between root and group centroid; standard DPL below legalizes the sites.
    set bx [expr {int(($rx+$sumx/8.0)/2.0)}]
    set by [expr {int(($ry+$sumy/8.0)/2.0)}]
    $buf setOrient R0
    $buf setLocation $bx $by
    $buf setPlacementStatus PLACED
    require {[llength [input_terms $new_net]] == 8} "New branch must have fanout eight."
    puts $report "New branch $name: fanout 8; initial location $bx $by DBU"
}
require {[llength [input_terms $root_net]] == 2} "Root fanout must be two after split."
puts $report "Final root fanout: 2; branch fanouts: 8,8; limit remains 10"
# The first completed routed attempt exposed a single overloaded data net:
# a211oi_2 _1358_/Y -> three loads, max_ss cap .059809pF > .052195pF.
# Keep its Boolean function/pins, and select the available stronger _4 master.
set data_driver [$block findInst _1358_]
require {$data_driver ne "NULL"} "Expected the observed data-net driver _1358_."
require {[[$data_driver getMaster] getName] eq "sky130_fd_sc_hd__a211oi_2"} "Unexpected data-driver master."
set stronger [[ord::get_db] findMaster sky130_fd_sc_hd__a211oi_4]
require {$stronger ne "NULL"} "The stronger compatible a211oi_4 master is unavailable."
require {[$data_driver swapMaster $stronger]} "Data-driver master swap failed."
puts $report "Observed data-net closure: _1358_ a211oi_2 -> a211oi_4; Boolean function/pin names unchanged."
close $report

# Keep the v21 clock repair intact; give the ui_in[2] data net fanout headroom
# before downstream antenna insertion and standard setup/hold repair.
source [file join [file dirname [info script]] input4_fanout.tcl]

# The TT macro uses VDD_PIN/GND_PIN as its actual supply net names. Generic
# OpenROADStep does not derive VDD_NET/GND_NET as the standard resizer step does.
set ::env(VDD_NET) $::env(VDD_PIN)
set ::env(GND_NET) $::env(GND_PIN)
require {[$block findNet $::env(VDD_NET)] ne "NULL"} "Expected existing VPWR supply."
require {[$block findNet $::env(GND_NET)] ne "NULL"} "Expected existing VGND supply."
source $::env(SCRIPTS_DIR)/openroad/common/set_global_connections.tcl
set_global_connections
estimate_parasitics -placement
source $::env(SCRIPTS_DIR)/openroad/common/dpl.tcl
estimate_parasitics -placement
set_propagated_clock [all_clocks]
write_views
puts "Kalman clock-root split complete: root 16 -> 2; two new branches 8/8; limit 10 unchanged."
