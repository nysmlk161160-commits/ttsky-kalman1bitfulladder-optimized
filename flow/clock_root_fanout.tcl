# The shared adder can change mapped instance names and CTS clustering.
# Repair the clock and public input nets by their connectivity.
source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
read_current_odb
source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
set_propagated_clock [all_clocks]

proc input_terms {net} {
    set terms [list]
    foreach pin [$net getITerms] {
        if {[$pin getIoType] eq "INPUT"} { lappend terms $pin }
    }
    return $terms
}

proc spatial_order {terms} {
    set rows [list]
    set xs [list]
    set ys [list]
    foreach pin $terms {
        set inst [$pin getInst]
        lassign [$inst getLocation] x y
        lappend xs $x
        lappend ys $y
        lappend rows [list [$inst getName] $pin $x $y]
    }
    set xs [lsort -integer $xs]
    set ys [lsort -integer $ys]
    set axis [expr {[lindex $xs end]-[lindex $xs 0] >= [lindex $ys end]-[lindex $ys 0] ? 2 : 3}]
    return [lsort -integer -index $axis [lsort -index 0 $rows]]
}

proc insert_branch {block driver upstream rows master_name name signal_type} {
    set master [[ord::get_db] findMaster $master_name]
    if {$master eq "NULL"} { error "Missing branch buffer $master_name" }
    set buffer [odb::dbInst_create $block $master $name]
    set branch [odb::dbNet_create $block "${name}_net"]
    $branch setSigType $signal_type
    [$buffer findITerm A] connect $upstream
    [$buffer findITerm X] connect $branch
    set sumx 0
    set sumy 0
    foreach row $rows {
        lassign $row inst_name pin x y
        $pin disconnect
        $pin connect $branch
        incr sumx $x
        incr sumy $y
    }
    set count [llength $rows]
    lassign [$driver getLocation] dx dy
    set bx [expr {int(($dx+$sumx/double($count))/2)}]
    set by [expr {int(($dy+$sumy/double($count))/2)}]
    $buffer setOrient R0
    $buffer setLocation $bx $by
    $buffer setPlacementStatus PLACED
    if {[llength [input_terms $branch]] != $count} {
        error "Unexpected branch load count: $name"
    }
}

set block [ord::get_db_block]
set limit $::env(MAX_FANOUT_CONSTRAINT)
if {$limit != 10} { error "Expected v24 fanout limit 10" }
set root [$block findInst clkbuf_0_clk]
if {$root eq "NULL"} { error "Missing CTS clock root" }
set root_net [[$root findITerm X] getNet]
set terms [input_terms $root_net]
set count [llength $terms]
set report [open "$::env(STEP_DIR)/clock_root_fanout.rpt" w]
puts $report "Clock root fanout before repair: $count, limit $limit"
if {$count > $limit} {
    set rows [spatial_order $terms]
    set groups [expr {($count+7)/8}]
    for {set i 0} {$i < $groups} {incr i} {
        set start [expr {$i*$count/$groups}]
        set stop [expr {($i+1)*$count/$groups-1}]
        set members [lrange $rows $start $stop]
        insert_branch $block $root $root_net $members sky130_fd_sc_hd__clkbuf_8 "clk_fanout_stage_$i" CLOCK
        puts $report "Clock branch $i fanout: [llength $members]"
    }
}
set root_count [llength [input_terms $root_net]]
if {$root_count > $limit} { error "Clock root fanout still exceeds $limit" }
puts $report "Clock root fanout after repair: $root_count"

# The related v24/v25 implementations needed antenna headroom on these ports.
# Leave unrelated ABC-mapped data gates to the standard repair and final checks.
foreach {port branch_name threshold} {
    {ui_in[2]} input4_fanout_stage 7
    {uio_in[2]} input12_fanout_stage 9
} {
    set port_net [[$block findBTerm $port] getNet]
    set input_loads [input_terms $port_net]
    if {[llength $input_loads] != 1} {
        puts $report "$port has no dedicated input buffer to split"
        continue
    }
    set driver [[lindex $input_loads 0] getInst]
    set master_name [[$driver getMaster] getName]
    if {![string match "sky130_fd_sc_hd__clkdlybuf*" $master_name] &&
        ![string match "sky130_fd_sc_hd__buf_*" $master_name]} {
        puts $report "$port is connected to $master_name"
        continue
    }
    set net [[$driver findITerm X] getNet]
    set terms [input_terms $net]
    set count [llength $terms]
    puts $report "$port uses [$driver getName], fanout $count"
    if {$count < $threshold} { continue }
    set moved [lrange [spatial_order $terms] [expr {$count/2}] end]
    insert_branch $block $driver $net $moved sky130_fd_sc_hd__buf_4 $branch_name SIGNAL
    puts $report "$port split fanouts: [llength [input_terms $net]] / [llength $moved]"
}
close $report

set ::env(VDD_NET) $::env(VDD_PIN)
set ::env(GND_NET) $::env(GND_PIN)
source $::env(SCRIPTS_DIR)/openroad/common/set_global_connections.tcl
set_global_connections
estimate_parasitics -placement
source $::env(SCRIPTS_DIR)/openroad/common/dpl.tcl
estimate_parasitics -placement
set_propagated_clock [all_clocks]
write_views
