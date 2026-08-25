# setup_vip_metasim.tcl — Create VIP-based FPGA-level VCS metasim for V80
#
# Creates a Vivado project with the full block design (versal_cips CPM5,
# axi_noc, SmartConnect, clk_wizard, proc_sys_reset) + Root Port BFM,
# then exports VCS simulation scripts.
#
# Usage:
#   source /ecad/tools/xilinx/2025.1/Vivado/settings64.sh
#   vivado -mode batch -stack 2000 -source setup_vip_metasim.tcl [-tclargs <CL_DIR>]
#
# CL_DIR points to the build config directory containing design/FireSim-generated.sv.
# If not given, auto-detects the Kodiak config.

set script_dir [file dirname [file normalize [info script]]]
set verif_dir  [file normalize "$script_dir/.."]
set cl_firesim [file normalize "$verif_dir/.."]
set platform_dir [file normalize "$cl_firesim/.."]
set firesim_dir  [file normalize "$platform_dir/../.."]

# ── Arguments ────────────────────────────────────────────────────────
if {[llength $argv] >= 1} {
    set cl_dir [file normalize [lindex $argv 0]]
} else {
    set candidates [glob -nocomplain "$platform_dir/cl_xilinx_alveo_v80-*Kodiak*"]
    if {[llength $candidates] == 0} {
        set candidates [glob -nocomplain "$platform_dir/cl_xilinx_alveo_v80-*"]
    }
    if {[llength $candidates] == 0} {
        error "No cl_xilinx_alveo_v80-* directory found. Pass CL_DIR as argument."
    }
    set cl_dir [lindex [lsort $candidates] end]
}

set cl_design_dir "$cl_dir/design"

if {![file exists "$cl_design_dir/FireSim-generated.sv"]} {
    error "FireSim-generated.sv not found in $cl_design_dir"
}

set proj_dir   "$script_dir/vivado_proj"
set export_dir "$cl_dir/vcs_vip"
set lib_map    "$verif_dir/vcs_xilinx_lib"

set ced_base "/ecad/tools/xilinx/2025.1/data/xhub/ced/XilinxCEDStore/ced/Xilinx/IPI/Versal_CPM_QDMA_EP_Simulation_Design/cpm5_qdma"
set ced_sim  "$ced_base/sim_files"
set ced_src  "$ced_base/src"

set desired_host_frequency 250

puts "============================================================"
puts "V80 VIP-based Metasim Setup"
puts "============================================================"
puts "SCRIPT_DIR : $script_dir"
puts "CL_DIR     : $cl_dir"
puts "CL_DESIGN  : $cl_design_dir"
puts "PROJECT    : $proj_dir"
puts "EXPORT     : $export_dir"
puts "CED_BASE   : $ced_base"
puts "LIB_MAP    : $lib_map"
puts ""

# ── 1. Create fresh Vivado project ─────────────────────────────────
file mkdir $proj_dir
create_project vip_metasim $proj_dir -part xcv80-lsva4737-2MHP-e-S -force
set_property target_language Verilog [current_project]

# ── 2. Create design_1 block design (from FireSim create_bd.tcl) ──
puts "Creating design_1 block design..."

proc check_file_exists { filepath } {
    if {![file exists $filepath]} {
        error "Required file not found: $filepath"
    }
}

# create_bd.tcl expects $script_folder (set by main.tcl in the build flow)
set script_folder "$cl_firesim/scripts"

source "$cl_firesim/scripts/create_bd.tcl"

generate_target all [get_files design_1.bd]
make_wrapper -files [get_files design_1.bd] -top
add_files -norecurse [glob "$proj_dir/vip_metasim.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v"]

# ── 3. Patch EP sim wrapper: PIPESIM=TRUE ─────────────────────────
puts "Patching EP sim wrappers (PIPESIM=TRUE)..."
set ep_search_dir "$proj_dir/vip_metasim.gen/sources_1/bd/design_1"
foreach f [glob -nocomplain "$ep_search_dir/ip/*/bd_*/ip/*/sim/bd_*_cpm_0_0.sv"] {
    set fd [open $f r]; set content [read $fd]; close $fd
    set content [string map {".C_CPM_PIPESIM(\"FALSE\")" ".C_CPM_PIPESIM(\"TRUE\")"} $content]
    set fd [open $f w]; puts -nonewline $fd $content; close $fd
    puts "  Patched PIPESIM=TRUE: [file tail $f]"
}

# ── 4. Add FireSim design sources ─────────────────────────────────
puts "Adding FireSim design sources..."
add_files -norecurse [list \
    "$cl_design_dir/FireSim-generated.defines.vh" \
    "$cl_design_dir/FireSim-generated.sv" \
    "$cl_design_dir/overall_fpga_top.v" \
]

set_property file_type "Verilog Header" [get_files FireSim-generated.defines.vh]
set_property is_global_include true [get_files FireSim-generated.defines.vh]

# Set include dirs so overall_fpga_top.v finds axi.vh and helpers.vh
set_property include_dirs [list $cl_design_dir] [get_filesets sources_1]

set_property top overall_fpga_top [get_filesets sources_1]

# Add +define+SIMULATION so overall_fpga_top's ifdef SIMULATION block is active
set_property verilog_define {SIMULATION} [get_filesets sources_1]

# ── 5. Create Root Port block design (from CED) ──────────────────
puts "Creating design_rp block design (Root Port)..."

# Read the CED design_rp_bd.tcl — it uses PCIE0 by default for the RP
source "$ced_base/design_rp_bd.tcl"

validate_bd_design
generate_target all [get_files design_rp.bd]
make_wrapper -files [get_files design_rp.bd] -top
add_files -norecurse [glob "$proj_dir/vip_metasim.gen/sources_1/bd/design_rp/hdl/design_rp_wrapper.v"]

# ── 5b. Patch RP sim wrapper: CLK_MASTER=TRUE ────────────────────
puts "Patching RP sim wrappers (PIPESIM_CLK_MASTER=TRUE)..."
set rp_search_dir "$proj_dir/vip_metasim.gen/sources_1/bd/design_rp"
foreach f [glob -nocomplain "$rp_search_dir/ip/*/bd_*/ip/*/sim/bd_*_cpm_0_0.sv"] {
    set fd [open $f r]; set content [read $fd]; close $fd
    set content [string map {".C_CPM_PIPESIM_CLK_MASTER(\"FALSE\")" ".C_CPM_PIPESIM_CLK_MASTER(\"TRUE\")"} $content]
    set fd [open $f w]; puts -nonewline $fd $content; close $fd
    puts "  Patched PIPESIM_CLK_MASTER=TRUE: [file tail $f]"
}

# ── 6. Simulation fileset ─────────────────────────────────────────
puts "Configuring simulation fileset..."
set sim_fs [get_filesets sim_1]

# Add CED simulation infrastructure files
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

# Add our custom testbench and test headers
add_files -fileset $sim_fs -norecurse [list \
    "$verif_dir/board_firesim.v" \
    "$verif_dir/tests_firesim.vh" \
    "$verif_dir/board_firesim_dma_mon.vh" \
]

set_property file_type "Verilog Header" [get_files board_common.vh]
set_property file_type "Verilog Header" [get_files pci_exp_expect_tasks.vh]
set_property file_type "Verilog Header" [get_files sample_tests.vh]
set_property file_type "Verilog Header" [get_files tests_firesim.vh]
set_property file_type "Verilog Header" [get_files board_firesim_dma_mon.vh]

set_property sim_wrapper_top true $sim_fs
set_property top board $sim_fs
set_property top_lib xil_defaultlib $sim_fs
set_property include_dirs [list $verif_dir $ced_sim $cl_design_dir] $sim_fs
set_property verilog_define {SIMULATION FIRESIM_EP} [get_filesets sim_1]

# ── 7. Export VCS simulation scripts ──────────────────────────────
puts ""
puts "Exporting VCS simulation scripts..."
puts "  Export dir: $export_dir"

export_simulation -simulator vcs \
    -lib_map_path $lib_map \
    -directory $export_dir \
    -force

# ── 8. Done ───────────────────────────────────────────────────────
close_project

puts ""
puts "============================================================"
puts "VIP-based VCS metasim setup complete."
puts ""
puts "  VCS scripts:   $export_dir/vcs/"
puts "  Vivado project: $proj_dir"
puts ""
puts "Next step:"
puts {  bash run_vip_metasim.sh [compile|elaborate|simulate|all] <CL_DIR>}
puts "============================================================"
