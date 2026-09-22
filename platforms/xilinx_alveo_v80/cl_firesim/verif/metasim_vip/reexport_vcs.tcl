# reexport_vcs.tcl — Re-export VCS scripts from existing VIP metasim project
# Usage: vivado -mode batch -source reexport_vcs.tcl [-tclargs <CL_DIR>]

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

puts "Exporting VCS scripts to: $export_dir"
export_simulation -simulator vcs \
    -lib_map_path $lib_map \
    -directory $export_dir \
    -force

close_project
puts "Done. VCS scripts at: $export_dir/vcs/"
