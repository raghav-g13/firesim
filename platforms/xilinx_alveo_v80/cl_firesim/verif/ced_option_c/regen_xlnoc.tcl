# Regenerate xlnoc BFM output products from stock project
open_project /scratch/raghavgupta/v80-chipyard/sims/firesim/platforms/xilinx_alveo_v80/cl_firesim/verif/ced_stock/proj/ced_stock.xpr

# Generate xlnoc simulation targets
set xlnoc_bd [get_files -of [get_filesets sim_1] xlnoc.bd]
if {$xlnoc_bd ne ""} {
    generate_target simulation [get_files $xlnoc_bd]
    puts "=== xlnoc simulation targets generated ==="
} else {
    puts "ERROR: xlnoc.bd not found in stock project"
}

close_project
