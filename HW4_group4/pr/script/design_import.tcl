read_mmmc ../Prepare/mmmc.view.stylus
read_physical -lef {../Prepare/ADFP_Executable_Package/Collaterals/Tech/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_11M.10a.tlef
../Prepare/ADFP_Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/LEF/lef/N16ADFP_StdCell.lef
../Prepare/ADFP_Executable_Package/Collaterals/IP/stdio/N16ADFP_StdIO/LEF/N16ADFP_StdIO.lef
../Prepare/ADFP_Executable_Package/Collaterals/IP/bondpad/N16ADFP_BondPad/LEF/N16ADFP_BondPad.lef
../Prepare/ADFP_Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/LEF/N16ADFP_SRAM_100a.lef}
set_db init_power_nets {VDD VDDPST}
set_db init_ground_nets VSS
read_netlist -top CHIP ../Prepare/CHIP_syn.v
init_design
