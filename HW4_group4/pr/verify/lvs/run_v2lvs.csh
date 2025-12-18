#!/bin/tcsh

# source /cad/mentor/CIC2/calibre.csh

set inputLvsvg  = ../../run/output/CHIP_pg.v


v2lvs -v $inputLvsvg -o ./CHIP.spi

sed -i -e 's/^\.GLOBAL.*/**\.GLOBAL/'   ./CHIP.spi
sed -i -e 's/^XBUMP/****XBUMP/'         ./CHIP.spi
sed -i -e 's/^\.INCLUDE.*/**\.INCLUDE/' ./CHIP.spi

