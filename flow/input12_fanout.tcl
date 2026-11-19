# The first 60 MHz route added a diode to ten existing loads on input12/X.
# Buffer the six readback mux selects together and leave the write/control
# gates directly driven by the input buffer.
set byte_driver [$block findInst input12]
require {$byte_driver ne "NULL"} "Expected byte-select input buffer input12."
require {[[$byte_driver getMaster] getName] eq "sky130_fd_sc_hd__clkdlybuf4s25_1"} "Unexpected byte-select input buffer master."
set byte_input [[$byte_driver findITerm A] getNet]
require {[$byte_input getName] eq {uio_in[2]}} "Expected input12 to buffer uio_in[2]."
set byte_net [[$byte_driver findITerm X] getNet]
set byte_terms [input_terms $byte_net]
require {[llength $byte_terms] == 10} "Expected ten byte-select loads before repair."
set mux_terms [list]
set mux_x 0
set mux_y 0
foreach pin $byte_terms {
    set inst [$pin getInst]
    if {[[$inst getMaster] getName] eq "sky130_fd_sc_hd__mux4_2" &&
        [[$pin getMTerm] getName] eq "S1"} {
        lappend mux_terms $pin
        lassign [$inst getLocation] x y
        incr mux_x $x
        incr mux_y $y
    }
}
set mux_count [llength $mux_terms]
require {$mux_count == 6} "Expected six mux4 S1 pins for byte selection."
set byte_master [[ord::get_db] findMaster sky130_fd_sc_hd__buf_4]
require {$byte_master ne "NULL"} "Noninverting byte-select buffer master missing."
require {[$block findInst input12_fanout_stage] eq "NULL"} "Byte-select buffer already exists."
require {[$block findNet input12_fanout_branch] eq "NULL"} "Byte-select branch already exists."
set byte_buf [odb::dbInst_create $block $byte_master input12_fanout_stage]
set byte_branch [odb::dbNet_create $block input12_fanout_branch]
$byte_branch setSigType SIGNAL
[$byte_buf findITerm A] connect $byte_net
[$byte_buf findITerm X] connect $byte_branch
set byte_report [open "$::env(STEP_DIR)/input12_fanout.rpt" w]
foreach pin $mux_terms {
    $pin disconnect
    $pin connect $byte_branch
    puts $byte_report "input12_fanout_stage/X -> [[$pin getInst] getName]/S1"
}
lassign [$byte_driver getLocation] byte_x byte_y
set buf_x [expr {int(($byte_x+$mux_x/double($mux_count))/2)}]
set buf_y [expr {int(($byte_y+$mux_y/double($mux_count))/2)}]
$byte_buf setOrient R0
$byte_buf setLocation $buf_x $buf_y
$byte_buf setPlacementStatus PLACED
require {[llength [input_terms $byte_net]] == 5} "Expected four control loads and the new buffer."
require {[llength [input_terms $byte_branch]] == 6} "Expected six buffered mux selects."
puts $byte_report "input12/X fanout 10 -> 5 plus branch fanout 6. Limit 10."
close $byte_report
