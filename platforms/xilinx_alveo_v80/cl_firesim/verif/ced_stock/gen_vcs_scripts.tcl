open_project /scratch/raghavgupta/v80-chipyard/sims/firesim/platforms/xilinx_alveo_v80/cl_firesim/verif/ced_stock/proj/ced_stock.xpr
set_property target_simulator VCS [current_project]
set_property compxlib.vcs_compiled_library_dir /ecad/tools/xilinx/2025.1/data/simmodels/vcs/W-2024.09-SP1/lnx64 [current_project]
launch_simulation -scripts_only
close_project
