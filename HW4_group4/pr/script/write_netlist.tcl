delete_empty_hinsts

write_netlist output/CHIP_pr.v
set DECAP_CELL_LIST [get_db [get_db base_cells DCAP*] .name]
set PVDD_CELL_LIST [get_db [get_db base_cells PVDD*] .name]
set FILLER_CELL_LIST [get_db [get_db base_cells FILL*] .name]
set PFILLER_CELL_LIST [get_db [get_db base_cells PFILL*] .name]
set PCORNER_CELL_LIST [get_db [get_db base_cells PCORNER*] .name]
write_netlist -include_pg_ports  -include_phys_cells "$DECAP_CELL_LIST $PVDD_CELL_LIST" -exclude_insts_of_cells "$FILLER_CELL_LIST $PFILLER_CELL_LIST $PCORNER_CELL_LIST" -exclude_leaf_cells output/CHIP_pg.v

