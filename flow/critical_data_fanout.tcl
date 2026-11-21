# Reparent the three cascaded, noninverting fanout branches on the
# post-route critical path of v27 run 44877685726.
foreach {source_name output_pin parent_name child_name} {
    _1423_ Q fanout51 fanout50
    _0706_ Y fanout44 fanout42
    _0894_ X fanout18 fanout16
} {
    set driver [$block findInst $source_name]
    set parent [$block findInst $parent_name]
    set child [$block findInst $child_name]
    if {$driver eq "NULL" || $parent eq "NULL" || $child eq "NULL"} {
        error "Missing verified critical-path branch $source_name / $parent_name / $child_name"
    }
    foreach buffer [list $parent $child] {
        if {[[$buffer getMaster] getName] ne "sky130_fd_sc_hd__clkdlybuf4s25_1"} {
            error "Unexpected master on [$buffer getName]"
        }
    }
    set source_net [[$driver findITerm $output_pin] getNet]
    set parent_net [[$parent findITerm X] getNet]
    set child_input [$child findITerm A]
    if {[[$parent findITerm A] getNet] ne $source_net ||
        [$child_input getNet] ne $parent_net ||
        [$source_net getSigType] ne "SIGNAL"} {
        error "Critical-path connectivity changed for $child_name"
    }
    set old_count [llength [input_terms $source_net]]
    if {$old_count >= $limit} {
        error "No fanout headroom on $source_name/$output_pin"
    }
    $child_input disconnect
    $child_input connect $source_net
    puts $report "$source_name/$output_pin now drives $parent_name/A and $child_name/A in parallel; root fanout $old_count -> [llength [input_terms $source_net]]"
}
