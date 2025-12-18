#!/bin/tcsh
set DummyRoot = /usr/cad/CBDK/Executable_Package/Collaterals/Tech/DUMMY/N16ADFP_Dummy_Calibre/

mkdir log output

# source /cad/mentor/CIC2/calibre.csh
# source /cad/mentor/CIC2/license.csh

set NUM_OF_CPU = 64

## gen BE dummy
### sed Deck

set deckFile = $DummyRoot/BEOL/Dummy_BEOL_CalibreYE_16nm_ADFP_FFP.10a.encrypt
cp -rf $deckFile ./scr/Dummy_BEOL_CalibreYE
sed -i -e 's/^LAYOUT PRIMARY/\/\/LAYOUT PRIMARY/g' ./scr/Dummy_BEOL_CalibreYE
sed -i -e 's/^LAYOUT PATH/\/\/LAYOUT PATH/g' ./scr/Dummy_BEOL_CalibreYE
sed -i -e 's/^LAYOUT SYSTEM/\/\/LAYOUT SYSTEM/g' ./scr/Dummy_BEOL_CalibreYE
sed -i -e 's/^DRC RESULTS DATABASE/\/\/DRC RESULTS DATABASE/g' ./scr/Dummy_BEOL_CalibreYE
sed -i -e 's/^DRC SUMMARY REPORT/\/\/DRC SUMMARY REPORT/g' ./scr/Dummy_BEOL_CalibreYE
sed -i -e 's/  #DEFINE WITH_SEALRING/\/\/#DEFINE WITH_SEALRING/g' ./scr/Dummy_BEOL_CalibreYE
sed -i -e 's/\/\/#DEFINE UseprBoundary/#DEFINE UseprBoundary/g' ./scr/Dummy_BEOL_CalibreYE
#sed -i -e 's/#DEFINE FILL_DM9/\/\/#DEFINE FILL_DM9/g' ./scr/Dummy_BEOL_CalibreYE

calibre -drc -hier -64 -turbo $NUM_OF_CPU  -hyper -lmretry loop,maxretry:200,interval:200 ./scr/runset_BE.cmd  | tee -i log/runset_BE.log

