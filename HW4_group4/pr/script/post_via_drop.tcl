set_db generate_special_via_rule_preference default
select_routes -shapes stripe -layer M2 -sub_class "manual_rail"
update_power_vias -bottom_layer M1 -top_layer M2 -selected_wires 1 -add_vias 1 -orthogonal_only 0 -via_using_exact_crossover_size 1 -skip_via_on_pin {pad cover standardcell}  -skip_via_on_wire_shape {Blockring Blockwire Iowire Padring Ring Fillwire Noshape} -user_class "VIA12_Manual" -split_long_via {0.2 0.2 -1 -1}

update_power_vias -bottom_layer M2 -top_layer M3 -selected_wires 1 -add_vias 1 -orthogonal_only 1 -via_using_exact_crossover_size 1 -skip_via_on_pin {pad cover standardcell}  -skip_via_on_wire_shape {Blockwire Iowire Padring Ring Fillwire Noshape}   -user_class "VIA23_Manual"
