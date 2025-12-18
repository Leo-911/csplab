
set corelly [get_db designs .core_bbox.ll.y]
set corellx [get_db designs .core_bbox.ll.x]
set site_h [get_db site:core .size.y]
set site_w [get_db site:core .size.x]
set insts [get_db insts -if {(.base_cell.base_class == block) && (.name != u_pll)}]
#set insts [get_db selected]
foreach inst $insts {
    set llx [get_db $inst .bbox.ll.x]
    set lly [get_db $inst .bbox.ll.y]
    set orient [get_db $inst .orient]

    set site_hnum [expr int(($lly-$corelly+$site_h/2)/$site_h)]
    set lly_snap [expr $site_hnum*$site_h + $corelly]

    set site_wnum [expr int(($llx-$corellx+$site_w/2)/$site_w)]
    set llx_snap [expr $site_wnum*$site_w + $corellx]
    #puts "snap $inst from $llx to $lly_snap"
    place_inst $inst $llx_snap $lly_snap $orient
}
gui_redraw

