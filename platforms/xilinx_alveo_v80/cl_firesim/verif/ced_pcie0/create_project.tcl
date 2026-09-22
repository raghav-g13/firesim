# create_project.tcl — Create CED PCIE0 EP PIPESIM project
# Run: vivado -mode batch -source create_project.tcl

set script_dir [file dirname [file normalize [info script]]]
set ced_dir "/ecad/tools/xilinx/2025.1/data/xhub/ced/XilinxCEDStore/ced/Xilinx/IPI/Versal_CPM_QDMA_EP_Simulation_Design/cpm5_qdma"

# 1. Create project
create_project ced_pcie0 $script_dir/proj -part xcv80-lsva4737-2MHP-e-S -force
set_property target_simulator VCS [current_project]
set_property "compxlib.vcs_compiled_library_dir" "/scratch/raghavgupta/v80-chipyard/sims/firesim/platforms/xilinx_alveo_v80/cl_firesim/verif/vcs_xilinx_lib" [current_project]

# 2. Create design_1 BD (PCIE0 variant)
create_bd_design design_1
source $script_dir/design_1_pcie0_bd.tcl

# 3. Create BD wrapper
make_wrapper -files [get_files design_1.bd] -top

# 4. Create design_rp BD (unchanged from CED)
source $ced_dir/design_rp_bd.tcl

# 5. Make RP wrapper
make_wrapper -files [get_files design_rp.bd] -top

# 6. Generate output products for both BDs (creates sim_wrapper)
generate_target all [get_files design_1.bd]
generate_target all [get_files design_rp.bd]

# 7. Add pre-created sim wrapper (stock CED version with PCIE1→PCIE0 port rename)
set sim_wrapper "$script_dir/design_1_wrapper_sim_wrapper.v"
add_files -fileset sources_1 $sim_wrapper
set_property file_type {Verilog} [get_files $sim_wrapper]

# 8. Add simulation sources from CED
set sim_files_dir "$ced_dir/sim_files"
add_files -fileset sim_1 [glob $sim_files_dir/board_common.vh]
add_files -fileset sim_1 [glob $sim_files_dir/usp_pci_exp_usrapp_com.v]
add_files -fileset sim_1 [glob $sim_files_dir/usp_pci_exp_usrapp_rx.v]
add_files -fileset sim_1 [glob $sim_files_dir/sample_tests.vh]
add_files -fileset sim_1 [glob $sim_files_dir/tests.vh]
# Use our patched usrapp_tx (stubbed COMPARE_DATA_H2C)
set verif_dir [file dirname $script_dir]
add_files -fileset sim_1 $verif_dir/ced_stock/proj/ced_stock.sim/sim_1/behav/vcs/usp_pci_exp_usrapp_tx_patched.v
# Add our testbench
add_files -fileset sim_1 $verif_dir/board_ced_pcie0.v

# Set top module
set_property top board [get_filesets sim_1]

# 9. Generate VCS simulation scripts (compiles all BD/IP sources inline)
launch_simulation -scripts_only

puts "=== Project created successfully ==="
puts "Next: cd to VCS sim dir and run compile/elaborate/simulate"
