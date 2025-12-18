root_dir := $(PWD)
src_dir := ./src
syn_dir := ./syn
inc_dir := ./include
sim_dir := ./sim
bld_dir := ./build
FSDB_DEF :=
ifeq ($(FSDB),1)
FSDB_DEF := +FSDB
else ifeq ($(FSDB),2)
FSDB_DEF := +FSDB_ALL
endif
CYCLE=`grep -v '^$$' $(root_dir)/sim/CYCLE`
MAX=`grep -v '^$$' $(root_dir)/sim/MAX`

$(bld_dir):
	mkdir -p $(bld_dir)

$(syn_dir):
	mkdir -p $(syn_dir)


# TA use this to check result
TA_run: 
  
# RTL simulation
rtl_all: rtl0 rtl1 rtl2 rtl3 rtl4 rtl5

rtl0: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -sverilog $(root_dir)/$(sim_dir)/top_tb.sv -debug_access+all -full64  \
	+incdir+$(root_dir)/$(src_dir)+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+prog0$(FSDB_DEF) \
	+prog_path=$(root_dir)/$(sim_dir)/prog0 \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+notimingcheck |& tee rtl0.log

rtl1: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -sverilog $(root_dir)/$(sim_dir)/top_tb.sv -debug_access+all -full64  \
	+incdir+$(root_dir)/$(src_dir)+$(root_dir)/$(src_dir)/AXI+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+prog1$(FSDB_DEF) \
	+prog_path=$(root_dir)/$(sim_dir)/prog1 \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+notimingcheck |& tee rtl1.log

rtl2: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -sverilog $(root_dir)/$(sim_dir)/top_tb1.sv -debug_access+all -full64  \
	+incdir+$(root_dir)/$(src_dir)+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+prog2$(FSDB_DEF) \
	+prog_path=$(root_dir)/$(sim_dir)/prog2 \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+notimingcheck  |& tee rtl2.log

rtl3: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -sverilog $(root_dir)/$(sim_dir)/top_tb1.sv -debug_access+all -full64  \
	+incdir+$(root_dir)/$(src_dir)+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+prog3$(FSDB_DEF) \
	+prog_path=$(root_dir)/$(sim_dir)/prog3 \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+notimingcheck  |& tee rtl3.log

rtl4: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -sverilog $(root_dir)/$(sim_dir)/top_tb2.sv -debug_access+all -full64  \
	+incdir+$(root_dir)/$(src_dir)+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+prog4$(FSDB_DEF) \
	+prog_path=$(root_dir)/$(sim_dir)/prog4 \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+notimingcheck   |& tee rtl4.log
 
rtl5: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -sverilog $(root_dir)/$(sim_dir)/top_tb3.sv -debug_access+all -full64  \
	+incdir+$(root_dir)/$(src_dir)+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+prog5$(FSDB_DEF) \
	+prog_path=$(root_dir)/$(sim_dir)/prog5 \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+notimingcheck   |& tee rtl5.log

# Post-Synthesis simulation
syn_all: syn0 syn1 syn2 syn3 syn4 syn5
# 16nm
syn0: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -sverilog +neg_tchk -negdelay \
	    -v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v \
	    $(root_dir)/$(sim_dir)/top_tb.sv \
	    -debug_access+all -full64 -diag=sdf:verbose \
	    +incdir+$(root_dir)/$(syn_dir)+$(root_dir)/$(src_dir)+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	    +define+SYN+prog0$(FSDB_DEF) \
		+define+CYCLE=$(CYCLE) \
		+define+MAX=$(MAX) \
	    +prog_path=$(root_dir)/$(sim_dir)/prog0 \
	    +vcs+dumpvars \
	    +vcdpluson \
	    +vcd_file=top.vcd \
	    |& tee syn0.log ; \
	if [ -d simv.vdb ]; then mv simv.vdb syn0.vdb; fi

syn1: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -cm tgl -sverilog +neg_tchk -negdelay \
		-v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v \
		$(root_dir)/$(sim_dir)/top_tb.sv \
		-debug_access+all -full64 -diag=sdf:verbose \
		+incdir+$(root_dir)/$(syn_dir)+$(root_dir)/$(src_dir)+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
		+define+CYCLE=$(CYCLE) \
		+define+MAX=$(MAX) \
		+define+SYN+prog1$(FSDB_DEF) \
		+no_notifier \
		+prog_path=$(root_dir)/$(sim_dir)/prog1 \
		|& tee syn1.log ; \
	if [ -d simv.vdb ]; then mv simv.vdb syn1.vdb; fi

syn2: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -cm tgl -sverilog +neg_tchk -negdelay \
		-v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v \
		$(root_dir)/$(sim_dir)/top_tb1.sv \
		-debug_access+all -full64 -diag=sdf:verbose \
		+incdir+$(root_dir)/$(syn_dir)+$(root_dir)/$(src_dir)+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
		+define+CYCLE=$(CYCLE) \
		+define+MAX=$(MAX) \
		+define+SYN+prog2$(FSDB_DEF) \
		+no_notifier \
		+prog_path=$(root_dir)/$(sim_dir)/prog2 \
		|& tee syn2.log ; \
	if [ -d simv.vdb ]; then mv simv.vdb syn2.vdb; fi

syn3: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -cm tgl -sverilog +neg_tchk -negdelay \
		-v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v \
		$(root_dir)/$(sim_dir)/top_tb1.sv \
		-debug_access+all -full64 -diag=sdf:verbose \
		+incdir+$(root_dir)/$(syn_dir)+$(root_dir)/$(src_dir)+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
		+define+CYCLE=$(CYCLE) \
		+define+MAX=$(MAX) \
		+define+SYN+prog3$(FSDB_DEF) \
		+no_notifier \
		+prog_path=$(root_dir)/$(sim_dir)/prog3 \
		|& tee syn3.log ; \
	if [ -d simv.vdb ]; then mv simv.vdb syn3.vdb; fi

syn4: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -cm tgl -sverilog +neg_tchk -negdelay \
		-v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v \
		$(root_dir)/$(sim_dir)/top_tb2.sv \
		-debug_access+all -full64 -diag=sdf:verbose \
		+incdir+$(root_dir)/$(syn_dir)+$(root_dir)/$(src_dir)+$(root_dir)/$(src_dir)/AXI+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
		+define+CYCLE=$(CYCLE) \
		+define+MAX=$(MAX) \
		+define+SYN+prog4$(FSDB_DEF) \
		+prog_path=$(root_dir)/$(sim_dir)/prog4 \
		|& tee syn4.log ; \
	if [ -d simv.vdb ]; then mv simv.vdb syn4.vdb; fi
 
 
syn5: | $(bld_dir)
	@if [ $$(echo $(CYCLE) '>' 20.0 | bc -l) -eq 1 ]; then \
		echo "Cycle time shouldn't exceed 20"; \
		exit 1; \
	fi; \
	cd $(bld_dir); \
	vcs -R -cm tgl -sverilog +neg_tchk -negdelay \
		-v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v \
		$(root_dir)/$(sim_dir)/top_tb3.sv \
		-debug_access+all -full64 -diag=sdf:verbose \
		+incdir+$(root_dir)/$(syn_dir)+$(root_dir)/$(src_dir)+$(root_dir)/$(src_dir)/AXI+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
		+define+CYCLE=$(CYCLE) \
		+define+MAX=$(MAX) \
		+define+SYN+prog5$(FSDB_DEF) \
		+prog_path=$(root_dir)/$(sim_dir)/prog5 \
		|& tee syn5.log ; \
	if [ -d simv.vdb ]; then mv simv.vdb syn5.vdb; fi

# Post-Layout simulation
pr_all: pr0 pr1 pr2 pr3 pr4 pr5

pr4_all:
	@echo "=================================================="
	@echo "  Running Full Regression for pr4 "
	@echo "=================================================="
	
	@echo "[pr4] 1. Checking 125C Setup (Max Delay)..."
	# 這裡一定要加上 || exit 1，這樣如果 Setup 爆了就會停下來，不會繼續跑 Hold
	make pr4 CORNER_DEF=+define+CORNER_125 DELAY_MODE=+maxdelays || exit 1
	
	@echo "[pr4] 2. Checking 125C Hold (Min Delay)..."
	make pr4 CORNER_DEF=+define+CORNER_125 DELAY_MODE=+mindelays || exit 1
	
	@echo "[pr4] 3. Checking -40C Setup (Max Delay)..."
	make pr4 CORNER_DEF=+define+CORNER_40 DELAY_MODE=+maxdelays || exit 1
	
	@echo "[pr4] 4. Checking -40C Hold (Min Delay)..."
	make pr4 CORNER_DEF=+define+CORNER_40 DELAY_MODE=+mindelays || exit 1
	
	@echo "################################################################"
	@echo "  CONGRATULATIONS! pr4 Passed 4-Corner Sign-off!"
	@echo "################################################################"

pr0: | clean $(bld_dir)
	cd $(bld_dir); \
	vcs -R -sverilog +neg_tchk -negdelay -v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v  $(root_dir)/$(sim_dir)/top_tb.sv -debug_access+all -full64 -diag=sdf:verbose \
	+incdir+$(root_dir)/pr/run/output+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+PR+prog0$(FSDB_DEF) \
	+no_notifier \
	+maxdelays \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+prog_path=$(root_dir)/$(sim_dir)/prog0 \

pr1: | clean $(bld_dir)
	cd $(bld_dir); \
	vcs -R -sverilog +neg_tchk -negdelay -v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v  $(root_dir)/$(sim_dir)/top_tb.sv -debug_access+all -full64 -diag=sdf:verbose \
	+incdir+$(root_dir)/pr/run/output+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+PR+prog1$(FSDB_DEF) \
	+no_notifier \
	+maxdelays \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+prog_path=$(root_dir)/$(sim_dir)/prog1 \

pr2: | clean $(bld_dir)
	cd $(bld_dir); \
	vcs -R -sverilog +neg_tchk -negdelay -v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v  $(root_dir)/$(sim_dir)/top_tb1.sv -debug_access+all -full64 -diag=sdf:verbose \
	+incdir+$(root_dir)/pr/run/output+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+PR+prog2$(FSDB_DEF) \
	+no_notifier \
	+maxdelays \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+prog_path=$(root_dir)/$(sim_dir)/prog2 \

pr3: | clean $(bld_dir)
	cd $(bld_dir); \
	vcs -R -sverilog +neg_tchk -negdelay -v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v  $(root_dir)/$(sim_dir)/top_tb1.sv -debug_access+all -full64 -diag=sdf:verbose \
	+incdir+$(root_dir)/pr/run/output+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+PR+prog3$(FSDB_DEF) \
	+no_notifier \
	+maxdelays \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \	
	+prog_path=$(root_dir)/$(sim_dir)/prog3 \

pr4: | clean $(bld_dir)
	cd $(bld_dir); \
	vcs -R -sverilog +neg_tchk -negdelay -v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v  $(root_dir)/$(sim_dir)/top_tb2.sv -debug_access+all -full64 -diag=sdf:verbose \
	+incdir+$(root_dir)/pr/run/output+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+PR+prog4+$(CORNER_DEF)$(FSDB_DEF) \
	+no_notifier \
	$(DELAY_MODE) \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+prog_path=$(root_dir)/$(sim_dir)/prog4 \

pr4_125_setup:
	make pr4 CORNER_DEF=+define+CORNER_125 DELAY_MODE=+maxdelays

pr4_125_hold:
	make pr4 CORNER_DEF=+define+CORNER_125 DELAY_MODE=+mindelays

pr4_40_setup:
	make pr4 CORNER_DEF=+define+CORNER_40 DELAY_MODE=+maxdelays

pr4_40_hold:
	make pr4 CORNER_DEF=+define+CORNER_40 DELAY_MODE=+mindelays

pr5: | clean $(bld_dir)
	cd $(bld_dir); \
	vcs -R -sverilog +neg_tchk -negdelay -v /usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v  $(root_dir)/$(sim_dir)/top_tb3.sv -debug_access+all -full64 -diag=sdf:verbose \
	+incdir+$(root_dir)/pr/run/output+$(root_dir)/$(inc_dir)+$(root_dir)/$(sim_dir) \
	+define+PR+prog5$(FSDB_DEF) \
	+no_notifier \
	+maxdelays \
	+define+CYCLE=$(CYCLE) \
	+define+MAX=$(MAX) \
	+prog_path=$(root_dir)/$(sim_dir)/prog5 \

# Utilities
nWave: | $(bld_dir)
	cd $(bld_dir); \
	nWave top.fsdb &

verdi: | $(bld_dir)
	cd $(bld_dir); \
	verdi -ssf top.fsdb &

superlint: | $(bld_dir)
	cd $(bld_dir); \
	jg -superlint ../script/superlint.tcl &

dv: | $(bld_dir) $(syn_dir)
	cp script/synopsys_dc.setup $(bld_dir)/.synopsys_dc.setup; \
	cd $(bld_dir); \
	dc_shell -gui -no_home_init &

synthesize: | $(bld_dir) $(syn_dir)
	cp script/synopsys_dc.setup $(bld_dir)/.synopsys_dc.setup; \
	cd $(bld_dir); \
	dc_shell -no_home_init -f ../script/synthesis.tcl | tee syn_compile.log

tcf_syn_merge:
	@echo "Merging syn TCF..."
	cd $(bld_dir); \
	URG_CVG_DUMP_FORMAT=tcf urg -full64 \
		-dir syn0.vdb \
		-dir syn1.vdb \
		-dir syn2.vdb \
		-dir syn3.vdb \
		-dir syn4.vdb \
		-dir syn5.vdb
	@echo ""
	@echo ">>> merged TCF generated under:"
	@echo "      $(bld_dir)/tcf/"


# Check file structure
BLUE=\033[1;34m
RED=\033[1;31m
NORMAL=\033[0m

check: clean
	@if [ -f StudentID ]; then \
		STUDENTID=$$(grep -v '^$$' StudentID); \
		if [ -z "$$STUDENTID" ]; then \
			echo -e "$(RED)Student ID number is not provided$(NORMAL)"; \
			exit 1; \
		else \
			ID_LEN=$$(expr length $$STUDENTID); \
			if [ $$ID_LEN -eq 9 ]; then \
				if [[ $$STUDENTID =~ ^[A-Z][A-Z0-9][0-9]+$$ ]]; then \
					echo -e "$(BLUE)Student ID number pass$(NORMAL)"; \
				else \
					echo -e "$(RED)Student ID number should be one capital letter and 8 numbers (or 2 capital letters and 7 numbers)$(NORMAL)"; \
					exit 1; \
				fi \
			else \
				echo -e "$(RED)Student ID number length isn't 9$(NORMAL)"; \
				exit 1; \
			fi \
		fi \
	else \
		echo -e "$(RED)StudentID file is not found$(NORMAL)"; \
		exit 1; \
	fi; \
	if [ -f StudentID2 ]; then \
		STUDENTID2=$$(grep -v '^$$' StudentID2); \
		if [ -z "$$STUDENTID2" ]; then \
			echo -e "$(RED)Second student ID number is not provided$(NORMAL)"; \
			exit 1; \
		else \
			ID2_LEN=$$(expr length $$STUDENTID2); \
			if [ $$ID2_LEN -eq 9 ]; then \
				if [[ $$STUDENTID2 =~ ^[A-Z][A-Z0-9][0-9]+$$ ]]; then \
					echo -e "$(BLUE)Second student ID number pass$(NORMAL)"; \
				else \
					echo -e "$(RED)Second student ID number should be one capital letter and 8 numbers (or 2 capital letters and 7 numbers)$(NORMAL)"; \
					exit 1; \
				fi \
			else \
				echo -e "$(RED)Second student ID number length isn't 9$(NORMAL)"; \
				exit 1; \
			fi \
		fi \
	fi; \
	if [ $$(ls -1 *.docx 2>/dev/null | wc -l) -eq 0 ]; then \
		echo -e "$(RED)Report file is not found$(NORMAL)"; \
		exit 1; \
	elif [ $$(ls -1 *.docx 2>/dev/null | wc -l) -gt 1 ]; then \
		echo -e "$(RED)More than one docx file is found, please delete redundant file(s)$(NORMAL)"; \
		exit 1; \
	elif [ ! -f $${STUDENTID}.docx ]; then \
		echo -e "$(RED)Report file name should be $$STUDENTID.docx$(NORMAL)"; \
		exit 1; \
	else \
		echo -e "$(BLUE)Report file name pass$(NORMAL)"; \
	fi; \
	if [ $$(basename $(PWD)) != $$STUDENTID ]; then \
		echo -e "$(RED)Main folder name should be \"$$STUDENTID\"$(NORMAL)"; \
		exit 1; \
	else \
		echo -e "$(BLUE)Main folder name pass$(NORMAL)"; \
	fi

tar: check
	STUDENTID=$$(basename $(PWD)); \
	cd ..; \
	tar cvf $$STUDENTID.tar $$STUDENTID

.PHONY: clean

clean:
	rm -rf $(bld_dir); \
	rm -rf $(sim_dir)/prog*/result*.txt; \