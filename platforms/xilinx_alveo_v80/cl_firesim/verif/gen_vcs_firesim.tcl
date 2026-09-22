# gen_vcs_firesim.tcl — Export VCS simulation scripts from the existing
# firesim.xpr Vivado project, with PIPESIM patches applied.
#
# Usage:
#   vivado -mode batch -stack 2000 -source gen_vcs_firesim.tcl [-tclargs <CL_DIR>]
#
# CL_DIR is the per-config build directory containing vivado_proj/firesim.xpr.
# If not given, auto-detects by globbing for cl_xilinx_alveo_v80-* siblings.

# ── Helper: recursive glob ────────────────────────────────────────────
proc find_files {basedir pattern} {
    set results {}
    foreach f [glob -nocomplain -directory $basedir $pattern] {
        lappend results $f
    }
    foreach d [glob -nocomplain -directory $basedir -type d *] {
        foreach f [find_files $d $pattern] {
            lappend results $f
        }
    }
    return $results
}

# ── Arguments ─────────────────────────────────────────────────────────
if {[llength $argv] < 1} {
    set candidates [glob -nocomplain [file normalize "[file dirname [info script]]/../../cl_xilinx_alveo_v80-*"]]
    if {[llength $candidates] == 0} {
        error "Pass CL_DIR as argument or ensure a cl_xilinx_alveo_v80-* dir exists."
    }
    set cl_dir [lindex [lsort $candidates] end]
} else {
    set cl_dir [file normalize [lindex $argv 0]]
}

set proj_dir   "$cl_dir/vivado_proj"
set verif_dir  [file dirname [file normalize [info script]]]
set firesim_root [file normalize "$verif_dir/../../.."]

puts "CL_DIR    : $cl_dir"
puts "PROJECT   : $proj_dir"
puts "VERIF     : $verif_dir"
puts "FIRESIM   : $firesim_root"

if {![file exists "$proj_dir/firesim.xpr"]} {
    error "firesim.xpr not found at $proj_dir/firesim.xpr"
}

# ── 1. Open existing project ─────────────────────────────────────────
open_project "$proj_dir/firesim.xpr"

# ── 2. Apply PIPESIM=TRUE patches to EP sim wrapper files ────────────
#    (design_1 BD → bd_*_cpm_0_0.sv under firesim.gen)
puts "Patching EP sim wrappers (PIPESIM=TRUE)..."
set ep_search_dir "$proj_dir/firesim.gen/sources_1/bd/design_1"
set ep_files [find_files $ep_search_dir "bd_*_cpm_0_0.sv"]
puts "  Found [llength $ep_files] EP wrapper file(s)"
foreach f $ep_files {
    puts "  Patching EP: $f"
    set fd [open $f r]
    set content [read $fd]
    close $fd
    set content [string map {".C_CPM_PIPESIM(\"FALSE\")" ".C_CPM_PIPESIM(\"TRUE\")"} $content]
    set fd [open $f w]
    puts -nonewline $fd $content
    close $fd
}

# ── 3. Apply PIPESIM_CLK_MASTER=TRUE patch to RP sim wrapper ─────────
#    (design_rp BD → bd_*_cpm_0_0.sv under firesim.gen)
puts "Patching RP sim wrappers (PIPESIM_CLK_MASTER=TRUE)..."
set rp_search_dir "$proj_dir/firesim.gen/sources_1/bd/design_rp"
set rp_files [find_files $rp_search_dir "bd_*_cpm_0_0.sv"]
puts "  Found [llength $rp_files] RP wrapper file(s)"
foreach f $rp_files {
    puts "  Patching RP: $f"
    set fd [open $f r]
    set content [read $fd]
    close $fd
    set content [string map {".C_CPM_PIPESIM_CLK_MASTER(\"FALSE\")" ".C_CPM_PIPESIM_CLK_MASTER(\"TRUE\")"} $content]
    set fd [open $f w]
    puts -nonewline $fd $content
    close $fd
}

# ── 4. Export VCS simulation scripts ──────────────────────────────────
set export_dir "$cl_dir/vcs"
set lib_map    "$verif_dir/vcs_xilinx_lib"

puts ""
puts "Exporting VCS simulation scripts..."
puts "  Export dir  : $export_dir"
puts "  Lib map path: $lib_map"

export_simulation -simulator vcs \
    -lib_map_path $lib_map \
    -directory $export_dir \
    -force

# ── 5. Report ─────────────────────────────────────────────────────────
close_project

puts ""
puts "================================================================"
puts "VCS simulation scripts exported."
puts ""
puts "  Output directory: $export_dir"
puts "  Run: cd $export_dir/vcs && bash board.sh"
puts "  (or use compile.sh + elaborate.sh + simulate.sh separately)"
puts "================================================================"
