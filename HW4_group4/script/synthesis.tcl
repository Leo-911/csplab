#   Read in top module
#read_file -autoread -top CHIP {../src/ ../include}
analyze -format sverilog {../src/CHIP.v}
elaborate CHIP
# SET POWER INTENT and ENVIRONMENT ###################################
current_design CHIP
link

#   Set Design Environment
set_host_options -max_core 8
source ../script/DC.sdc
check_design
uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
set_max_area 0


#   Synthesize circuit
compile -map_effort high -area_effort high
#compile -map_effort high -area_effort high -inc
# ungroup -all -flatten
# compile_ultra -retime
# compile_ultra -retime
# compile_ultra -retime
# compile_ultra -inc

# optimze_netlist -area
# optimze_netlist -area
# optimze_netlist -area
#   Create Report
#timing report(setup time)
report_timing -path full -delay max -nworst 1 -max_paths 1 -significant_digits 4 -sort_by group > ../syn/timing_max_rpt.txt
#timing report(hold time)
report_timing -path full -delay min -nworst 1 -max_paths 1 -significant_digits 4 -sort_by group > ../syn/timing_min_rpt.txt
#area report
report_area -nosplit > ../syn/area_rpt.txt
#report power
report_power -analysis_effort low > ../syn/power_rpt.txt

#   Save syntheized file
write -hierarchy -format verilog -output {../syn/CHIP_syn.v}
write_file -format verilog -hier -output ../pr/Prepare/CHIP_syn.v
#write_sdf -version 1.0 -context verilog {../syn/top_syn.sdf}
write_sdf -version 3.0 -context verilog {../syn/CHIP_syn.sdf}
write_sdf -version 2.1 -context verilog -load_delay net ../pr/Prepare/CHIP_syn.sdf
write_sdc -version 2.1 ../syn/CHIP.sdc
write_sdc -version 2.1 ../pr/Prepare/CHIP.sdc