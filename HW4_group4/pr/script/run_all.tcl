set_multi_cpu_usage -local_cpu 100
set_multi_cpu_usage -remote_host 4
set_multi_cpu_usage -cpu_per_remote_host 8
set_layer_preference CUSTOM_CB -stipple none
set_db read_db_file_check false

# ==================================================================
# Design Import
# ==================================================================
# page 11  
#(1)
source ../script/design_import.tcl 

# load config
source ../script/config.tcl

# page 12. 
#(2)
source ../script/create_pg_pad.tcl
#(3)
source ../script/connect_global_net.tcl

# load cts config
source ../script/config_cts.tcl

# write dbs 00_init
write_db ../dbs/00_init

# ===================================================================
# Floorplan
# ===================================================================
#!!!!!!!!!!!!!!!!!底下flooplan部分只是參考，需要自己完成!!!!!!!!!!!!!!!!!
# page 15
read_io_file ../Prepare/CHIP.io –no_die_size_adjust
#(4)
source ../script/swap_io_hv.tcl
#(5)
do_swap_io

# page 18
snap_floorplan -all

check_floorplan

# page 20 ~ 30
create_bump -cell PAD80APB_LF_BU -pitch {154 154}  -location {80 80} -pattern_array {5 5} -name_format "Bump_%r_%c"
set_db flip_chip_route_width 12
set_db flip_chip_top_layer AP
set_db flip_chip_bottom_layer AP
set_db flip_chip_connect_power_cell_to_bump true
set_db flip_chip_multiple_connection multiple_pads_to_bump

assign_pg_bumps -nets VDDPST -bumps {Bump_1_2}
assign_pg_bumps -nets VDDPST -bumps {Bump_2_3}
assign_pg_bumps -nets VDDPST -bumps {Bump_3_4}
assign_pg_bumps -nets VDDPST -bumps {Bump_4_3}

assign_pg_bumps -nets VDD -bumps {Bump_1_3}
assign_pg_bumps -nets VDD -bumps {Bump_1_5}

assign_pg_bumps -nets VDD -bumps {Bump_5_4}
assign_pg_bumps -nets VDD -bumps {Bump_3_2}

assign_pg_bumps -nets VSS -bumps {Bump_2_2}
assign_pg_bumps -nets VSS -bumps {Bump_3_3}
assign_pg_bumps -nets VSS -bumps {Bump_4_5}

assign_bumps

route_flip_chip -target connect_bump_to_pad -route_engine global_detail -bottom_layer AP -top_layer AP -route_width 12
#(6)
source ../script/delete_bump.tcl

# page 31
#(7)
source ../script/add_io_fillers.tcl
set_db  [get_db insts -if {.base_cell.base_class == pad}] .place_status  fixed

# write dbs 01_floorplan
#(8)
write_db ../dbs/01_floorplan

# ===================================================================
# Powerplan
# ===================================================================
#!!!!!!!!!!!!!!!!!power ring的部分可以自行調整要疊幾層metal跟要圍幾圈!!!!!!!!!!!!!!!!!
#(9)
source ../script/pns.tcl

# page 33
#(10 ~ 12)
createPowerRing   {VDD VSS}   M8     M7     2     1.1       0.8    13
createPowerRing   {VDD VSS}   M6     M5     2     1.1      0.8    13
edit_trim_routes -nets {VDD VSS} -layers {M8 M7 M6 M5}

# page 34~35
set_db route_special_via_connect_to_shape { ring }
route_special -connect pad_pin -layer_change_range { M1(1) M9(9) } -block_pin_target nearest_target -pad_pin_port_connect {all_port all_geom} -pad_pin_target nearest_target -pad_pin_layer_range { M1(1) M4(4) } -allow_jogging 0 -crossover_via_layer_range { M1(1) M9(9) } -nets { VDD VSS } -allow_layer_change 1 -target_via_layer_range { M1(1) M9(9) }
check_drc

# page 37
#(13)
source ../script/create_padpin_blockage.tcl

# page 38
#(14 ~ 23)
createPowerStripe  "V" "M9"  [list VDD VSS]    1.8    1.8    1.8     7.2    "none"
createPowerStripe  "H" "M8"  [list VSS]        1.44   0.864   0      2.88   "half_grid"
createPowerStripe  "H" "M8"  [list VDD]        0      0.864   0      2.88   "half_grid"
createPowerStripe  "V" "M7"  [list VSS]        3.6    0.24    0      7.2    "grid"
createPowerStripe  "V" "M7"  [list VDD]        7.2    0.24    0      7.2    "grid"
createPowerStripe  "H" "M6"  [list VSS]        3.6    0.24    0      7.2    "grid"
createPowerStripe  "H" "M6"  [list VDD]        0      0.24    0      7.2    "grid"
createPowerStripe  "V" "M5"  [list VSS]        3.6    0.24    0      7.2    "grid"
createPowerStripe  "V" "M5"  [list VDD]        7.2    0.24    0      7.2    "grid"

# follow pin
set_db route_special_via_connect_to_shape { ring stripe }
route_special -connect core_pin -layer_change_range { M1(1) M5(5) } -block_pin_target nearest_target -core_pin_target first_after_row_end -allow_jogging 0 -crossover_via_layer_range { M1(1) M5(5) } -nets { VDD VSS } -allow_layer_change 1 -target_via_layer_range { M1(1) M5(5) } 


# page 38
#(24 ~ 25)
delete_obj [get_db route_blockages {RBKM234}]
delete_obj [get_db route_blockages RBKPADPIN]

# page 
#(26 ~ 27)
add_power_mesh_colors
create_pg_model_for_macro_place -file golden_mimic_power_mesh.tcl

# page 40
set_db check_drc_limit 100000
check_drc
fix_via -min_step
# check again, the drc will be zero
check_drc

# write dbs 02_powerplan
write_db ../dbs/02_powerplan

# ===================================================================
# Placement
# ===================================================================
# !!!!!!!!!!!!!!!!!placement部分自行優化timing!!!!!!!!!!!!!!!!!
# page 41
#(28 ~ 31)
source ../script/add_endcaps.tcl
source ../script/add_well_taps.tcl
source ../script/config.tcl
source ../script/config_cts.tcl

# page 42
#(32 ~ 33)
place_design
place_opt_design

write_db ../dbs/03_placement

# ===================================================================
# CTS
# ===================================================================
# !!!!!!!!!!!!!!!!!cts部分自行優化timing!!!!!!!!!!!!!!!!!
#(34 ~ 35)
reset_clock_latency [all_clocks]
ccopt_design

# page 46
#(36)
if {[get_db add_tieoffs_cells] ne "" } {
    delete_tieoffs
    add_tieoffs -matching_power_domains true
}

write_db ../dbs/04_cts

# ===================================================================
# Routing
# ===================================================================
# !!!!!!!!!!!!!!!!!routing部分自行優化timing，且嘗試解決drc violation!!!!!!!!!!!!!!!!!
# page 49
set_db route_design_antenna_diode_insertion 1
set_db route_design_with_timing_driven 1
set_db route_design_with_eco 1
set_db route_design_with_si_driven 1
set_db route_design_top_routing_layer 9
set_db route_design_bottom_routing_layer 2
set_db route_design_detail_end_iteration 5
set_db route_design_with_timing_driven true
set_db route_design_with_si_driven true
route_design -global_detail -via_opt -wire_opt

# optional
source ../script/set_inst_padding.tcl
place_detail
route_eco
check_drc

set_db delaycal_enable_si true

# Check DRC
set_db check_drc_limit 100000
check_drc
fix_via -min_step
fix_via -short
fix_via -min_cut
# check again, the drc will be zero
check_drc

delete_obj [get_db route_blockages BumpBlk]
delete_obj [get_db route_blockages {RBKM234}]
delete_obj [get_db route_blockages RBKPADPIN]
delete_obj [get_db place_blockages -if {.type==soft}]

# write dbs 05_routing
write_db ../dbs/05_route

# page 55
#(37)
source ../script/add_fillers_20p90.tcl

# page 56
#(38 ~ 39)
get_db insts -if {.place_status == unplaced}
delete_obj [get_db insts -if {.place_status == unplaced}]

# !!!!!!!!!!!!!!!!!!!!!!!把前面記住的bump重新建立並連線，記得最後要把沒用到的bump刪掉!!!!!!!!!!!!!!!!!!!!!!!!!!!!  
create_bump -cell PAD80APB_LF_BU -pitch {154 154}  -location {80 80} -pattern_array {5 5} -name_format "Bump_%r_%c"
set_db flip_chip_route_width 12
set_db flip_chip_top_layer AP
set_db flip_chip_bottom_layer AP
set_db flip_chip_connect_power_cell_to_bump true
set_db flip_chip_multiple_connection multiple_pads_to_bump

assign_pg_bumps -nets VDDPST -bumps {Bump_1_2}
assign_pg_bumps -nets VDDPST -bumps {Bump_2_3}
assign_pg_bumps -nets VDDPST -bumps {Bump_3_4}
assign_pg_bumps -nets VDDPST -bumps {Bump_4_3}

assign_pg_bumps -nets VDD -bumps {Bump_1_3}
assign_pg_bumps -nets VDD -bumps {Bump_1_5}

assign_pg_bumps -nets VDD -bumps {Bump_5_4}
assign_pg_bumps -nets VDD -bumps {Bump_3_2}

assign_pg_bumps -nets VSS -bumps {Bump_2_2}
assign_pg_bumps -nets VSS -bumps {Bump_3_3}
assign_pg_bumps -nets VSS -bumps {Bump_4_5}


assign_bumps

route_flip_chip -target connect_bump_to_pad -route_engine global_detail -bottom_layer AP -top_layer AP -route_width 12

#(40)
source ../script/create_chipBoundary.tcl

# Check DRC
set_db check_drc_limit 100000
check_drc
fix_via -min_step
fix_via -short
fix_via -min_cut
# check again, the drc will be zero
check_drc

# write dbs 05_routing
write_db ../dbs/05_route

# ==================================================================
# Output Data
# ==================================================================
delete_empty_hinsts

delete_route_halos -all_blocks
delete_place_halo -all_blocks

#page 57
#(41 ~ 43)
source ../script/write_stream.tcl
source ../script/write_netlist.tcl
source ../script/write_sdf.tcl

# write dbs 06_finish
write_db ../dbs/06_finish