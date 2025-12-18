rm add_dummy/*.gds
rm add_dummy/*.gds.gz
rm -rf drc/output
cd add_dummy
./run_FE.csh 
./run_BE.csh 
./run_merge.csh 
cd ../drc 
 ./run_DRC.csh
