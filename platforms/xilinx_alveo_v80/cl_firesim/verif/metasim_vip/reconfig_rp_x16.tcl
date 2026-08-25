# reconfig_rp_x16.tcl — Reconfigure RP to x16 Gen3 to match EP, regenerate, and re-export
#
# The CED RP design only has 2 GT Quads, but in PIPESIM mode GTs are bypassed.
# CPM params live inside CONFIG.CPM_CONFIG { ... }, not as direct CONFIG.* properties.
# After export, we also create gt_quad_2/3 .mem files (copies of quad_1).
#
# Usage: vivado -mode batch -source reconfig_rp_x16.tcl [-tclargs <CL_DIR>]

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

# ── 1. Reconfigure RP versal_cips for x16 Gen3 ──────────────────────
puts "Reconfiguring RP versal_cips_0 to x16 Gen3..."
open_bd_design [get_files design_rp.bd]

set cips [get_bd_cells versal_cips_0]

set cpm_cfg [get_property CONFIG.CPM_CONFIG $cips]
puts "Current CPM_CONFIG link params:"
puts "  [lsearch -inline -all $cpm_cfg *MAX_LINK_SPEED*]"
puts "  [lsearch -inline -all $cpm_cfg *LINK_CAP_MAX_LINK_WIDTH*]"

set_property -dict [list \
    CONFIG.CPM_CONFIG [list \
        CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH {X16} \
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

# ── 5. Create missing GT Quad .mem files for x16 ───────────────────
# The CED only has 2 GT Quads, so Vivado only exports quad_0 and quad_1.
# For x16 CPM5 model, quads 2 and 3 are needed. Copy quad_1 content.
puts "Creating gt_quad_2/3 .mem files for x16 operation..."
set vcs_dir "$export_dir/vcs"
set rp_prefix "bd_e4ca_cpm_0_0"
set quad1 "$vcs_dir/${rp_prefix}_gt_quad_1.mem"
if {[file exists $quad1]} {
    file copy -force $quad1 "$vcs_dir/${rp_prefix}_gt_quad_2.mem"
    file copy -force $quad1 "$vcs_dir/${rp_prefix}_gt_quad_3.mem"
    puts "  Created gt_quad_2.mem and gt_quad_3.mem from gt_quad_1.mem"
} else {
    puts "WARNING: $quad1 not found — cannot create quad 2/3"
}

close_project
puts "Done. RP is now x16 Gen3. VCS scripts at: $export_dir/vcs/"
puts "Next: run compile, elaborate, simulate."
