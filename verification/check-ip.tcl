# Run in a scratch directory: vivado -mode batch -source /path/to/check-ip.tcl
set app_root [file normalize [file join [file dirname [info script]] ..]]
create_project -in_memory -part xc7a100tcsg324-1
set_property ip_repo_paths [list $app_root] [current_project]
update_ip_catalog -rebuild
set vlnv eccelerators.com:samples:webapp:1.0
if {[llength [get_ipdefs -all $vlnv]] != 1} { error "Missing or ambiguous $vlnv" }
create_bd_design check_webapp
create_bd_cell -type ip -vlnv $vlnv webapp_0
foreach name {Clk nRst UartRx UartTx EthernetFrameDetected} {
    if {[llength [get_bd_pins -quiet webapp_0/$name]] != 1} { error "Missing pin $name" }
}
set axi [get_bd_intf_pins webapp_0/M_AXI]
if {[get_property MODE $axi] ne "Master"} { error "M_AXI is not a master" }
if {[get_property CONFIG.PROTOCOL $axi] ne "AXI4LITE"} { error "M_AXI is not AXI4-Lite" }
if {[llength [get_bd_addr_spaces -quiet webapp_0/M_AXI]] != 1} { error "Missing AXI address space" }
if {[get_property CONFIG.POLARITY [get_bd_pins webapp_0/nRst]] ne "ACTIVE_LOW"} { error "Wrong reset polarity" }
if {[get_property CONFIG.FREQ_HZ [get_bd_pins webapp_0/Clk]] != 100000000} { error "Wrong clock frequency" }
puts "PASS: Arty WebApp IP identity, pins, AXI address space, clock and reset"
close_project
