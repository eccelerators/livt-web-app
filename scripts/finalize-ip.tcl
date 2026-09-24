# Explicit IP-XACT metadata: Vivado does not retain all VHDL-2008 attributes.
set app_root [file normalize [file join [file dirname [info script]] ..]]
ipx::open_core [file join $app_root package component.xml]
set core [ipx::current_core]
proc bus_parameter {core interface name value} {
    set bus [ipx::get_bus_interfaces $interface -of_objects $core]
    set parameter [ipx::get_bus_parameters $name -of_objects $bus]
    if {[llength $parameter] == 0} { set parameter [ipx::add_bus_parameter $name $bus] }
    set_property value $value $parameter
}
bus_parameter $core M_AXI PROTOCOL AXI4LITE
bus_parameter $core M_AXI ADDR_WIDTH 13
bus_parameter $core M_AXI DATA_WIDTH 32
bus_parameter $core M_AXI READ_WRITE_MODE READ_WRITE
bus_parameter $core Clk FREQ_HZ 100000000
bus_parameter $core Clk ASSOCIATED_BUSIF M_AXI
bus_parameter $core Clk ASSOCIATED_RESET nRst
set reset [ipx::get_bus_interfaces nRst -of_objects $core]
if {[llength $reset] == 0} {
    set reset [ipx::add_bus_interface nRst $core]
    set_property bus_type_vlnv xilinx.com:signal:reset:1.0 $reset
    set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 $reset
    set_property interface_mode slave $reset
    set mapping [ipx::add_port_map RST $reset]
    set_property physical_name nRst $mapping
}
bus_parameter $core nRst POLARITY ACTIVE_LOW
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
ipx::unload_core $core
source [file join $app_root verification check-ip.tcl]
