#!/bin/tcsh
set ADFPRoot = /usr/cad/CBDK/Executable_Package/Collaterals/

mkdir log output rpt

# source /cad/mentor/CIC2/calibre.csh

set NUM_OF_CPU = 8

#tcl ./scr/genHcell.cmd > ./rpt/hcell

### sed Deck

set deckFile = "$ADFPRoot/Tech/LVS/N16ADFP_LVS_Calibre/MAIN_DECK/CCI_FLOW/N16ADFP_LVS_Calibre"

cp -rf $deckFile ./scr/N16ADFP_LVS_Calibre.modified

sed -i -e 's/VARIABLE POWER_NAME/\/\/VARIABLE POWER_NAME/g' ./scr/N16ADFP_LVS_Calibre.modified
sed -i -e 's/VARIABLE GROUND_NAME/\/\/VARIABLE GROUND_NAME/g' ./scr/N16ADFP_LVS_Calibre.modified

sed -i -e 's/LAYOUT PRIMARY/\/\/LAYOUT PRIMARY/g' ./scr/N16ADFP_LVS_Calibre.modified
sed -i -e 's/LAYOUT PATH/\/\/LAYOUT PATH/g' ./scr/N16ADFP_LVS_Calibre.modified
sed -i -e 's/LAYOUT SYSTEM/\/\/LAYOUT SYSTEM/g' ./scr/N16ADFP_LVS_Calibre.modified

sed -i -e 's/SOURCE PRIMARY/\/\/SOURCE PRIMARY/g' ./scr/N16ADFP_LVS_Calibre.modified
sed -i -e 's/SOURCE PATH/\/\/SOURCE PATH/g' ./scr/N16ADFP_LVS_Calibre.modified

sed -i -e 's/ERC RESULTS DATABASE/\/\/ERC RESULTS DATABASE/g' ./scr/N16ADFP_LVS_Calibre.modified
sed -i -e 's/ERC SUMMARY REPORT/\/\/ERC SUMMARY REPORT/g' ./scr/N16ADFP_LVS_Calibre.modified

sed -i -e 's/LVS REPORT \"/\/\/LVS REPORT \"/g' ./scr/N16ADFP_LVS_Calibre.modified

calibre -lvs -64 -hier -turbo $NUM_OF_CPU -spice layout.spi ./scr/runset.cmd -lmretry loop,maxretry:200,interval:180 | tee -i log/runset.log


