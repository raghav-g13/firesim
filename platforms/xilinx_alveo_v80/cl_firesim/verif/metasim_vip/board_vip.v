// board_vip.v — VIP-based VCS metasim testbench for V80 FireSim
//
// EP = overall_fpga_top_sim_wrapper (Vivado-generated: overall_fpga_top + xlnoc fabric)
// RP = xilinx_pcie5_versal_rp (CED Root Port BFM)
// Communication = PIPESIM (bypasses GT transceivers for fast simulation)
//
// This testbench uses the Vivado-generated sim_wrapper which already
// instantiates xlnoc and does the cross-hierarchy NPS↔axi_noc connects.
// The EP hierarchy is one level deeper than board_firesim.v:
//   board.EP.overall_fpga_top_i.design_1_i.* (vs board.EP.design_1_i.*)

`timescale 1ps/1ps
`include "board_common.vh"
`define SIMULATION

module board;

  parameter          REF_CLK_FREQ       = 0;  // 0=100MHz
  localparam         REF_CLK_HALF_CYCLE = (REF_CLK_FREQ == 0) ? 5000 :
                                          (REF_CLK_FREQ == 1) ? 4000 :
                                          (REF_CLK_FREQ == 2) ? 2000 : 0;
  localparam [2:0]   PF0_DEV_CAP_MAX_PAYLOAD_SIZE = 3'b010;
  localparam [4:0]   LINK_WIDTH = 5'd16;
  localparam         EP_DATA_WIDTH = 512;

  reg sys_rst_n;

  wire ep_sys_clk_p, ep_sys_clk_n;
  wire rp_sys_clk_p, rp_sys_clk_n;
  wire ddr4_sys_clk_p, ddr4_sys_clk_n;

  sys_clk_gen_ds #(.halfcycle(REF_CLK_HALF_CYCLE), .offset(0))
    CLK_GEN_RP (.sys_clk_p(rp_sys_clk_p), .sys_clk_n(rp_sys_clk_n));

  sys_clk_gen_ds #(.halfcycle(REF_CLK_HALF_CYCLE), .offset(0))
    CLK_GEN_EP (.sys_clk_p(ep_sys_clk_p), .sys_clk_n(ep_sys_clk_n));

  sys_clk_gen_ds #(.halfcycle(2500), .offset(0))
    CLK_GEN_DDR4 (.sys_clk_p(ddr4_sys_clk_p), .sys_clk_n(ddr4_sys_clk_n));

  wire [(LINK_WIDTH-1):0] ep_pci_exp_txn, ep_pci_exp_txp;
  wire [(LINK_WIDTH-1):0] rp_pci_exp_txn, rp_pci_exp_txp;

  parameter ON=3, OFF=4, UNIQUE=32, UNIQUE0=64, PRIORITY=128;

  // PIPESIM enable — hierarchy goes through overall_fpga_top_i in the sim_wrapper
  defparam board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.C_CPM_PIPESIM = "TRUE";
  defparam board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.C_CPM_PIPESIM = "TRUE";

  // PIPESIM PIPE signal cross-connections (EP ↔ RP)
  initial begin
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_in =
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_in =
          board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out;

    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_0  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_0;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_1  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_1;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_2  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_2;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_3  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_3;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_4  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_4;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_5  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_5;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_6  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_6;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_7  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_7;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_8  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_8;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_9  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_9;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_10 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_10;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_11 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_11;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_12 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_12;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_13 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_13;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_14 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_14;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_15 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_15;

    // RP RX lanes 0-7: cross-connect from EP TX
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_0  = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_0;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_1  = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_2  = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_2;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_3  = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_3;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_4  = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_4;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_5  = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_5;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_6  = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_6;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_7  = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_7;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_8  = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_8;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_9  = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_9;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_10 = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_10;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_11 = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_11;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_12 = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_12;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_13 = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_13;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_14 = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_14;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_15 = board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_15;
  end

  // PS9 VIP configuration + Reset sequencing
  initial begin
    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.en_multi_clock_support();
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.en_multi_clock_support();

    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(0, 250);
    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(1, 250);
    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(2, 250);
    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(3, 250);

    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(0, 250);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(1, 250);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(2, 250);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(3, 250);

    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI0", "PSNOCPCIAXI0", 1);
    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI1", "PSNOCPCIAXI1", 1);
    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("NOCPSPCIAXI0", "PSCPMPCIEAXI", 1);

    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI0", "PSNOCPCIAXI0", 1);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI1", "PSNOCPCIAXI1", 1);

    $display("[%t] System Reset Asserted", $realtime);
    sys_rst_n = 1'b0;

    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b0;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b0;
    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'h0);
    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(0);

    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b0;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b0;
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'h0);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(0);

    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b0;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b0;

    repeat (500) @(posedge rp_sys_clk_p);
    $display("[%t] System Reset De-asserted", $realtime);
    sys_rst_n = 1'b1;

    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'hF);
    board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(1);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'hF);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(1);

    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b1;

    wait(board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    wait(board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    $display("[%t] CDO programming done on both EP and RP", $realtime);

    $display("[%t] Releasing PERST on EP and RP", $realtime);
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b1;
    force board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b1;
  end

  initial begin
    wait(board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    wait(board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    $display("[%t] LINK_MON: starting (CDO done, monitoring every 2us)", $realtime);
    forever begin
      #2_000_000;
      $display("[%t] LINK: user_lnk_up=%b ltssm=%h pipe_cmd_ep=%h pipe_cmd_rp=%h rp_tx8=%h",
        $realtime,
        board.RP.user_lnk_up,
        board.RP.cfg_ltssm_state,
        board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_8);
    end
  end

  // EP: overall_fpga_top_sim_wrapper (includes overall_fpga_top + xlnoc fabric BFM)
  overall_fpga_top_sim_wrapper EP (
    .sys_clk0_1_clk_p (ddr4_sys_clk_p),
    .sys_clk0_1_clk_n (ddr4_sys_clk_n),

    .pci_express_x16_gtx_n (ep_pci_exp_txn),
    .pci_express_x16_gtx_p (ep_pci_exp_txp),
    .pci_express_x16_grx_n (rp_pci_exp_txn),
    .pci_express_x16_grx_p (rp_pci_exp_txp),

    .pcie_refclk_clk_p (ep_sys_clk_p),
    .pcie_refclk_clk_n (ep_sys_clk_n)
  );

  // RP: Xilinx Root Port BFM — x16 Gen4 to match EP
  xilinx_pcie5_versal_rp #(
    .PF0_DEV_CAP_MAX_PAYLOAD_SIZE (PF0_DEV_CAP_MAX_PAYLOAD_SIZE),
    .PL_LINK_CAP_MAX_LINK_WIDTH   (5'd16),
    .PL_LINK_CAP_MAX_LINK_SPEED   (4)
  ) RP (
    .sys_clk_n  (rp_sys_clk_n),
    .sys_clk_p  (rp_sys_clk_p),
    .sys_rst_n  (sys_rst_n),
    .pci_exp_txn (rp_pci_exp_txn),
    .pci_exp_txp (rp_pci_exp_txp),
    .pci_exp_rxn (ep_pci_exp_txn),
    .pci_exp_rxp (ep_pci_exp_txp)
  );

  initial begin
    if ($test$plusargs("dump_all")) begin
      $dumpfile("board.vcd");
      $dumpvars(0, board);
    end
    if ($test$plusargs("dump_fsdb")) begin
      $fsdbDumpfile("board.fsdb");
      $fsdbDumpvars(0, board);
      $display("[%t] FSDB: dumping full board hierarchy", $realtime);
    end
    else if ($test$plusargs("dump_firesim")) begin
      $fsdbDumpfile("firesim.fsdb");
      $fsdbDumpvars(0, board.EP.overall_fpga_top_i.firesim_top);
      $fsdbDumpvars(0, board.u_driver_bridge);
      $display("[%t] FSDB: dumping FireSim target + driver_bridge only", $realtime);
    end
  end

  // Driver bridge — enabled by the driver_test case in tests_firesim.vh
  // after CED system init (BAR init, user_bar discovery) completes.
  // The test case sets driver_bridge_enable = 1 to start the DPI FIFO loop.
  reg driver_bridge_enable;
  wire [31:0] driver_bridge_cmd_count;
  wire driver_bridge_done, driver_bridge_pass;

  driver_bridge u_driver_bridge (
    .enable      (driver_bridge_enable),
    .cmd_count   (driver_bridge_cmd_count),
    .done        (driver_bridge_done),
    .pass        (driver_bridge_pass)
  );

  initial begin
    driver_bridge_enable = 1'b0;
  end

  // AXI bus monitor — probes at two levels:
  // 1. F1Shim io_master (port-level, shows what external AXI-Lite sees)
  // 2. NastiRouter master port (internal ctrl AXI, shows xbar input)
  wire mon_clk   = board.EP.overall_fpga_top_i.firesim_top.clock;
  wire mon_reset = board.EP.overall_fpga_top_i.firesim_top.reset;

  // --- F1Shim io_master (external-facing, AXI-Lite side) ---
  wire ext_b_valid = board.EP.overall_fpga_top_i.firesim_top.io_master_b_valid;
  wire ext_b_ready = board.EP.overall_fpga_top_i.firesim_top.io_master_b_ready;
  wire ext_aw_valid = board.EP.overall_fpga_top_i.firesim_top.io_master_aw_valid;
  wire ext_aw_ready = board.EP.overall_fpga_top_i.firesim_top.io_master_aw_ready;
  wire ext_ar_valid = board.EP.overall_fpga_top_i.firesim_top.io_master_ar_valid;
  wire ext_ar_ready = board.EP.overall_fpga_top_i.firesim_top.io_master_ar_ready;
  wire ext_r_valid = board.EP.overall_fpga_top_i.firesim_top.io_master_r_valid;
  wire ext_r_ready = board.EP.overall_fpga_top_i.firesim_top.io_master_r_ready;

  // --- NastiRouter master port (internal) ---
  wire mon_aw_valid = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_aw_valid;
  wire mon_aw_ready = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_aw_ready;
  wire [24:0] mon_aw_addr = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_aw_bits_addr;
  wire [11:0] mon_aw_id = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_aw_bits_id;

  wire mon_w_valid = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_w_valid;
  wire mon_w_ready = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_w_ready;
  wire [31:0] mon_w_data = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_w_bits_data;

  wire mon_b_valid = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_b_valid;
  wire mon_b_ready = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_b_ready;
  wire [11:0] mon_b_id = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_b_bits_id;
  wire [1:0]  mon_b_resp = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_b_bits_resp;

  wire mon_ar_valid = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_ar_valid;
  wire mon_ar_ready = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_ar_ready;
  wire [24:0] mon_ar_addr = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_ar_bits_addr;
  wire [11:0] mon_ar_id = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_ar_bits_id;

  wire mon_r_valid = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_r_valid;
  wire mon_r_ready = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_r_ready;
  wire [31:0] mon_r_data = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_r_bits_data;
  wire [11:0] mon_r_id = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.io_master_r_bits_id;

  // --- B arbiter probes (all 10 inputs + chosen + lastGrant) ---
  wire barb_in0_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_in_0_valid;
  wire barb_in1_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_in_1_valid;
  wire barb_in2_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_in_2_valid;
  wire barb_in3_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_in_3_valid;
  wire barb_in4_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_in_4_valid;
  wire barb_in5_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_in_5_valid;
  wire barb_in6_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_in_6_valid;
  wire barb_in7_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_in_7_valid;
  wire barb_in8_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_in_8_valid;
  wire barb_in9_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_in_9_valid;
  wire [3:0] barb_chosen = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_chosen;
  wire [3:0] barb_lastgrant = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.ctrl_validMask_grantMask_lastGrant;
  wire barb_out_v = board.EP.overall_fpga_top_i.firesim_top.top.ctrlInterconnect.xbar.router.b_arb.io_out_valid;

  // --- DDR4 bus probes (io_slave_0 = LoadMem + FASED → DDR4) ---
  wire ddr_aw_valid = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_aw_valid;
  wire ddr_aw_ready = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_aw_ready;
  wire [34:0] ddr_aw_addr = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_aw_bits_addr;
  wire [7:0]  ddr_aw_len  = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_aw_bits_len;
  wire [2:0]  ddr_aw_size = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_aw_bits_size;
  wire [15:0] ddr_aw_id   = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_aw_bits_id;

  wire ddr_w_valid  = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_w_valid;
  wire ddr_w_ready  = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_w_ready;
  wire [63:0] ddr_w_data = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_w_bits_data;
  wire [7:0]  ddr_w_strb = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_w_bits_strb;
  wire ddr_w_last   = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_w_bits_last;

  wire ddr_b_valid  = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_b_valid;
  wire ddr_b_ready  = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_b_ready;
  wire [15:0] ddr_b_id   = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_b_bits_id;
  wire [1:0]  ddr_b_resp = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_b_bits_resp;

  wire ddr_ar_valid = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_ar_valid;
  wire ddr_ar_ready = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_ar_ready;
  wire [34:0] ddr_ar_addr = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_ar_bits_addr;
  wire [7:0]  ddr_ar_len  = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_ar_bits_len;
  wire [15:0] ddr_ar_id   = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_ar_bits_id;

  wire ddr_r_valid  = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_r_valid;
  wire ddr_r_ready  = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_r_ready;
  wire [63:0] ddr_r_data  = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_r_bits_data;
  wire [15:0] ddr_r_id    = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_r_bits_id;
  wire ddr_r_last   = board.EP.overall_fpga_top_i.firesim_top.io_slave_0_r_bits_last;

  integer ddr_aw_cnt = 0;
  integer ddr_w_cnt  = 0;
  integer ddr_b_cnt  = 0;
  integer ddr_ar_cnt = 0;
  integer ddr_r_cnt  = 0;
  integer ddr_aw_stall_cnt = 0;

  integer mon_aw_cnt = 0;
  integer mon_b_cnt = 0;
  integer mon_cycle = 0;
  reg mon_x_logged = 0;
  reg [9:0] prev_barb_inv;

  always @(posedge mon_clk) begin
    if (!mon_reset) begin
      mon_cycle <= mon_cycle + 1;

      // --- Handshake events (NastiRouter internal) ---
      if (mon_aw_valid && mon_aw_ready) begin
        mon_aw_cnt <= mon_aw_cnt + 1;
        $display("[%t] [AXI_MON] AW #%0d: addr=0x%h id=0x%h", $realtime, mon_aw_cnt, mon_aw_addr, mon_aw_id);
      end
      if (mon_w_valid && mon_w_ready)
        $display("[%t] [AXI_MON] W:  data=0x%h", $realtime, mon_w_data);
      if (mon_b_valid && mon_b_ready) begin
        mon_b_cnt <= mon_b_cnt + 1;
        $display("[%t] [AXI_MON] B  #%0d: id=0x%h resp=%0d", $realtime, mon_b_cnt, mon_b_id, mon_b_resp);
      end
      if (mon_ar_valid && mon_ar_ready)
        $display("[%t] [AXI_MON] AR: addr=0x%h id=0x%h", $realtime, mon_ar_addr, mon_ar_id);
      if (mon_r_valid && mon_r_ready)
        $display("[%t] [AXI_MON] R:  data=0x%h id=0x%h", $realtime, mon_r_data, mon_r_id);

      // --- B arbiter X detection: dump once when ext_b_valid becomes X ---
      if ($isunknown(ext_b_valid) && !mon_x_logged) begin
        mon_x_logged <= 1;
        $display("[%t] [AXI_MON] *** X DETECTED on ext_b_valid! ***", $realtime);
        $display("[%t] [AXI_MON]   barb inputs: %b %b %b %b %b %b %b %b %b %b",
                 $realtime, barb_in0_v, barb_in1_v, barb_in2_v, barb_in3_v, barb_in4_v,
                 barb_in5_v, barb_in6_v, barb_in7_v, barb_in8_v, barb_in9_v);
        $display("[%t] [AXI_MON]   barb chosen=%h lastGrant=%h out_valid=%b",
                 $realtime, barb_chosen, barb_lastgrant, barb_out_v);
        $display("[%t] [AXI_MON]   int_b: valid=%b ready=%b  ext_b: valid=%b ready=%b",
                 $realtime, mon_b_valid, mon_b_ready, ext_b_valid, ext_b_ready);
      end

      // --- Log any b_arb input transition to X (first time per input) ---
      if ($isunknown(barb_in0_v) && !$isunknown(prev_barb_inv[0]))
        $display("[%t] [AXI_MON] b_arb_in[0] went X", $realtime);
      if ($isunknown(barb_in1_v) && !$isunknown(prev_barb_inv[1]))
        $display("[%t] [AXI_MON] b_arb_in[1] went X", $realtime);
      if ($isunknown(barb_in2_v) && !$isunknown(prev_barb_inv[2]))
        $display("[%t] [AXI_MON] b_arb_in[2] went X", $realtime);
      if ($isunknown(barb_in3_v) && !$isunknown(prev_barb_inv[3]))
        $display("[%t] [AXI_MON] b_arb_in[3] went X", $realtime);
      if ($isunknown(barb_in4_v) && !$isunknown(prev_barb_inv[4]))
        $display("[%t] [AXI_MON] b_arb_in[4] went X", $realtime);
      if ($isunknown(barb_in5_v) && !$isunknown(prev_barb_inv[5]))
        $display("[%t] [AXI_MON] b_arb_in[5] went X", $realtime);
      if ($isunknown(barb_in6_v) && !$isunknown(prev_barb_inv[6]))
        $display("[%t] [AXI_MON] b_arb_in[6] went X", $realtime);
      if ($isunknown(barb_in7_v) && !$isunknown(prev_barb_inv[7]))
        $display("[%t] [AXI_MON] b_arb_in[7] went X", $realtime);
      if ($isunknown(barb_in8_v) && !$isunknown(prev_barb_inv[8]))
        $display("[%t] [AXI_MON] b_arb_in[8] went X", $realtime);
      if ($isunknown(barb_in9_v) && !$isunknown(prev_barb_inv[9]))
        $display("[%t] [AXI_MON] b_arb_in[9] went X", $realtime);

      prev_barb_inv <= {barb_in9_v, barb_in8_v, barb_in7_v, barb_in6_v, barb_in5_v,
                        barb_in4_v, barb_in3_v, barb_in2_v, barb_in1_v, barb_in0_v};

      // --- Stall detection (AW stall, first time only) ---
      if (mon_aw_valid && !mon_aw_ready && mon_cycle > 100 && !mon_x_logged)
        $display("[%t] [AXI_MON] STALL: AW valid but NOT ready (addr=0x%h id=0x%h)", $realtime, mon_aw_addr, mon_aw_id);

      // --- DDR4 bus (io_slave_0) handshake events ---
      if (ddr_aw_valid && ddr_aw_ready) begin
        ddr_aw_cnt <= ddr_aw_cnt + 1;
        $display("[%t] [DDR_MON] AW #%0d: addr=0x%h len=%0d size=%0d id=0x%h",
                 $realtime, ddr_aw_cnt, ddr_aw_addr, ddr_aw_len, ddr_aw_size, ddr_aw_id);
      end
      if (ddr_w_valid && ddr_w_ready) begin
        ddr_w_cnt <= ddr_w_cnt + 1;
        if (ddr_w_cnt < 20 || ddr_w_last)
          $display("[%t] [DDR_MON] W  #%0d: data=0x%h strb=0x%h last=%b",
                   $realtime, ddr_w_cnt, ddr_w_data, ddr_w_strb, ddr_w_last);
      end
      if (ddr_b_valid && ddr_b_ready) begin
        ddr_b_cnt <= ddr_b_cnt + 1;
        $display("[%t] [DDR_MON] B  #%0d: id=0x%h resp=%0d", $realtime, ddr_b_cnt, ddr_b_id, ddr_b_resp);
      end
      if (ddr_ar_valid && ddr_ar_ready) begin
        ddr_ar_cnt <= ddr_ar_cnt + 1;
        if (ddr_ar_cnt < 50)
          $display("[%t] [DDR_MON] AR #%0d: addr=0x%h len=%0d id=0x%h",
                   $realtime, ddr_ar_cnt, ddr_ar_addr, ddr_ar_len, ddr_ar_id);
      end
      if (ddr_r_valid && ddr_r_ready) begin
        ddr_r_cnt <= ddr_r_cnt + 1;
        if (ddr_r_cnt < 50)
          $display("[%t] [DDR_MON] R  #%0d: data=0x%h id=0x%h last=%b",
                   $realtime, ddr_r_cnt, ddr_r_data, ddr_r_id, ddr_r_last);
      end

      // --- DDR4 stall detection ---
      if (ddr_aw_valid && !ddr_aw_ready && ddr_aw_stall_cnt < 3) begin
        ddr_aw_stall_cnt <= ddr_aw_stall_cnt + 1;
        if (ddr_aw_stall_cnt == 0)
          $display("[%t] [DDR_MON] AW STALL: valid but NOT ready (addr=0x%h)", $realtime, ddr_aw_addr);
      end else if (!ddr_aw_valid || ddr_aw_ready)
        ddr_aw_stall_cnt <= 0;

      // --- Periodic state dump every 5000 cycles ---
      if (mon_cycle % 5000 == 0 && mon_cycle > 0) begin
        $display("[%t] [AXI_MON] P cyc=%0d: ext_aw=%b/%b ext_b=%b/%b | barb_in={%b%b%b%b%b%b%b%b%b%b} chosen=%h lg=%h out=%b",
                 $realtime, mon_cycle,
                 ext_aw_valid, ext_aw_ready, ext_b_valid, ext_b_ready,
                 barb_in0_v, barb_in1_v, barb_in2_v, barb_in3_v, barb_in4_v,
                 barb_in5_v, barb_in6_v, barb_in7_v, barb_in8_v, barb_in9_v,
                 barb_chosen, barb_lastgrant, barb_out_v);
        $display("[%t] [DDR_MON] P cyc=%0d: aw=%0d w=%0d b=%0d ar=%0d r=%0d | aw_v/r=%b/%b ar_v/r=%b/%b",
                 $realtime, mon_cycle,
                 ddr_aw_cnt, ddr_w_cnt, ddr_b_cnt, ddr_ar_cnt, ddr_r_cnt,
                 ddr_aw_valid, ddr_aw_ready, ddr_ar_valid, ddr_ar_ready);
      end
    end
  end

endmodule
