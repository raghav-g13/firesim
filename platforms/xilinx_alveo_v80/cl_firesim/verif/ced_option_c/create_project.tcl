# create_project.tcl — Create Option C (production CIPS config) PIPESIM project
# Based on ced_pcie0 project with modified CIPS parameters (dev ID 903F, production BARs)
# Run: vivado -mode batch -source create_project.tcl

set script_dir [file dirname [file normalize [info script]]]
set ced_dir "/ecad/tools/xilinx/2025.1/data/xhub/ced/XilinxCEDStore/ced/Xilinx/IPI/Versal_CPM_QDMA_EP_Simulation_Design/cpm5_qdma"

# 1. Create project
create_project ced_option_c $script_dir/proj -part xcv80-lsva4737-2MHP-e-S -force
set_property target_simulator VCS [current_project]
set_property "compxlib.vcs_compiled_library_dir" "/scratch/raghavgupta/v80-chipyard/sims/firesim/platforms/xilinx_alveo_v80/cl_firesim/verif/vcs_xilinx_lib" [current_project]

# 2. Create design_1 BD (CED-based with production CIPS config)
create_bd_design design_1
source $script_dir/design_1_option_c_ced_based_bd.tcl

# 3. Create BD wrapper
make_wrapper -files [get_files design_1.bd] -top

# 4. Create design_rp BD (unchanged from CED)
source $ced_dir/design_rp_bd.tcl

# 5. Make RP wrapper
make_wrapper -files [get_files design_rp.bd] -top

# 6. Generate output products
generate_target all [get_files design_1.bd]
generate_target all [get_files design_rp.bd]

# 7. Add pre-created sim wrapper (reused from ced_pcie0 — same PCIE0 port topology)
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
# Use Option C patched usrapp_tx (stubbed COMPARE_DATA_H2C + DEV_ID=903F + user_bar=1)
add_files -fileset sim_1 $script_dir/src/usp_pci_exp_usrapp_tx_patched.v
# Add our testbench
set verif_dir [file dirname $script_dir]
add_files -fileset sim_1 $verif_dir/board_option_c.v

# Set top module
set_property top board [get_filesets sim_1]

# 9. Generate VCS simulation scripts
launch_simulation -scripts_only

puts "=== Option C project created successfully ==="
puts "Next: set up VCS compile flow (adapt from ced_pcie0) and run"
