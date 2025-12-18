#write_sdf output/CHIP_ff0p88v125c.sdf -max_view AV_func_ff0p88v125c -typical_view AV_func_ff0p88v125c -min_view  AV_func_ff0p88v125c -map_removal -recompute_delaycal
#write_sdf output/CHIP_ss0p72vm40c.sdf -max_view AV_func_ss0p72vm40c -typical_view AV_func_ss0p72vm40c -min_view  AV_func_ss0p72vm40c -map_removal -recompute_delaycal

#source my_script/write_netlist.tcl

#write_sdf output/CHIP_pr.sdf -max_view AV_func_ff0p88v125c -typical_view AV_func_ff0p88v125c -min_view  AV_func_ff0p88v125c -map_removal -recompute_delaycal

write_sdf output/CHIP_pr125c.sdf -max_view AV_func_ss0p72v125c -typical_view AV_func_ff0p88v125c -min_view  AV_func_ff0p88v125c -map_removal -recompute_delaycal
write_sdf output/CHIP_pr40c.sdf -max_view AV_func_ss0p72vm40c -typical_view AV_func_ff0p88vm40c -min_view  AV_func_ff0p88vm40c -map_removal -recompute_delaycal