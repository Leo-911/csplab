set ADFPRoot /usr/cad/CBDK/Executable_Package/Collaterals/

set lefList  " \
    $ADFPRoot/IP/stdcell/N16ADFP_StdCell/LEF/lef/N16ADFP_StdCell.lef \
    $ADFPRoot/IP/stdio/N16ADFP_StdIO/LEF/N16ADFP_StdIO.lef
"


foreach lef $lefList {
    set cellList [exec grep "MACRO " $lef | awk {{print $2}}]

    foreach cell $cellList {
        puts "$cell $cell"
    }
}

