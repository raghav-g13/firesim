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
    $display("[%t] LINK_MON: starting (CDO done, monitoring every 10us)", $realtime);
    forever begin
      #10_000_000;
      $display("[%t] LINK: user_lnk_up=%b ltssm=%h pipe_cmd_ep=%h pipe_cmd_rp=%h",
        $realtime,
        board.RP.user_lnk_up,
        board.RP.cfg_ltssm_state,
        board.EP.overall_fpga_top_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out);
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

  // RP: Xilinx Root Port BFM — must match EP link config (x16 Gen3)
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
  end

endmodule
