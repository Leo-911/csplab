select_routes -shapes followpin -via_cell {VIAGEN12* VIAGEN23*}
    update_power_via -bottom_layer M1 -top_layer M4 -update_vias 1 -selected_vias 1  -via_scale_height 70 -via_scale_width 130
deselect_obj -all
select_routes -shapes followpin -via_cell {VIAGEN34*}
    update_power_via -bottom_layer M1 -top_layer M4 -update_vias 1 -selected_vias 1  -via_scale_height 100 -via_scale_width 130

