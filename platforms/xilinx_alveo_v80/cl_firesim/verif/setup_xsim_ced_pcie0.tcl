# setup_xsim_ced_pcie0.tcl — CED QDMA EP simulation modified for PCIE0
#
# Instead of creating the CED BD (which uses PCIE1) and reconfiguring after,
# we modify the CED's design_1_bd.tcl text to use PCIE0 before sourcing it.
# This avoids CIPS post-creation validation failures.
#
# Usage:
#   vivado -mode batch -stack 2000 -source setup_xsim_ced_pcie0.tcl

set verif_dir  [file dirname [file normalize [info script]]]
set proj_dir   "$verif_dir/ced_pcie0/proj"
set export_dir "$verif_dir/ced_pcie0/xsim"
set ced_base   "/ecad/tools/xilinx/2025.1/data/xhub/ced/XilinxCEDStore/ced/Xilinx/IPI/Versal_CPM_QDMA_EP_Simulation_Design/cpm5_qdma"
set ced_sim    "$ced_base/sim_files"
set ced_src    "$ced_base/src"

puts "VERIF_DIR : $verif_dir"
puts "PROJECT   : $proj_dir"
puts "CED_BASE  : $ced_base"

# ── 1. Create project ───────────────────────────────────────────────
file mkdir $proj_dir
create_project ced_pcie0 $proj_dir -part xcv80-lsva4737-2MHP-e-S -force
set_property board_part xilinx.com:v80:part0:1.0 [current_project]
set_property target_language Verilog [current_project]

# ── 2. Create modified design_1_bd.tcl with PCIE0 config ────────────
# Read the original CED BD script as text
set fd [open "$ced_base/design_1_bd.tcl" r]
set bd_content [read $fd]
close $fd

# 2a. Swap CPM_CONFIG params: PCIE0 <-> PCIE1 (3-step to avoid collisions)
set bd_content [string map {"CPM_PCIE0_" "CPM_PCIE_TEMP0_"} $bd_content]
set bd_content [string map {"CPM_PCIE1_" "CPM_PCIE0_"} $bd_content]
set bd_content [string map {"CPM_PCIE_TEMP0_" "CPM_PCIE1_"} $bd_content]

# 2b. Fix PS_PMC_CONFIG: PCIE0 EP needs RESET1 on PMC_MIO 24
set bd_content [string map {
  "PS_PCIE_EP_RESET1_IO {None}"       "PS_PCIE_EP_RESET1_IO {PMC_MIO 24}"
  "PS_PCIE_EP_RESET2_IO {PS_MIO 19}"  "PS_PCIE_EP_RESET2_IO {None}"
} $bd_content]

# 2c. Swap BD connections: dma1->dma0, PCIE1_GT->PCIE0_GT, gt_refclk1->gt_refclk0
set bd_content [string map {
  "dma1_"      "dma0_"
  "PCIE1_GT"   "PCIE0_GT"
  "gt_refclk1" "gt_refclk0"
} $bd_content]

# Write and source the modified BD
set mod_bd "$verif_dir/ced_pcie0/design_1_bd_pcie0.tcl"
file mkdir "$verif_dir/ced_pcie0"
set fd [open $mod_bd w]
puts $fd $bd_content
close $fd

puts "Sourcing modified BD (PCIE0 config)..."
source $mod_bd

# ── 3. Generate targets and wrapper ─────────────────────────────────
generate_target all [get_files design_1.bd]
make_wrapper -files [get_files design_1.bd] -top
add_files -norecurse [glob "$proj_dir/ced_pcie0.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v"]

# ── 3b. Fix EP sim wrapper: xsim defparam can't override named param ──
foreach f [glob -nocomplain "$proj_dir/ced_pcie0.gen/sources_1/bd/design_1/ip/*/bd_0/ip/ip_1/sim/bd_*_cpm_0_0.sv"] {
    set fd [open $f r]; set content [read $fd]; close $fd
    set content [string map {".C_CPM_PIPESIM(\"FALSE\")" ".C_CPM_PIPESIM(\"TRUE\")"} $content]
    set fd [open $f w]; puts -nonewline $fd $content; close $fd
    puts "Patched PIPESIM=TRUE in $f"
}

# ── 4. Add CED application RTL (qdma_app) with PCIE0 port names ────
set src_wrapper "$ced_src/design_1_wrapper.sv"
set dst_wrapper "$verif_dir/ced_pcie0/design_1_wrapper_pcie0.sv"

set fd [open $src_wrapper r]
set content [read $fd]
close $fd

set content [string map {
    "PCIE1_GT_0_grx_p" "PCIE0_GT_0_grx_p"
    "PCIE1_GT_0_grx_n" "PCIE0_GT_0_grx_n"
    "PCIE1_GT_0_gtx_p" "PCIE0_GT_0_gtx_p"
    "PCIE1_GT_0_gtx_n" "PCIE0_GT_0_gtx_n"
    "gt_refclk1_0_clk_n" "gt_refclk0_0_clk_n"
    "gt_refclk1_0_clk_p" "gt_refclk0_0_clk_p"
    ".PCIE1_GT_0" ".PCIE0_GT_0"
    ".gt_refclk1_0" ".gt_refclk0_0"
    "dma1_" "dma0_"
} $content]

set fd [open $dst_wrapper w]
puts $fd $content
close $fd

add_files -norecurse $dst_wrapper
foreach f [glob "$ced_src/*.sv" "$ced_src/*.svh"] {
    if {[file tail $f] ne "design_1_wrapper.sv"} {
        add_files -norecurse $f
    }
}
set_property file_type "Verilog Header" [get_files qdma_stm_defines.svh]

set_property top design_1_wrapper [get_filesets sources_1]

# ── 5. Create RP block design (same as stock — always uses PCIE0) ──
source "$ced_base/design_rp_bd.tcl"
validate_bd_design
generate_target all [get_files design_rp.bd]
make_wrapper -files [get_files design_rp.bd] -top
add_files -norecurse [glob "$proj_dir/ced_pcie0.gen/sources_1/bd/design_rp/hdl/design_rp_wrapper.v"]

# ── 5b. Fix RP sim wrapper: set CLK_MASTER=TRUE so RP generates pipe clk ──
foreach f [glob -nocomplain "$proj_dir/ced_pcie0.gen/sources_1/bd/design_rp/ip/*/bd_0/ip/ip_1/sim/bd_*_cpm_0_0.sv"] {
    set fd [open $f r]; set content [read $fd]; close $fd
    set content [string map {".C_CPM_PIPESIM_CLK_MASTER(\"FALSE\")" ".C_CPM_PIPESIM_CLK_MASTER(\"TRUE\")"} $content]
    set fd [open $f w]; puts -nonewline $fd $content; close $fd
    puts "Patched PIPESIM_CLK_MASTER=TRUE in $f"
}

# ── 6. Simulation fileset ───────────────────────────────────────────
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

add_files -fileset $sim_fs -norecurse "$verif_dir/board_ced_pcie0.v"

set_property sim_wrapper_top true $sim_fs
set_property top board $sim_fs
set_property top_lib xil_defaultlib $sim_fs
set_property include_dirs [list $verif_dir $ced_sim] $sim_fs

# ── 7. XSim settings ────────────────────────────────────────────────
set_property -name {xsim.simulate.runtime}          -value {500us}   -objects $sim_fs
set_property -name {xsim.simulate.log_all_signals}  -value {true}    -objects $sim_fs
set_property -name {xsim.elaborate.debug_level}      -value {typical} -objects $sim_fs
set_property -name {xsim.simulate.xsim.more_options} -value {-testplusarg testname=qdma_mm_test0} -objects $sim_fs

# ── 8. Export standalone XSim scripts ────────────────────────────────
export_simulation -simulator xsim -directory $export_dir -force

puts ""
puts "================================================================"
puts "CED PCIE0 XSim project ready (PCIE0 EP)."
puts "  cd $export_dir/xsim && bash board.sh"
puts "================================================================"
