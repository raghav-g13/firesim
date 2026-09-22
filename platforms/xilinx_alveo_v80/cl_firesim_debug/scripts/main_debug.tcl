# main_debug.tcl
#
# Simplified Vivado batch build script for the V80 BRAM-loopback debug design.
# Runs synthesis, implementation, and writes a PDI.
#
# Usage:
#   vivado -mode batch -source scripts/main_debug.tcl

set root_dir [pwd]

# ---- Part / board ----
set part       xcv80-lsva4737-2MHP-e-S
set board_part xilinx.com:v80:part0:1.0

set jobs 8

# ---- Utilities ----
proc check_file_exists { inFile } {
    if {![file exists $inFile]} {
        puts "ERROR: Could not find $inFile"
        exit 1
    }
}

proc check_progress { run errmsg } {
    set progress [get_property PROGRESS ${run}]
    if {$progress != "100%"} {
        puts "ERROR: $errmsg (progress at $progress/%100)"
        exit 1
    }
}

# ---- Create project ----
# Note: build_debug.sh already cleans vivado_proj/ before launching Vivado.
# Do NOT delete it here — tee is writing to vivado_proj/build_console.log.
create_project -force firesim_debug ${root_dir}/vivado_proj -part $part
set_property board_part $board_part [current_project]

# ---- Add design sources ----
add_files ${root_dir}/design/overall_fpga_top_debug.v
update_compile_order -fileset sources_1

# ---- Create block design ----
check_file_exists ${root_dir}/scripts/create_bd_debug.tcl
source ${root_dir}/scripts/create_bd_debug.tcl
create_debug_design

# ---- Generate BD wrapper / targets ----
set bd_file [get_files design_1.bd]
generate_target all $bd_file
update_compile_order -fileset sources_1

# ---- Set top module ----
set top_level_name overall_fpga_top_debug
set_property top $top_level_name [current_fileset]
update_compile_order -fileset sources_1

# ---- Add DDR4 pin constraints ----
set ddr4_xdc ${root_dir}/../cl_firesim/design/v80_ddr4_pins.xdc
if {[file exists $ddr4_xdc]} {
    add_files -fileset constrs_1 $ddr4_xdc
    puts "INFO: Added DDR4 pin constraints from $ddr4_xdc"
} else {
    puts "WARNING: DDR4 pin constraints not found at $ddr4_xdc"
}

# ---- Report IP status ----
report_ip_status

# ---- Reports directory ----
set rpt_dir ${root_dir}/vivado_proj/reports
file mkdir ${rpt_dir}

# ---- Synthesis ----
set synth_run [get_runs synth_1]
reset_runs ${synth_run}

set_property -dict [ list \
    STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE {default} \
    {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} {-flatten_hierarchy rebuilt} \
] ${synth_run}

puts "INFO: launching synthesis"
launch_runs ${synth_run} -jobs ${jobs}
wait_on_run ${synth_run}
check_progress ${synth_run} "synthesis failed"

# ---- Post-synth: fix BUFGCE SIM_DEVICE for Versal ----
open_run synth_1
foreach cell [get_cells -hierarchical -filter {REF_NAME == BUFGCE} -quiet] {
    set_property SIM_DEVICE VERSAL_HBM $cell
}
report_utilization -hierarchical -hierarchical_percentages -file ${rpt_dir}/post_synth_utilization.rpt
close_design

# ---- Implementation ----
set impl_run [get_runs impl_1]
reset_runs ${impl_run}

# Default directives -- no timing pressure for a tiny debug design
set_property STEPS.OPT_DESIGN.IS_ENABLED 1 ${impl_run}

puts "INFO: launching implementation"
launch_runs ${impl_run} -to_step route_design -jobs ${jobs}
wait_on_run ${impl_run}
check_progress ${impl_run} "implementation failed"

# ---- Post-impl reports ----
open_run impl_1
report_timing_summary -file ${rpt_dir}/final_timing_summary.rpt
report_utilization -hierarchical -hierarchical_percentages -file ${rpt_dir}/final_utilization.rpt
close_design

# ---- Write PDI ----
puts "INFO: generating device image (PDI)"
launch_runs ${impl_run} -to_step write_device_image -jobs ${jobs}
wait_on_run ${impl_run}
check_progress ${impl_run} "device image generation failed"

# ---- Copy PDI to known location ----
set src_pdi ${root_dir}/vivado_proj/firesim_debug.runs/impl_1/${top_level_name}.pdi
set dst_pdi ${root_dir}/vivado_proj/firesim_debug.pdi

file copy -force $src_pdi $dst_pdi
puts "INFO: PDI written to $dst_pdi"

puts "Done!"
exit 0
