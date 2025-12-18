
#set_db check_drc_limit 10000
#check_drc
deselect_obj -all
set errors [get_db current_design .markers -if {.subtype == "Metal_JogToJog_Spacing"}]
foreach marker $errors {
   #puts $marker
   set mbox [get_db $marker .bbox]
   foreach via [get_obj_in_area -areas $mbox -obj_type special_via] {
      if { [get_db $via .shape] == "followpin" } {
         select_obj $via
      }
   }
}
update_power_vias -bottom_layer M1 -top_layer M3  -selected_vias 1 -via_scale_height 85 -update_vias 1 



