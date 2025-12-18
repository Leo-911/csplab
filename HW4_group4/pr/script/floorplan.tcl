
set floorplan_file "CHIP.fp"
#write_io_file CHIP.save.io

if {[file exists $floorplan_file]} {
    read_floorplan $floorplan_file
    create_floorplan -site core -core_density_size 1 0.7 80.0 80.0 80.0 80.0
    read_io_file ../../design/CHIP.io -no_die_size_adjust
    source lab_script/swap_io_hv.tcl
    do_swap_io
    read_floorplan $floorplan_file
    snap_floorplan -all
    set_db  [get_db insts -if {.base_cell.base_class == pad}] .place_status  fixed
    set_instance_placement_status -all_hard_macros -status fixed
} else {
#== Lab step 10 ==
    read_io_file ../../design/CHIP.io
    create_floorplan -site core -core_density_size 1 0.7 80.0 80.0 80.0 80.0
    read_io_file ../../design/CHIP.io -no_die_size_adjust
    snap_floorplan -all
    source lab_script/swap_io_hv.tcl
    do_swap_io
    create_floorplan -site core -box_size 0.0 0.0 627.39 626.496 50.04 49.968 577.35 576.48 130.05 129.984 497.34 496.32

    read_io_file ../../design/CHIP.io -no_die_size_adjust
    check_floorplan 
    snap_floorplan -all
    check_floorplan -out_file check_floorplan.log
    write_db dbs/floorplan.enc

#== Lab step 11 ==
    #set_db inst:IO_PG4 .orient MY90
    #set_db inst:CORE_PG2 .orient MX90
    #set_db inst:CORE_PG3 .orient MY
    #set_db inst:IO_PG2 .orient MX90
#== Lab step 12 ==
    source lab_script/create_bump.tcl
    source lab_script/delete_bump.tcl
#== Lab step 13 ==
#== Lab step 14 ==
    source lab_script/add_io_fillers.tcl
    #fix io
    set_db  [get_db insts -if {.base_cell.base_class == pad}] .place_status  fixed
    create_place_halo -halo_deltas {0.96 0.96 0.96 0.96} -all_blocks
    create_route_halo -all_blocks -space 0.18 -bottom_layer M1 -top_layer M9
    if {[file exists golden_mimic_power_mesh.tcl]} {
        puts "use golden_mimic_power_mesh.tcl"
        source golden_mimic_power_mesh.tcl
    } else {
        set_macro_place_constraint -pg_resource_model "M1 0.1 M2 0.1 M3 0.1 M4 0.1 M5 0.1 M6 0.1 M7 0.1 M8 0.1 M9 0.1"
    }
#== Lab step 15 ==
    source lab_script/create_relative_floorplan.tcl
#== Lab step 16 ==
    source lab_script/set_macro_place_constraint.tcl
    place_design -concurrent_macros
#== Lab step 17 ==
    place_macro_detail
    #pack_align_macros
    #source lab_script/snap_block_to_raw.tcl
    #fix sram
    set_instance_placement_status -all_hard_macros -status fixed
    delete_relative_floorplan -all
#== Lab step 18 ==
    set_db finish_floorplan_active_objs   [list macro soft_blockage core]
    finish_floorplan  -fill_place_blockage soft 20.0
    set_db [get_db insts -if {.base_cell.class == core}] .place_status unplaced
    write_db dbs/floorplan.enc
    #write_db  -oa_lib_cell_view {implementation CHIP before_pns}
#== Lab step 19 ~ step 30 ==
    source lab_script/pns.tcl
    runPGPlan
#== Lab step 31 ==
    #write_db dbs/powerplan.enc
    #write_db  -oa_lib_cell_view {implementation CHIP pns}
    write_floorplan $floorplan_file
    #place_design
}

