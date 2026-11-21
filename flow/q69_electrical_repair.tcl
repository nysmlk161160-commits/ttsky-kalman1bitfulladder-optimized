# v30 physical attempt 2: preserve Q6.9 RTL and every implementation limit.
# The first routed result added 3/5/4 antenna diode loads to these eight-load
# input-buffer nets. Split the logical sinks before routing to leave headroom.
foreach {port branch_name} {
    {ui_in[0]} q69_input0_fanout_stage
    {ui_in[3]} q69_input3_fanout_stage
    {ui_in[4]} q69_input4_fanout_stage
} {
    set term [$block findBTerm $port]
    if {$term eq "NULL"} { error "Missing Q6.9 input port $port" }
    set loads [input_terms [$term getNet]]
    if {[llength $loads] != 1} { error "Expected dedicated input buffer on $port" }
    set driver [[lindex $loads 0] getInst]
    if {[[$driver getMaster] getName] ne "sky130_fd_sc_hd__clkdlybuf4s25_1"} {
        error "Unexpected Q6.9 input buffer on $port"
    }
    set net [[$driver findITerm X] getNet]
    set terms [input_terms $net]
    if {[llength $terms] != 8} { error "Expected eight pre-route sinks on $port" }
    set moved [lrange [spatial_order $terms] 4 end]
    insert_branch $block $driver $net $moved sky130_fd_sc_hd__buf_4 $branch_name SIGNAL
    if {[llength [input_terms $net]] != 5 || [llength $moved] != 4} {
        error "Unexpected input split on $port"
    }
    puts $report "Q6.9 $port: eight logical sinks -> root5 / branch4 ($branch_name)"
}

# One AO21-inverting driver caused all eleven slew reports and the one
# capacitance report. The exact unchanged synthesis has ten sinks on _0248_.
# Find its driver by connectivity and guard the mapping before changing size.
set critical_net [$block findNet _0248_]
set critical_driver [signal_driver $critical_net]
if {$critical_driver eq "NULL"} { error "Missing Q6.9 electrical repair net _0248_" }
if {[[$critical_driver getMaster] getName] ne "sky130_fd_sc_hd__a21oi_2"} {
    error "Unexpected Q6.9 electrical driver; recheck the mapped netlist"
}
if {[llength [input_terms $critical_net]] != 10} {
    error "Unexpected Q6.9 electrical repair load count"
}
set stronger_master [[ord::get_db] findMaster sky130_fd_sc_hd__a21oi_4]
if {$stronger_master eq "NULL"} { error "Missing Q6.9 a21oi_4 replacement" }
if {![$critical_driver swapMaster $stronger_master]} {
    error "Q6.9 electrical driver replacement failed"
}
puts $report "Q6.9 [$critical_driver getName]/Y on [$critical_net getName]: a21oi_2 -> a21oi_4, ten sinks retained"
# Parent step reconnects power, legalizes placement and estimates parasitics.
# Normal post-CTS timing repair and the full routed nine-corner checks follow.
