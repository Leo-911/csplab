#!/bin/tcsh
mkdir log output
# source /cad/mentor/CIC2/calibre.csh
# source /cad/mentor/CIC2/license.csh

##merge
calibredrv -64 ./scr/runset_merge.cmd | tee log/runset_merge.log

