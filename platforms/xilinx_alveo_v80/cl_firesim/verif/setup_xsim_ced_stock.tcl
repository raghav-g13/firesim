# setup_xsim_ced_stock.tcl — Stock CED QDMA EP simulation (PCIE1 EP, PCIE0 RP)
#
# Validates PIPESIM infrastructure with Xilinx's known-working example.
# No modifications to the CED — uses PCIE1 for EP exactly as Xilinx designed.
#
# Usage:
#   vivado -mode batch -stack 2000 -source setup_xsim_ced_stock.tcl

set verif_dir  [file dirname [file normalize [info script]]]
set proj_dir   "$verif_dir/ced_stock/proj"
set export_dir "$verif_dir/ced_stock/xsim"
set ced_base   "/ecad/tools/xilinx/2025.1/data/xhub/ced/XilinxCEDStore/ced/Xilinx/IPI/Versal_CPM_QDMA_EP_Simulation_Design/cpm5_qdma"
set ced_sim    "$ced_base/sim_files"
set ced_src    "$ced_base/src"

puts "VERIF_DIR : $verif_dir"
puts "PROJECT   : $proj_dir"
puts "CED_BASE  : $ced_base"

# ── 1. Create project ───────────────────────────────────────────────
file mkdir $proj_dir
create_project ced_stock $proj_dir -part xcv80-lsva4737-2MHP-e-S -force
set_property board_part xilinx.com:v80:part0:1.0 [current_project]
set_property target_language Verilog [current_project]

# ── 2. Create EP block design (CED's design_1 with QDMA on PCIE1) ──
source "$ced_base/design_1_bd.tcl"
validate_bd_design
generate_target all [get_files design_1.bd]
make_wrapper -files [get_files design_1.bd] -top
add_files -norecurse [glob "$proj_dir/ced_stock.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v"]

# ── 2b. Fix EP sim wrapper: xsim defparam can't override named param ──
# The generated sim wrapper hardcodes C_CPM_PIPESIM("FALSE") even though
# board.v uses defparam to set it TRUE. xsim doesn't override named
# parameter associations with defparam, so patch the file directly.
foreach f [glob -nocomplain "$proj_dir/ced_stock.gen/sources_1/bd/design_1/ip/*/bd_0/ip/ip_1/sim/bd_*_cpm_0_0.sv"] {
    set fd [open $f r]; set content [read $fd]; close $fd
    set content [string map {".C_CPM_PIPESIM(\"FALSE\")" ".C_CPM_PIPESIM(\"TRUE\")"} $content]
    set fd [open $f w]; puts -nonewline $fd $content; close $fd
    puts "Patched PIPESIM=TRUE in $f"
}

# ── 3. Add CED application RTL (qdma_app + loopback) ────────────────
add_files -norecurse [glob "$ced_src/*.sv" "$ced_src/*.svh"]
set_property file_type "Verilog Header" [get_files qdma_stm_defines.svh]

set_property top design_1_wrapper [get_filesets sources_1]

# ── 4. Create RP block design ───────────────────────────────────────
source "$ced_base/design_rp_bd.tcl"
validate_bd_design
generate_target all [get_files design_rp.bd]
make_wrapper -files [get_files design_rp.bd] -top
add_files -norecurse [glob "$proj_dir/ced_stock.gen/sources_1/bd/design_rp/hdl/design_rp_wrapper.v"]

# ── 4b. Fix RP sim wrapper: set CLK_MASTER=TRUE so RP generates pipe clk ──
# Without this, both EP and RP have CLK_MASTER=FALSE, creating a circular
# clock dependency where neither side generates the PIPE clock.
foreach f [glob -nocomplain "$proj_dir/ced_stock.gen/sources_1/bd/design_rp/ip/*/bd_0/ip/ip_1/sim/bd_*_cpm_0_0.sv"] {
    set fd [open $f r]; set content [read $fd]; close $fd
    set content [string map {".C_CPM_PIPESIM_CLK_MASTER(\"FALSE\")" ".C_CPM_PIPESIM_CLK_MASTER(\"TRUE\")"} $content]
    set fd [open $f w]; puts -nonewline $fd $content; close $fd
    puts "Patched PIPESIM_CLK_MASTER=TRUE in $f"
}

# ── 5. Simulation fileset ───────────────────────────────────────────
set sim_fs [get_filesets sim_1]

add_files -fileset $sim_fs -norecurse [list \
    "$ced_sim/board_common.vh" \
    "$ced_sim/sys_clk_gen.v" \
    "$ced_sim/sys_clk_gen_ds.v" \
    "$ced_sim/pcie_4_0_rp.v" \
    "$ced_sim/xilinx_pcie5_versal_rp.sv" \
    "$ced_sim/xp4_usp_smsw_model_core_top.v" \
    "$ced_sim/usp_pci_exp_usrapp_com.v" \
    "$ced_sim/usp_pci_exp_usrapp_cfg.v" \
    "$ced_sim/usp_pci_exp_usrapp_rx.v" \
    "$verif_dir/usp_pci_exp_usrapp_tx.v" \
    "$ced_sim/usp_pci_exp_usrapp_tx_sriov.sv" \
    "$ced_sim/pci_exp_expect_tasks.vh" \
    "$ced_sim/sample_tests.vh" \
    "$ced_sim/tests.vh" \
]

# Use our board.v with link monitor (references CED hierarchy)
add_files -fileset $sim_fs -norecurse "$verif_dir/board_ced_stock.v"

set_property sim_wrapper_top true $sim_fs
set_property top board $sim_fs
set_property top_lib xil_defaultlib $sim_fs
set_property include_dirs [list $verif_dir $ced_sim] $sim_fs

# ── 6. XSim settings ────────────────────────────────────────────────
set_property -name {xsim.simulate.runtime}          -value {500us}   -objects $sim_fs
set_property -name {xsim.simulate.log_all_signals}  -value {true}    -objects $sim_fs
set_property -name {xsim.elaborate.debug_level}      -value {typical} -objects $sim_fs
set_property -name {xsim.simulate.xsim.more_options} -value {-testplusarg testname=qdma_mm_test0} -objects $sim_fs

# ── 7. Export standalone XSim scripts ────────────────────────────────
export_simulation -simulator xsim -directory $export_dir -force

puts ""
puts "================================================================"
puts "CED stock XSim project ready (PCIE1 EP)."
puts "  cd $export_dir/xsim && bash board.sh"
puts "================================================================"
