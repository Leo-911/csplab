set_db write_stream_text_size 10

set streamOutMapLink ../Prepare/ADFP_Executable_Package/Collaterals/Tech/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_Gdsout_11M.10a.map

set_db write_stream_text_size 10
if {! [file exists stream_out_map]} {
    set streamOutMapFile [file dirname [file normalize $streamOutMapLink/___]]
    if [file exists $streamOutMapFile] {
       file copy $streamOutMapFile stream_out_map
       set outfile [open stream_out_map a]
       puts  $outfile "CUSTOM_CB CUSTOM 108 250"
       #puts  $outfile "CUSTOM_CB CUSTOM 108 0"
       close $outfile
    }
}

write_stream output/CHIP.gds -map_file stream_out_map -lib_name DesignLib \
      -merge { \
           ../Prepare/ADFP_Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/GDS/N16ADFP_StdCell.gds \
          ../Prepare/ADFP_Executable_Package/Collaterals/IP/stdio/N16ADFP_StdIO/GDS/N16ADFP_StdIO.gds \
          ../Prepare/ADFP_Executable_Package/Collaterals/IP/bondpad/N16ADFP_BondPad/GDS/N16ADFP_BondPad.gds \
      } \
      -uniquify_cell_names -unit 1000 -mode all

#create_pin_text -cells aiot_mcu label_loc.txt