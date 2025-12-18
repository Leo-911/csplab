#== Lab step 7 ==
source -quiet lab_script/design_import.tcl
#== Lab step 8 ==
source -quiet lab_script/create_pg_pad.tcl
source -quiet lab_script/connect_global_net.tcl
source -quiet lab_script/read_scan_def.tcl
#== Lab step 9 ==
source -quiet lab_script/config.tcl
source -quiet lab_script/config_cts.tcl
write_db dbs/init.enc

#== Lab step 10 ~ step 31 ==
source -quiet lab_script/floorplan.tcl

#== Lab step 32 ==
source -quiet lab_script/add_endcaps.tcl
#== Lab step 33 ==
source -quiet lab_script/add_well_taps.tcl
#== Lab step 34 ==
place_design
place_opt_design
write_db dbs/prects.enc
#== Lab step 35 ==
reset_clock_latency [all_clocks]
ccopt_design
write_db dbs/cts.enc
#== Lab step 36 ==
opt_design -post_cts
opt_design -post_cts -hold
opt_design -post_cts -hold -setup
#== Lab step 37 ==
if {[get_db add_tieoffs_cells] ne "" } {
    delete_tieoffs
    add_tieoffs -matching_power_domains true
}
write_db dbs/postcts.enc
#== Lab step 38 ==
route_design
write_db dbs/route.enc
#== Lab step 39 ==
set_db delaycal_enable_si true
opt_design -post_route -setup -hold
opt_design -post_route -hold
write_db dbs/postroute.enc

#== Lab step 40 ==
opt_signoff -all
#  opt_signoff -hold
#  write_db dbs/signoff.enc
#  time_design -sign_off
#  time_design -sign_off -hold
#== Lab step 41 ~ setp ==
source -quiet lab_script/finish_design.tcl
write_db dbs/finish.enc


