#!/bin/tcsh
set DRC_Root = /usr/cad/CBDK/Executable_Package/Collaterals/Tech/DRC/N16ADFP_DRC_Calibre


mkdir rpt output log
# source /cad/mentor/CIC2/calibre.csh
# source /cad/mentor/CIC2/license.csh
set NUM_OF_CPU = 16

### sed Deck
set deckFile = $DRC_Root/ANTENNA_DRC/N16ADFP_DRC_Calibre_11M_ANT.11_1a.encrypt

cp -rf $deckFile ./scr/ANTENNA_DRC
sed -i -e 's/^#DEFINE DUMMY_PRE_CHECK/\/\/#DEFINE DUMMY_PRE_CHECK/g' ./scr/ANTENNA_DRC
sed -i -e 's/\/\/#DEFINE UseprBoundary/#DEFINE UseprBoundary/g' ./scr/ANTENNA_DRC
sed -i -e 's/^LAYOUT SYSTEM/\/\/LAYOUT SYSTEM/g' ./scr/ANTENNA_DRC
sed -i -e 's/^LAYOUT PATH/\/\/LAYOUT PATH/g' ./scr/ANTENNA_DRC
sed -i -e 's/^LAYOUT PRIMARY/\/\/LAYOUT PRIMARY/g' ./scr/ANTENNA_DRC
sed -i -e 's/^DRC RESULTS DATABASE "/\/\/DRC RESULTS DATABASE "/g' ./scr/ANTENNA_DRC
sed -i -e 's/^DRC SUMMARY REPORT/\/\/DRC SUMMARY REPORT/g' ./scr/ANTENNA_DRC
sed -i -e 's/^VARIABLE VDD_TEXT/\/\/VARIABLE VDD_TEXT/g' ./scr/ANTENNA_DRC

calibre -drc -hier -64 -turbo $NUM_OF_CPU  -hyper -lmretry loop,maxretry:200,interval:200 ./scr/runset_ANTENNA.cmd | tee -i log/runset_ANTENNA.log

mv -f *.rep     ./rpt
