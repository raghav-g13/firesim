# gen_sim_files.tcl — Generate missing simulation IP user files
# Run: vivado -mode batch -source gen_sim_files.tcl

set script_dir [file dirname [file normalize [info script]]]
open_project $script_dir/proj/ced_pcie0.xpr

# Generate simulation IP user files (xlnoc, GT quad models, etc.)
export_ip_user_files -of_objects [get_ips] -no_script -sync -force -quiet
update_compile_order -fileset sim_1

# Re-generate simulation scripts with full file list
launch_simulation -scripts_only

close_project
puts "=== Simulation files generated ==="
