# Repair the routed covariance input and cascaded internal fanout buffers
# observed in the first v28 run. Use connectivity across adder mappings.
proc signal_driver {net} {
    if {$net eq "NULL" || [$net getSigType] ne "SIGNAL"} { return "NULL" }
    foreach pin [$net getITerms] {
        if {[$pin getIoType] eq "OUTPUT"} { return [$pin getInst] }
    }
    return "NULL"
}

proc repair_fanout_buffer {inst} {
    return [expr {$inst ne "NULL" &&
        [regexp {^fanout[0-9]+$} [$inst getName]] &&
        [[$inst getMaster] getName] eq "sky130_fd_sc_hd__clkdlybuf4s25_1"}]
}

# In v28, routing raises p[3] from eight logical inputs to eleven by
# attaching antenna diodes. Leave at least two loads of headroom.
set covariance_bit [$block findNet {p[3]}]
if {$covariance_bit eq "NULL"} { set covariance_bit [$block findNet {\p[3]}] }
set covariance_driver [signal_driver $covariance_bit]
if {$covariance_driver ne "NULL"} {
    set terms [input_terms $covariance_bit]
    if {[llength $terms] >= 8} {
        set moved [lrange [spatial_order $terms] [expr {[llength $terms]/2}] end]
        insert_branch $block $covariance_driver $covariance_bit $moved \
            sky130_fd_sc_hd__buf_4 covariance3_fanout_stage SIGNAL
        puts $report "p\[3\] split fanouts: [llength [input_terms $covariance_bit]] / [llength $moved]"
    }
}

# Place serial data fanout branches in parallel when their original
# driver has headroom. Port and reset-buffer trees keep their topology.
set buffers [list]
foreach inst [$block getInsts] {
    if {[repair_fanout_buffer $inst]} { lappend buffers [$inst getName] }
}
foreach name [lsort -dictionary $buffers] {
    set child [$block findInst $name]
    set pin [$child findITerm A]
    set previous [$pin getNet]
    set driver [signal_driver $previous]
    if {![repair_fanout_buffer $driver]} { continue }
    set upstream $previous
    while {[repair_fanout_buffer $driver]} {
        set upstream [[$driver findITerm A] getNet]
        set driver [signal_driver $upstream]
    }
    if {$driver eq "NULL" || [string match "input*" [$driver getName]]} { continue }
    if {[llength [input_terms $upstream]] >= 8} { continue }
    $pin disconnect
    $pin connect $upstream
    puts $report "$name/A: [$previous getName] -> [$upstream getName], driver fanout [llength [input_terms $upstream]]"
}
