#== Lab step 41 ==
add_fillers
source ../script/post_via_drop.tcl
#source ../script/fix_followpin_via13.tcl
set_db check_drc_limit 10000
check_drc
source ../script/fix_manual_via12.tcl
source ../script/create_bump.tcl

##create_gui_text -label VDDPST -layer CUSTOM_AP -pt {105 1890} -height 10
#create_gui_text -label 1.8 -layer CUSTOM_AP_high -pt {125 1890} -height 10
#create_gui_text -label 1.8 -layer CUSTOM_AP_low -pt  {125 1890} -height 10
##create_gui_text -label VSSPST -layer CUSTOM_AP -pt {45 1850} -height 10
#create_gui_text -label 0 -layer CUSTOM_AP_high -pt {45 1850} -height 10
#create_gui_text -label 0 -layer CUSTOM_AP_low -pt  {45 1850} -height 10
##create_gui_text -label VDD -layer CUSTOM_AP -pt {105 1800} -height 10
#create_gui_text -label 0.8 -layer CUSTOM_AP_high -pt {125 1800} -height 10
#create_gui_text -label 0.8 -layer CUSTOM_AP_low -pt  {125 1800} -height 10
##create_gui_text -label VSS -layer CUSTOM_AP -pt {45 1775} -height 10
#create_gui_text -label 0 -layer CUSTOM_AP_high -pt {45 1775} -height 10
#create_gui_text -label 0 -layer CUSTOM_AP_low -pt  {45 1775} -height 10

source ../script/create_chipBoundary.tcl
delete_empty_hinsts
source ../script/write_stream.tcl
source ../script/write_netlist.tcl
write_db dbs/write_stream.enc 
#write_db -sdc -oa_view write_stream 
source ../script/write_sdf.tcl

check_connectivity -type regular -error 1000 -warning 50

#write_db dbs/write_stream.enc -rc_extract
#report_summary -no_html -out_dir summary_report -out_file summary_report/qor.rpt
