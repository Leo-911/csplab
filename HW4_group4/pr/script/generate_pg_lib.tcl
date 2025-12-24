# voltus -batch -file lab_script/generate_pg_lib.tcl
read_lib -lef \
  ../Prepare/ADFP_Executable_Package/Collaterals/Tech/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_11M.10a.tlef \
../Prepare/ADFP_Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/LEF/lef/N16ADFP_StdCell.lef \
../Prepare/ADFP_Executable_Package/Collaterals/IP/stdio/N16ADFP_StdIO/LEF/N16ADFP_StdIO.lef \
../Prepare/ADFP_Executable_Package/Collaterals/IP/bondpad/N16ADFP_BondPad/LEF/N16ADFP_BondPad.lef \
../Prepare/ADFP_Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/LEF/N16ADFP_SRAM_100a.lef 
set_pg_library_mode -celltype techonly \
                    -power_pins {VDD 0.8 VDDCE 0.8 VDDPE 0.8} \
                    -ground_pins {VSS VSSE} \
                    -extraction_tech_file ../Prepare/ADFP_Executable_Package/Collaterals/Tech/RC/N16ADFP_QRC/worst/qrcTechFile \
                    -temperature 0
#                    -lef_layermap ../../library/fireice/lefdef.layermap 
                    #-filler_cells FILLCELL* \
                    #-decap_cells
generate_pg_library
                    
