# reconfig_rp_x8_gen3.tcl — Reconfigure RP to x8 Gen3 to match EP speed
#
# The RP's CED only has 2 GT Quads (x8 max), so x16 is not possible.
# We keep x8 but change speed from Gen4 (16.0_GT/s) to Gen3 (8.0_GT/s).
# CPM params live inside CONFIG.CPM_CONFIG { ... }, not as direct CONFIG.* properties.
#
# Usage: vivado -mode batch -source reconfig_rp_x8_gen3.tcl [-tclargs <CL_DIR>]

set script_dir [file dirname [file normalize [info script]]]
set verif_dir  [file normalize "$script_dir/.."]
set platform_dir [file normalize "$verif_dir/../.."]

if {[llength $argv] >= 1} {
    set cl_dir [file normalize [lindex $argv 0]]
} else {
    set candidates [glob -nocomplain "$platform_dir/cl_xilinx_alveo_v80-*Kodiak*"]
    if {[llength $candidates] == 0} {
        set candidates [glob -nocomplain "$platform_dir/cl_xilinx_alveo_v80-*"]
    }
    set cl_dir [lindex [lsort $candidates] end]
}

set proj_dir   "$script_dir/vivado_proj"
set export_dir "$cl_dir/vcs_vip"
set lib_map    "$verif_dir/vcs_xilinx_lib"

puts "Opening project: $proj_dir/vip_metasim.xpr"
open_project "$proj_dir/vip_metasim.xpr"

# ── 1. Reconfigure RP versal_cips for x8 Gen3 ───────────────────────
puts "Reconfiguring RP versal_cips_0 to x8 Gen3..."
open_bd_design [get_files design_rp.bd]

# CPM parameters are nested inside CONFIG.CPM_CONFIG
set cips [get_bd_cells versal_cips_0]

# Read current CPM_CONFIG, modify link params, write back
set cpm_cfg [get_property CONFIG.CPM_CONFIG $cips]
puts "Current CPM_CONFIG link params:"
puts "  [lsearch -inline -all $cpm_cfg *MAX_LINK_SPEED*]"
puts "  [lsearch -inline -all $cpm_cfg *LINK_CAP_MAX_LINK_WIDTH*]"

set_property -dict [list \
    CONFIG.CPM_CONFIG [list \
        CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH {X8} \
        CPM_PCIE0_MAX_LINK_SPEED {8.0_GT/s} \
    ] \
] $cips

puts "After reconfiguration:"
set cpm_cfg_new [get_property CONFIG.CPM_CONFIG $cips]
puts "  Speed: [lsearch -inline -all $cpm_cfg_new *MAX_LINK_SPEED*]"
puts "  Width: [lsearch -inline -all $cpm_cfg_new *LINK_CAP_MAX_LINK_WIDTH*]"

puts "Validating design_rp..."
validate_bd_design
save_bd_design

# ── 2. Regenerate output products ───────────────────────────────────
puts "Regenerating design_rp output products..."
generate_target all [get_files design_rp.bd]

# ── 3. Patch PIPESIM_CLK_MASTER=TRUE on regenerated SV ──────────────
puts "Patching PIPESIM_CLK_MASTER=TRUE on regenerated RP SV..."
set rp_search_dir "$proj_dir/vip_metasim.gen/sources_1/bd/design_rp"
foreach f [glob -nocomplain "$rp_search_dir/ip/*/bd_*/ip/*/sim/bd_*_cpm_0_0.sv"] {
    set fd [open $f r]; set content [read $fd]; close $fd
    set content [string map {".C_CPM_PIPESIM_CLK_MASTER(\"FALSE\")" ".C_CPM_PIPESIM_CLK_MASTER(\"TRUE\")"} $content]
    set fd [open $f w]; puts -nonewline $fd $content; close $fd
    puts "  Patched: [file tail $f]"
}

# ── 4. Re-export VCS simulation scripts ─────────────────────────────
puts "Exporting VCS scripts to: $export_dir"
export_simulation -simulator vcs \
    -lib_map_path $lib_map \
    -directory $export_dir \
    -force

close_project
puts "Done. RP is now x8 Gen3. VCS scripts at: $export_dir/vcs/"
