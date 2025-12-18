# delete_routes -shapes iowire  
# delete_obj [get_db bumps]

create_bump -cell PAD80APB_LF_BU -pitch {154 154}  -location {80 80} -pattern_array {4 4} -name_format "Bump_%c_%r"

set_db flip_chip_route_width 12
set_db flip_chip_top_layer AP
set_db flip_chip_bottom_layer AP
set_db flip_chip_connect_power_cell_to_bump true
set_db flip_chip_multiple_connection multiple_pads_to_bump

unassign_bumps -all
assign_pg_bumps -nets VSS -bumps {Bump_3_3 }
assign_pg_bumps -nets VSS -bumps {Bump_2_2 }
assign_pg_bumps -nets VSS -bumps {Bump_2_4 }
assign_pg_bumps -nets VDDPST -bumps {Bump_4_4}
assign_pg_bumps -nets VDD -bumps {Bump_3_2}
assign_pg_bumps -nets VDD -bumps {Bump_2_3}
assign_pg_bumps -nets VDDPST -bumps {Bump_1_2}

# set_db flip_chip_multi_pad_routing_style  star
# set_db flip_chip_honor_bump_connect_target_constraint true
# create_bump_connect_target_constraint -bumps {Bump_2_2 Bump_3_3} -io_inst CORE_PG4 -pin_name VSS

assign_bumps
# delete_routes -shapes iowire
route_flip_chip -target connect_bump_to_pad

#foreach_in_collection net [get_nets -of_objects [get_ports]] {
#    set_dont_touch [get_attr $net full_name]
#    setAttribute -skip_routing true -net [get_attr $net full_name]
#}

