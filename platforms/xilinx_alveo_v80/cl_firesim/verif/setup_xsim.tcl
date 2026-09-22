# setup_xsim.tcl — Build a Vivado XSim simulation project for V80 FireSim
#
# Self-contained: recreates the Vivado project from design files (same
# way build-bitstream.sh / main.tcl does), adds the Xilinx CPM5 QDMA
# CED root-port BFM, and configures XSim with PIPESIM.
#
# Usage:
#   vivado -mode batch -stack 2000 -source setup_xsim.tcl -tclargs <CL_DIR>
#
# CL_DIR is the per-config build directory containing design/ and scripts/.
# Example:
#   platforms/xilinx_alveo_v80/cl_xilinx_alveo_v80-firesim-FireSim-...-BaseXilinxAlveoV80Config

# ── Arguments ─────────────────────────────────────────────────────────
if {[llength $argv] < 1} {
    set candidates [glob -nocomplain [file normalize "[file dirname [info script]]/../../../cl_xilinx_alveo_v80-*"]]
    if {[llength $candidates] == 0} {
        error "Pass CL_DIR as argument."
    }
    set cl_dir [lindex [lsort $candidates] end]
} else {
    set cl_dir [file normalize [lindex $argv 0]]
}

set design_dir "$cl_dir/design"
set script_dir "$cl_dir/scripts"
set verif_dir  [file dirname [file normalize [info script]]]
set ced_base   "/ecad/tools/xilinx/2025.1/data/xhub/ced/XilinxCEDStore/ced/Xilinx/IPI/Versal_CPM_QDMA_EP_Simulation_Design/cpm5_qdma"
set ced_sim    "$ced_base/sim_files"
set proj_dir   "$cl_dir/vivado_proj"

puts "CL_DIR    : $cl_dir"
puts "DESIGN    : $design_dir"
puts "SCRIPTS   : $script_dir"
puts "VERIF     : $verif_dir"
puts "PROJECT   : $proj_dir"

if {![file exists "$design_dir/FireSim-generated.sv"]} {
    error "$design_dir/FireSim-generated.sv not found."
}

# ── 1. Create EP Vivado project (mirrors main.tcl) ───────────────────
file mkdir $proj_dir
create_project firesim $proj_dir -part xcv80-lsva4737-2MHP-e-S -force
set_property board_part xilinx.com:v80:part0:1.0 [current_project]
set_property target_language Verilog [current_project]

# Source platform scripts the same way main.tcl does
source "$script_dir/utils.tcl"
source "$script_dir/platform_env.tcl"

# Variables that create_bd.tcl expects (normally set by main.tcl)
set desired_host_frequency 10

# Add RTL sources
add_files -norecurse [list \
    "$design_dir/axi_tieoff_master.v" \
    "$design_dir/overall_fpga_top.v" \
    "$design_dir/FireSim-generated.sv" \
]
add_files -norecurse [list \
    "$design_dir/axi.vh" \
    "$design_dir/helpers.vh" \
    "$design_dir/FireSim-generated.defines.vh" \
]
set_property file_type "Verilog Header" [get_files {axi.vh helpers.vh FireSim-generated.defines.vh}]
set_property include_dirs $design_dir [get_filesets sources_1]

# Create EP block design (uses original BD scripts with CPM_PCIE0)
source "$script_dir/create_bd.tcl"
validate_bd_design
generate_target all [get_files design_1.bd]

set_property top overall_fpga_top [get_filesets sources_1]

# ── 2. Create RP block design ────────────────────────────────────────
puts "Creating root-port block design (design_rp)..."
source "$ced_base/design_rp_bd.tcl"
validate_bd_design
generate_target all [get_files design_rp.bd]
make_wrapper -files [get_files design_rp.bd] -top
add_files -norecurse [glob "$proj_dir/firesim.gen/sources_1/bd/design_rp/hdl/design_rp_wrapper.v"]

# ── 3. Simulation fileset ────────────────────────────────────────────
set sim_fs [get_filesets sim_1]

# CED BFM files (use local patched tx_usrapp)
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
]

# Board testbench + FireSim tests
add_files -fileset $sim_fs -norecurse [list \
    "$verif_dir/board_firesim.v" \
    "$verif_dir/tests.vh" \
    "$verif_dir/tests_firesim.vh" \
]

# Disable auto sim wrapper — we supply our own board testbench
set_property sim_wrapper_top false $sim_fs
set_property top board $sim_fs
set_property top_lib xil_defaultlib $sim_fs
set_property verilog_define {FIRESIM_EP} $sim_fs
set_property verilog_define {FIRESIM_EP} [get_filesets sources_1]
set_property include_dirs [list $verif_dir $design_dir $ced_sim] $sim_fs

# ── 4. XSim settings ─────────────────────────────────────────────────
set_property -name {xsim.simulate.runtime}          -value {2ms}     -objects $sim_fs
set_property -name {xsim.simulate.log_all_signals}  -value {true}    -objects $sim_fs
set_property -name {xsim.elaborate.debug_level}      -value {typical} -objects $sim_fs
set_property -name {xsim.simulate.xsim.more_options} -value {-testplusarg testname=qdma_mm_test0} -objects $sim_fs

# ── 5. Export standalone XSim scripts ─────────────────────────────────
set export_dir "$cl_dir/xsim"
export_simulation -simulator xsim -directory $export_dir -force

# ── 6. Convenience run scripts ───────────────────────────────────────
set fp [open "$proj_dir/run_sim.tcl" w]
puts $fp "open_project $proj_dir/firesim.xpr"
puts $fp "launch_simulation"
puts $fp "run 500us"
close $fp

puts ""
puts "================================================================"
puts "XSim project ready."
puts ""
puts "Option A — run via Vivado GUI:"
puts "  vivado $proj_dir/firesim.xpr"
puts "  launch_simulation"
puts ""
puts "Option B — run via exported scripts (no Vivado GUI):"
puts "  cd $export_dir/xsim && bash board.sh"
puts ""
puts "Default test: qdma_mm_test0"
puts "================================================================"
