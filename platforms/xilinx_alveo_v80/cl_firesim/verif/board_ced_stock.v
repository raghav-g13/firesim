// board_ced_stock.v — Stock CED testbench with link monitor
// EP uses PCIE1, RP uses PCIE0 (Xilinx default CED configuration)

`timescale 1ps/1ps
`include "board_common.vh"
`define SIMULATION

module board;

  parameter          REF_CLK_FREQ       = 0;
  localparam         REF_CLK_HALF_CYCLE = (REF_CLK_FREQ == 0) ? 5000 :
                                          (REF_CLK_FREQ == 1) ? 4000 :
                                          (REF_CLK_FREQ == 2) ? 2000 : 0;
  localparam [2:0]   PF0_DEV_CAP_MAX_PAYLOAD_SIZE = 3'b010;
  localparam [4:0]   LINK_WIDTH = 5'd8;
  localparam         EP_DATA_WIDTH = 512;

  reg sys_rst_n;

  wire ep_sys_clk_p, ep_sys_clk_n;
  wire rp_sys_clk_p, rp_sys_clk_n;
  wire [(LINK_WIDTH-1):0] ep_pci_exp_txn, ep_pci_exp_txp;
  wire [(LINK_WIDTH-1):0] rp_pci_exp_txn, rp_pci_exp_txp;

  sys_clk_gen_ds #(.halfcycle(REF_CLK_HALF_CYCLE), .offset(0))
    CLK_GEN_RP (.sys_clk_p(rp_sys_clk_p), .sys_clk_n(rp_sys_clk_n));

  sys_clk_gen_ds #(.halfcycle(REF_CLK_HALF_CYCLE), .offset(0))
    CLK_GEN_EP (.sys_clk_p(ep_sys_clk_p), .sys_clk_n(ep_sys_clk_n));

  parameter ON=3, OFF=4, UNIQUE=32, UNIQUE0=64, PRIORITY=128;

  // ── PIPESIM enable ────────────────────────────────────────────────
  defparam board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.C_CPM_PIPESIM = "TRUE";
  defparam board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.C_CPM_PIPESIM = "TRUE";

  // ── PIPESIM PIPE connections: EP pcie1 <-> RP pcie0 ───────────────
  // NOTE: No BUFGGT mask or pipe_clk forces needed. With C_CPM_PIPESIM=TRUE
  // (set via sim wrapper patching), the BUFGGT naturally generates txusrclk
  // from the pipe_sim_model reference clocks. pipe_clk = txusrclk keeps the
  // pipe_sim_model synchronous with SecureIP. Forcing pipe_clk = pipe_clk_fr
  // breaks this synchronous relationship and causes receiver detect failure.
  initial begin
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_commands_in =
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_in =
          board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_commands_out;

    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_0  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_0;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_1  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_1;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_2  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_2;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_3  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_3;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_4  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_4;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_5  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_5;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_6  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_6;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_7  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_7;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_8  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_8;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_9  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_9;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_10 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_10;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_11 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_11;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_12 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_12;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_13 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_13;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_14 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_14;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_rx_15 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_15;

    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_0  = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_0;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_1  = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_2  = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_2;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_3  = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_3;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_4  = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_4;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_5  = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_5;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_6  = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_6;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_7  = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_7;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_8  = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_8;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_9  = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_9;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_10 = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_10;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_11 = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_11;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_12 = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_12;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_13 = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_13;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_14 = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_14;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_15 = board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_15;
  end

  // ── PS9 VIP + Reset sequencing (from CED board.v) ────────────────
  initial begin
    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.en_multi_clock_support();
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.en_multi_clock_support();

    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(0, 250);
    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(1, 250);
    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(2, 250);
    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(3, 250);

    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(0, 250);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(1, 250);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(2, 250);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(3, 250);

    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI0", "PSNOCPCIAXI0", 1);
    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI1", "PSNOCPCIAXI1", 1);
    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("NOCPSPCIAXI0", "PSCPMPCIEAXI", 1);

    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI0", "PSNOCPCIAXI0", 1);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI1", "PSNOCPCIAXI1", 1);

    $display("[%t] System Reset Asserted", $realtime);
    sys_rst_n = 1'b0;

    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b0;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b0;
    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'h0);
    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(0);

    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b0;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b0;
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'h0);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(0);

    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b0;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b0;

    repeat (500) @(posedge rp_sys_clk_p);
    $display("[%t] System Reset De-asserted", $realtime);
    sys_rst_n = 1'b1;

    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'hF);
    board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(1);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'hF);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(1);

    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b1;

    wait(board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    wait(board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    $display("[%t] CDO programming done on both EP and RP", $realtime);

    $display("[%t] Releasing PERST", $realtime);
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b1;
    force board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b1;
  end

  // ── Edge-triggered LTSSM monitor — captures exact state transitions ─
  reg [5:0] ltssm_prev;
  initial begin
    ltssm_prev = 6'h3F;
    wait(board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    forever begin
      @(board.RP.cfg_ltssm_state);
      if (board.RP.cfg_ltssm_state !== ltssm_prev) begin
        $display("[%t] LTSSM_EDGE: %h -> %h user_lnk_up=%b", $realtime,
          ltssm_prev, board.RP.cfg_ltssm_state, board.RP.user_lnk_up);
        $display("[%t]   RP: tx_ei=%b rx_ei=%b txdata=%h fifo_e=%b fifo_p=%b link_clk=%b phy_rdy=%b pipe_clk=%b",
          $realtime,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.iffcq00txelecidle,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.iffcq00rxelecidle,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.iffcq00txdata[31:0],
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_tx_cdcfifo_empty,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_tx_cdcfifo_primed,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.link_pipe_clk,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.phy_rdy,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_clk);
        $display("[%t]   EP: tx_ei=%b rx_ei=%b txdata=%h fifo_e=%b link_clk=%b phy_rdy=%b pipe_clk=%b",
          $realtime,
          board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.iffcq20txelecidle,
          board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.iffcq20rxelecidle,
          board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.iffcq20txdata[31:0],
          board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pipe1_tx_cdcfifo_empty,
          board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.link_pipe_clk1,
          board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.phy_rdy1,
          board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pipe_clk1);
        $display("[%t]   RP_RXFIFO: rx_fifo_e=%b rx_fifo_p=%b rx_wr=%b rx_rd=%b pcie0_pipe_rx0[34]=%b",
          $realtime,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_rx_cdcfifo_empty,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_rx_cdcfifo_primed,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_rx_cdcfifo_wren,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_rx_cdcfifo_rden,
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_0[34]);
        ltssm_prev = board.RP.cfg_ltssm_state;
      end
    end
  end

  // ── Periodic PIPE monitor — 500ns during first 200us, then 10us ─────
  initial begin
    wait(board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    $display("[%t] PIPE_MON: starting (CDO done)", $realtime);
    forever begin
      if ($realtime < 200_000_000)
        #497_000;
      else
        #9_997_000;
      $display("[%t] LINK: user_lnk_up=%b ltssm=%h pipe_cmd_ep=%h pipe_cmd_rp=%h",
        $realtime,
        board.RP.user_lnk_up,
        board.RP.cfg_ltssm_state,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_commands_out,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out);
      $display("[%t] DIAG_RP: perst0n=%b phy_rdy=%b txdetectrx=%b rxstatus=%b phystatus=%b",
        $realtime,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.perst0n,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.phy_rdy,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.iffcq00txdetectrxloopback,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.iffcq00rxstatus,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.iffcq00phystatus);
      $display("[%t] DIAG_EP: perst1n=%b phy_rdy1=%b txdetectrx=%b rxstatus=%b phystatus=%b",
        $realtime,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.perst1n,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.phy_rdy1,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.iffcq20txdetectrxloopback,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.iffcq20rxstatus,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.iffcq20phystatus);
      $display("[%t] PIPE_RP: tx0_ei=%b rx0_ei=%b tx0_data=%h tx_fifo_e=%b tx_fifo_p=%b link_clk=%b",
        $realtime,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.iffcq00txelecidle,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.iffcq00rxelecidle,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.iffcq00txdata[31:0],
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_tx_cdcfifo_empty,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_tx_cdcfifo_primed,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.link_pipe_clk);
      $display("[%t] RXFIFO_RP: rx_fifo_e=%b rx_fifo_p=%b rx_wr=%b rx_rd=%b rx_raw_ei=%b pcie0_pipe_rx0[34]=%b",
        $realtime,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_rx_cdcfifo_empty,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_rx_cdcfifo_primed,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_rx_cdcfifo_wren,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_rx_cdcfifo_rden,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_rx_0_cdcfifo[34],
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_0[34]);
      $display("[%t] PIPE_EP: tx0_ei=%b rx0_ei=%b tx0_data=%h tx_fifo_e=%b link_clk=%b",
        $realtime,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.iffcq20txelecidle,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.iffcq20rxelecidle,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.iffcq20txdata[31:0],
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pipe1_tx_cdcfifo_empty,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.link_pipe_clk1);
      $display("[%t] EP_TXOUT: pipe_tx0=%h rden=%b dout[664]=%b dout[671:630]=%h",
        $realtime,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie1_pipe_tx_0,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pipe1_tx_cdcfifo_rden,
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pipe1_tx_cdcfifo_dout[664],
        board.EP.design_1_wrapper_i.design_1_i.versal_cips_0.inst.cpm_0.inst.pipe1_tx_cdcfifo_dout[671:630]);
      $display("[%t] RP_RXBUS: pcie0_pipe_rx0=%h pipe_rx_cdcfifo_dout[671:630]=%h",
        $realtime,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_0,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pipe_rx_cdcfifo_dout[671:630]);
    end
  end

  // ── EP: CED design (design_1_wrapper wrapping BD + qdma_app) ─────
  design_1_wrapper_sim_wrapper EP (
    .gt_refclk1_0_clk_n (ep_sys_clk_n),
    .gt_refclk1_0_clk_p (ep_sys_clk_p),
    .sys_clk0_0_clk_n   (ep_sys_clk_n),
    .sys_clk0_0_clk_p   (ep_sys_clk_p),
    .PCIE1_GT_0_gtx_n   (ep_pci_exp_txn),
    .PCIE1_GT_0_gtx_p   (ep_pci_exp_txp),
    .PCIE1_GT_0_grx_n   (rp_pci_exp_txn),
    .PCIE1_GT_0_grx_p   (rp_pci_exp_txp)
  );

  // ── RP: Xilinx root port BFM ─────────────────────────────────────
  xilinx_pcie5_versal_rp #(
    .PF0_DEV_CAP_MAX_PAYLOAD_SIZE (PF0_DEV_CAP_MAX_PAYLOAD_SIZE)
  ) RP (
    .sys_clk_n   (rp_sys_clk_n),
    .sys_clk_p   (rp_sys_clk_p),
    .sys_rst_n   (sys_rst_n),
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
