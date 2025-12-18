#set_db check_drc_limit 10000
#check_drc

set errors [get_db current_design .markers -if {.subtype == Cut_Spacing }]
foreach marker $errors {
   #puts $marker
   set mbox [get_db $marker .bbox]
   foreach via [get_obj_in_area -areas $mbox -obj_type special_via] {
      if { [get_db $via .user_class] == "VIA12_Manual" } {
         delete_obj $via
      }
   }
}


