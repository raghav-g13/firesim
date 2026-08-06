// Include standard Xilinx QDMA tests only for CED designs (not FireSim)
// The sample_tests.vh has cross-module references to axi_bram_ctrl_0
// which doesn't exist in the FireSim design hierarchy.
`ifndef FIRESIM_EP
`include "sample_tests.vh"
`endif
// Include FireSim-specific tests
`include "tests_firesim.vh"
