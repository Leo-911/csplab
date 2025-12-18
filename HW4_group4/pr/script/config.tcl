
#set_db net:io_rte .skip_routing true
#set_db place_detail_legalization_inst_gap 2

delete_assigns
set_db init_no_new_assigns 1

set_db design_process_node 16
set_db design_top_routing_layer M9
set_db design_bottom_routing_layer M2

create_basic_path_groups -reset
create_basic_path_groups -expanded

set_db timing_analysis_type ocv
set_db timing_analysis_cppr both
set_timing_derate -max -early 0.8 -late 1.0
set_timing_derate -min -early 1.0 -late 1.1

set_db add_tieoffs_max_fanout 10
set_db add_tieoffs_max_distance 100
set_db add_tieoffs_cells {TIEHBWP20P90 TIELBWP20P90 }

#set_db add_fillers_preserve_user_order true
#set_db add_fillers_cells {FILL64BWP16P90 DCAP32BWP16P90 DCAP16BWP16P90 DCAP8BWP16P90 DCAP4BWP16P90 FILL2BWP16P90 FILL2BWP16P90LVT FILL1BWP16P90 FILL1BWP16P90LVT}

#set_db route_design_antenna_diode_insertion true
#set_db route_design_antenna_cell_name {}

# POWER ANALYSIS
# source -quiet lab_script/set_activity.tcl
# set_db power_write_db false
# set_db power_write_static_currents false

set_db design_early_clock_flow        true
set_db place_detail_use_no_diffusion_one_site_filler true
set_db place_detail_no_filler_without_implant true
set_db place_detail_check_cut_spacing true
set_db place_detail_check_route true
set_db design_cong_effort high
set_db place_detail_honor_inst_pad true
set_db place_detail_color_aware_legal true


