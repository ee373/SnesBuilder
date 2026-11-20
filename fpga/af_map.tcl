#yosys -TQd -v 1 -L map.log -c map.tcl

yosys -import

if { ! [info exists IOPAD] } {
  set IOPAD true
}
if { [info exists DESIGN] && ! [info exists TOP_MODULE] } {
  set TOP_MODULE "$DESIGN"
}
if { ! [info exists DESIGN] } {
  set DESIGN "top"
}
if { ! [info exists TOP_MODULE] } {
  set TOP_MODULE "top"
}

set verilogs $argv
if { [ llength $verilogs ] == 0 } {
  set verilogs { "top.v" "sfcbuilder.v" }
}
if { [ llength $verilogs ] == 0 } {
  set verilogs [list ./${DESIGN}.v]
}
foreach verilog $verilogs {
  read_verilog -sv -overwrite -DALTA_SYN "$verilog"
}


#family:
    read_verilog -DALTA_LIB -sv -lib +/agm/rodina/cells_sim.v
    read_verilog -DALTA_SYN -sv +/agm/common/m9k_bb.v
    read_verilog -DALTA_SYN -sv +/agm/common/altpll_bb.v
    read_verilog -DALTA_LIB -sv -lib +/agm/rodina/alta_sim.v
    read_verilog -DALTA_SYN -sv +/agm/rodina/alta_sim.v
    read_verilog -DALTA_SYN -sv +/agm/common/alta_bb.v
    hierarchy -check -top $TOP_MODULE -libdir .

#flatten:
    yosys proc
    flatten
    tribuf -logic
    deminout

    set alta_ips {alta_bram alta_bram9k alta_sram alta_wram alta_pll alta_pllx alta_pllv alta_pllve alta_boot alta_osc alta_mult alta_multm alta_ufm alta_ufms alta_ufml alta_i2c alta_spi alta_irda alta_mcu alta_mcu_m3 alta_saradc alta_adc alta_dac alta_cmp}
    select -none
    foreach alta_ip $alta_ips {
      select -add */t:$alta_ip
    }
    select -set keep_cells %
    select -clear
    setattr -set keep 1 @keep_cells

#coarse:
    synth -run coarse -top $TOP_MODULE

#map_bram:
    memory_libmap -lib local_brams_m9k.txt
    techmap -autoproc -map local_brams_map_m9k.v
    read_verilog -DALTA_SYN -sv +/agm/rodina/alta_sim.v
    hierarchy -check -top $TOP_MODULE
    yosys proc
    flatten

#map_ffram:
    opt -fast -mux_undef -undriven -fine -full
    memory_map
    opt -undriven -fine
    opt -full
    techmap -autoproc -map +/techmap.v -map +/agm/rodina/arith_map.v
    yosys rename -wire -suffix _reg t:$*DFF*
    clean -purge
    setundef -undriven -zero
    abc -markgroups -dff -D 1000

#map_ffs:
    dfflegalize -cell \$_DFFE_PN0P_ 01
    techmap -autoproc -map +/agm/common/ff_map.v

##opts:
    clean -purge
    setundef -undriven -zero
    abc -markgroups -dff -D 1
    opt_expr -mux_undef -undriven -full
    opt_merge
    opt_clean
    autoname

#map_luts:
    abc -lut 4
    clean

#map_cells:
    if { $IOPAD } {
      iopadmap -bits -outpad \$__outpad I:O -inpad \$__inpad O:I -toutpad \$__toutpad E:I:O -tinoutpad \$__tinoutpad E:O:I:IO
    }
    techmap -autoproc -map +/agm/rodina/cells_map.v
    clean -purge
    autoname

#check:
    hierarchy -check
    stat
    check -noinit
    blackbox =A:whitebox

#vqm:
    write_verilog -simple-lhs -bitblasted -attr2comment -defparam -decimal -renameprefix syn_ ${DESIGN}.vqm
