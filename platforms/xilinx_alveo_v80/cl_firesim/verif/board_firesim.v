// board_firesim.v — Top-level XSim testbench for V80 FireSim design
//
// Adapted from Xilinx CPM5 QDMA CED board.v.
// EP = our FireSim design (overall_fpga_top wrapping design_1 + F1Shim)
// RP = Xilinx root port BFM (xilinx_pcie5_versal_rp from CED)
// Communication = PIPESIM (bypasses GT transceivers for fast simulation)

`timescale 1ps/1ps
`include "board_common.vh"
`define SIMULATION

module board;

  parameter          REF_CLK_FREQ       = 0;  // 0=100MHz, 1=125MHz, 2=250MHz
  localparam         REF_CLK_HALF_CYCLE = (REF_CLK_FREQ == 0) ? 5000 :
                                          (REF_CLK_FREQ == 1) ? 4000 :
                                          (REF_CLK_FREQ == 2) ? 2000 : 0;
  localparam [2:0]   PF0_DEV_CAP_MAX_PAYLOAD_SIZE = 3'b010;
  localparam [4:0]   LINK_WIDTH = 5'd8;
  localparam         EP_DATA_WIDTH = 512;

  // ── System reset ───────────────────────────────────────────────────
  reg sys_rst_n;

  // ── Reference clocks ───────────────────────────────────────────────
  wire ep_sys_clk_p, ep_sys_clk_n;
  wire rp_sys_clk_p, rp_sys_clk_n;

  // DDR4 reference clock (200 MHz = 2500 ps half-period)
  wire ddr4_sys_clk_p, ddr4_sys_clk_n;

  sys_clk_gen_ds #(.halfcycle(REF_CLK_HALF_CYCLE), .offset(0))
    CLK_GEN_RP (.sys_clk_p(rp_sys_clk_p), .sys_clk_n(rp_sys_clk_n));

  sys_clk_gen_ds #(.halfcycle(REF_CLK_HALF_CYCLE), .offset(0))
    CLK_GEN_EP (.sys_clk_p(ep_sys_clk_p), .sys_clk_n(ep_sys_clk_n));

  sys_clk_gen_ds #(.halfcycle(2500), .offset(0))
    CLK_GEN_DDR4 (.sys_clk_p(ddr4_sys_clk_p), .sys_clk_n(ddr4_sys_clk_n));

  // ── PCIe serial interconnect (active only in non-PIPESIM mode) ────
  wire [(LINK_WIDTH-1):0] ep_pci_exp_txn, ep_pci_exp_txp;
  wire [(LINK_WIDTH-1):0] rp_pci_exp_txn, rp_pci_exp_txp;

  // ── Enable PIPESIM on both EP and RP ──────────────────────────────
  parameter ON=3, OFF=4, UNIQUE=32, UNIQUE0=64, PRIORITY=128;

  defparam board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.C_CPM_PIPESIM = "TRUE";
  defparam board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.C_CPM_PIPESIM = "TRUE";

  // RP CPM5 link width override (x8→x16) applied directly in bd_e4ca_cpm_0_0.sv.
  // No defparam needed — the source file instantiation parameters are modified.

  // ── PIPESIM PIPE signal cross-connections ─────────────────────────
  // EP pcie0 <-> RP pcie0 (both sides use CPM_PCIE0)
  initial begin
    // Command channel
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_in =
          board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_in =
          board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out;

    // Per-lane RX/TX cross-connect (RP TX -> EP RX)
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_0  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_0;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_1  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_1;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_2  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_2;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_3  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_3;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_4  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_4;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_5  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_5;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_6  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_6;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_7  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_7;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_8  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_8;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_9  = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_9;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_10 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_10;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_11 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_11;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_12 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_12;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_13 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_13;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_14 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_14;
    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_15 = board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_15;

    // EP TX -> RP RX
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_0  = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_0;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_1  = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_2  = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_2;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_3  = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_3;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_4  = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_4;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_5  = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_5;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_6  = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_6;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_7  = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_7;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_8  = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_8;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_9  = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_9;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_10 = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_10;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_11 = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_11;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_12 = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_12;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_13 = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_13;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_14 = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_14;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_rx_15 = board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_tx_15;
  end

  // ── PS9 VIP configuration + Reset sequencing ──────────────────────
  initial begin
    // Enable multi-clock support
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.en_multi_clock_support();
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.en_multi_clock_support();

    // Set PL output clocks (EP pl0_ref_clk feeds our clock wizard)
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(0, 250);
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(1, 250);
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(2, 250);
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(3, 250);

    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(0, 250);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(1, 250);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(2, 250);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_clock(3, 250);

    // Enable CPM PS AXI routing
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI0", "PSNOCPCIAXI0", 1);
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI1", "PSNOCPCIAXI1", 1);
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("NOCPSPCIAXI0", "PSCPMPCIEAXI", 1);

    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI0", "PSNOCPCIAXI0", 1);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.set_routing_config("CPMPSAXI1", "PSNOCPCIAXI1", 1);

    // ── Assert all resets ────────────────────────────────────────────
    $display("[%t] System Reset Asserted", $realtime);
    sys_rst_n = 1'b0;

    force board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b0;
    force board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b0;
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'h0);
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(0);

    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b0;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b0;
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'h0);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(0);

    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b0;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b0;

    // ── Release resets after CPM stabilises ──────────────────────────
    repeat (500) @(posedge rp_sys_clk_p);
    $display("[%t] System Reset De-asserted", $realtime);
    sys_rst_n = 1'b1;

    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'hF);
    board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(1);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.pl_gen_reset(4'hF);
    board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.por_reset(1);

    force board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.lpd_cpm5_por_n = 1'b1;

    // Wait for CDO programming to complete on both sides
    wait(board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    wait(board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    $display("[%t] CDO programming done on both EP and RP", $realtime);

    // Release PCIe resets
    $display("[%t] Releasing PERST on EP and RP", $realtime);
    force board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b1;
    force board.EP.design_1_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST0N = 1'b1;
    force board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.pspmc_0.inst.PS9_VIP_inst.inst.PERST1N = 1'b1;
  end

  // Periodic link training monitor — waits for CDO then runs forever at 10us intervals
  initial begin
    wait(board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    wait(board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
    $display("[%t] LINK_MON: starting (CDO done, monitoring every 10us)", $realtime);
    forever begin
      #10_000_000;
      $display("[%t] LINK: user_lnk_up=%b ltssm=%h pipe_cmd_ep=%h pipe_cmd_rp=%h",
        $realtime,
        board.RP.user_lnk_up,
        board.RP.cfg_ltssm_state,
        board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out,
        board.RP.design_rp_wrapper_i.design_rp_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out);
    end
  end

  // ── Endpoint: our FireSim design ──────────────────────────────────
  //
  // overall_fpga_top instantiates design_1 (block design) + F1Shim.
  // DDR4 pins are directly on overall_fpga_top; in behavioral sim
  // the NoC DDR4 MC model handles memory internally, so we can leave
  // the physical DDR4 pins undriven (they float harmlessly in sim).
  //
  overall_fpga_top EP (
    // DDR4 — left unconnected; NoC DDRMC behavioural model is self-contained
    // (Vivado sim_netlist includes internal memory model for the DDRMC)

    // DDR4 reference clock
    .sys_clk0_1_clk_p (ddr4_sys_clk_p),
    .sys_clk0_1_clk_n (ddr4_sys_clk_n),

    // PCIe x16 serial (active only without PIPESIM; unused with PIPESIM)
    .pci_express_x16_gtx_n (ep_pci_exp_txn),
    .pci_express_x16_gtx_p (ep_pci_exp_txp),
    .pci_express_x16_grx_n (rp_pci_exp_txn),
    .pci_express_x16_grx_p (rp_pci_exp_txp),

    // PCIe reference clock
    .pcie_refclk_clk_p (ep_sys_clk_p),
    .pcie_refclk_clk_n (ep_sys_clk_n)
  );

  // ── Root Port: Xilinx BFM with QDMA test infrastructure ──────────
  xilinx_pcie5_versal_rp #(
    .PF0_DEV_CAP_MAX_PAYLOAD_SIZE (PF0_DEV_CAP_MAX_PAYLOAD_SIZE)
  ) RP (
    .sys_clk_n  (rp_sys_clk_n),
    .sys_clk_p  (rp_sys_clk_p),
    .sys_rst_n  (sys_rst_n),
    .pci_exp_txn (rp_pci_exp_txn),
    .pci_exp_txp (rp_pci_exp_txp),
    .pci_exp_rxn (ep_pci_exp_txn),
    .pci_exp_rxp (ep_pci_exp_txp)
  );

  // ── Waveform dump ─────────────────────────────────────────────────
  initial begin
    if ($test$plusargs("dump_all")) begin
      $dumpfile("board.vcd");
      $dumpvars(0, board);
    end
  end


  // ── xlnoc NoC fabric BFM ─────────────────────────────────────────
  //
  // The Versal NoC requires an external xlnoc fabric BFM to route
  // transactions between NMU (master) and NSU (slave) endpoints through
  // NPS (NoC Protocol Switch) instances. Without this, the NPP interface
  // wires inside the EP's axi_noc blocks float at X/Z and trigger $fatal
  // in the encrypted NMU/NSU simulation models.
  //
  // Connections derived from overall_fpga_top_sim_wrapper.v.

  // ── NPP interconnect wires ────────────────────────────────────────
  // nps_0: connects to axi_noc_1 S00_AXI NMU
  wire [0:0]   nps_0_mnpp_s_credit_rdy;
  wire [7:0]   nps_0_mnpp_s_credit_return;
  wire [181:0] nps_0_mnpp_s_flit;
  wire [7:0]   nps_0_mnpp_s_valid;
  wire [0:0]   nps_0_snpp_s_credit_rdy;
  wire [7:0]   nps_0_snpp_s_credit_return;
  wire [181:0] nps_0_snpp_s_flit;
  wire [7:0]   nps_0_snpp_s_valid;

  // nps_1: connects to axi_noc_0 M00_AXI NSU
  wire [0:0]   nps_1_mnpp_s_credit_rdy;
  wire [7:0]   nps_1_mnpp_s_credit_return;
  wire [181:0] nps_1_mnpp_s_flit;
  wire [7:0]   nps_1_mnpp_s_valid;
  wire [0:0]   nps_1_snpp_s_credit_rdy;
  wire [7:0]   nps_1_snpp_s_credit_return;
  wire [181:0] nps_1_snpp_s_flit;
  wire [7:0]   nps_1_snpp_s_valid;

  // nps_6: connects to axi_noc_1 MC0 DDRC
  wire [0:0]   nps_6_mnpp_n_credit_rdy;
  wire [7:0]   nps_6_mnpp_n_credit_return;
  wire [181:0] nps_6_mnpp_n_flit;
  wire [7:0]   nps_6_mnpp_n_valid;
  wire [0:0]   nps_6_snpp_n_credit_rdy;
  wire [7:0]   nps_6_snpp_n_credit_return;
  wire [181:0] nps_6_snpp_n_flit;
  wire [7:0]   nps_6_snpp_n_valid;

  // nps_8: connects to axi_noc_0 M01_AXI NSU
  wire [0:0]   nps_8_mnpp_s_credit_rdy;
  wire [7:0]   nps_8_mnpp_s_credit_return;
  wire [181:0] nps_8_mnpp_s_flit;
  wire [7:0]   nps_8_mnpp_s_valid;
  wire [0:0]   nps_8_snpp_s_credit_rdy;
  wire [7:0]   nps_8_snpp_s_credit_return;
  wire [181:0] nps_8_snpp_s_flit;
  wire [7:0]   nps_8_snpp_s_valid;

  // nps_9: connects to axi_noc_0 S00_AXI NMU (CPM QDMA NMU — the fatal trigger)
  wire [0:0]   nps_9_mnpp_s_credit_rdy;
  wire [7:0]   nps_9_mnpp_s_credit_return;
  wire [181:0] nps_9_mnpp_s_flit;
  wire [7:0]   nps_9_mnpp_s_valid;
  wire [0:0]   nps_9_snpp_s_credit_rdy;
  wire [7:0]   nps_9_snpp_s_credit_return;
  wire [181:0] nps_9_snpp_s_flit;
  wire [7:0]   nps_9_snpp_s_valid;

  // ── xlnoc instantiation ──────────────────────────────────────────
  xlnoc xlnoc_i (
    .nps_0_MNPP_S_credit_rdy    (nps_0_mnpp_s_credit_rdy),
    .nps_0_MNPP_S_credit_return (nps_0_mnpp_s_credit_return),
    .nps_0_MNPP_S_flit          (nps_0_mnpp_s_flit),
    .nps_0_MNPP_S_valid         (nps_0_mnpp_s_valid),
    .nps_0_SNPP_S_credit_rdy    (nps_0_snpp_s_credit_rdy),
    .nps_0_SNPP_S_credit_return (nps_0_snpp_s_credit_return),
    .nps_0_SNPP_S_flit          (nps_0_snpp_s_flit),
    .nps_0_SNPP_S_valid         (nps_0_snpp_s_valid),

    .nps_1_MNPP_S_credit_rdy    (nps_1_mnpp_s_credit_rdy),
    .nps_1_MNPP_S_credit_return (nps_1_mnpp_s_credit_return),
    .nps_1_MNPP_S_flit          (nps_1_mnpp_s_flit),
    .nps_1_MNPP_S_valid         (nps_1_mnpp_s_valid),
    .nps_1_SNPP_S_credit_rdy    (nps_1_snpp_s_credit_rdy),
    .nps_1_SNPP_S_credit_return (nps_1_snpp_s_credit_return),
    .nps_1_SNPP_S_flit          (nps_1_snpp_s_flit),
    .nps_1_SNPP_S_valid         (nps_1_snpp_s_valid),

    .nps_6_MNPP_N_credit_rdy    (nps_6_mnpp_n_credit_rdy),
    .nps_6_MNPP_N_credit_return (nps_6_mnpp_n_credit_return),
    .nps_6_MNPP_N_flit          (nps_6_mnpp_n_flit),
    .nps_6_MNPP_N_valid         (nps_6_mnpp_n_valid),
    .nps_6_SNPP_N_credit_rdy    (nps_6_snpp_n_credit_rdy),
    .nps_6_SNPP_N_credit_return (nps_6_snpp_n_credit_return),
    .nps_6_SNPP_N_flit          (nps_6_snpp_n_flit),
    .nps_6_SNPP_N_valid         (nps_6_snpp_n_valid),

    .nps_8_MNPP_S_credit_rdy    (nps_8_mnpp_s_credit_rdy),
    .nps_8_MNPP_S_credit_return (nps_8_mnpp_s_credit_return),
    .nps_8_MNPP_S_flit          (nps_8_mnpp_s_flit),
    .nps_8_MNPP_S_valid         (nps_8_mnpp_s_valid),
    .nps_8_SNPP_S_credit_rdy    (nps_8_snpp_s_credit_rdy),
    .nps_8_SNPP_S_credit_return (nps_8_snpp_s_credit_return),
    .nps_8_SNPP_S_flit          (nps_8_snpp_s_flit),
    .nps_8_SNPP_S_valid         (nps_8_snpp_s_valid),

    .nps_9_MNPP_S_credit_rdy    (nps_9_mnpp_s_credit_rdy),
    .nps_9_MNPP_S_credit_return (nps_9_mnpp_s_credit_return),
    .nps_9_MNPP_S_flit          (nps_9_mnpp_s_flit),
    .nps_9_MNPP_S_valid         (nps_9_mnpp_s_valid),
    .nps_9_SNPP_S_credit_rdy    (nps_9_snpp_s_credit_rdy),
    .nps_9_SNPP_S_credit_return (nps_9_snpp_s_credit_return),
    .nps_9_SNPP_S_flit          (nps_9_snpp_s_flit),
    .nps_9_SNPP_S_valid         (nps_9_snpp_s_valid)
  );

  // ── Cross-hierarchy NPP connections ──────────────────────────────
  // These connect the xlnoc NPS ports to the EP's internal axi_noc
  // NMU/NSU NPP interfaces via hierarchical references.
  // (From overall_fpga_top_sim_wrapper.v, with EP replacing overall_fpga_top_i)

  // nps_0 <-> axi_noc_1 S00_AXI NMU (npp_in = from fabric to NMU, npp_out = from NMU to fabric)
  assign EP.design_1_i.axi_noc_1.inst.s00_axi_nmu_if_noc_npp_in_noc_credit_rdy    = nps_0_mnpp_s_credit_rdy;
  assign nps_0_mnpp_s_credit_return = EP.design_1_i.axi_noc_1.inst.s00_axi_nmu_if_noc_npp_in_noc_credit_return;
  assign EP.design_1_i.axi_noc_1.inst.s00_axi_nmu_if_noc_npp_in_noc_flit          = nps_0_mnpp_s_flit;
  assign EP.design_1_i.axi_noc_1.inst.s00_axi_nmu_if_noc_npp_in_noc_valid         = nps_0_mnpp_s_valid;
  assign nps_0_snpp_s_credit_rdy    = EP.design_1_i.axi_noc_1.inst.s00_axi_nmu_if_noc_npp_out_noc_credit_rdy;
  assign EP.design_1_i.axi_noc_1.inst.s00_axi_nmu_if_noc_npp_out_noc_credit_return = nps_0_snpp_s_credit_return;
  assign nps_0_snpp_s_flit          = EP.design_1_i.axi_noc_1.inst.s00_axi_nmu_if_noc_npp_out_noc_flit;
  assign nps_0_snpp_s_valid         = EP.design_1_i.axi_noc_1.inst.s00_axi_nmu_if_noc_npp_out_noc_valid;

  // nps_1 <-> axi_noc_0 M00_AXI NSU
  assign EP.design_1_i.axi_noc_0.inst.m00_axi_nsu_if_noc_npp_in_noc_credit_rdy    = nps_1_mnpp_s_credit_rdy;
  assign nps_1_mnpp_s_credit_return = EP.design_1_i.axi_noc_0.inst.m00_axi_nsu_if_noc_npp_in_noc_credit_return;
  assign EP.design_1_i.axi_noc_0.inst.m00_axi_nsu_if_noc_npp_in_noc_flit          = nps_1_mnpp_s_flit;
  assign EP.design_1_i.axi_noc_0.inst.m00_axi_nsu_if_noc_npp_in_noc_valid         = nps_1_mnpp_s_valid;
  assign nps_1_snpp_s_credit_rdy    = EP.design_1_i.axi_noc_0.inst.m00_axi_nsu_if_noc_npp_out_noc_credit_rdy;
  assign EP.design_1_i.axi_noc_0.inst.m00_axi_nsu_if_noc_npp_out_noc_credit_return = nps_1_snpp_s_credit_return;
  assign nps_1_snpp_s_flit          = EP.design_1_i.axi_noc_0.inst.m00_axi_nsu_if_noc_npp_out_noc_flit;
  assign nps_1_snpp_s_valid         = EP.design_1_i.axi_noc_0.inst.m00_axi_nsu_if_noc_npp_out_noc_valid;

  // nps_6 <-> axi_noc_1 MC0 DDRC (memory controller, uses different signal names)
  assign EP.design_1_i.axi_noc_1.inst.mc0_ddrc_noc2dmc_credit_rdy_0  = nps_6_mnpp_n_credit_rdy;
  assign nps_6_mnpp_n_credit_return = EP.design_1_i.axi_noc_1.inst.mc0_ddrc_dmc2noc_credit_rtn_0;
  assign EP.design_1_i.axi_noc_1.inst.mc0_ddrc_noc2dmc_data_in_0     = nps_6_mnpp_n_flit;
  assign EP.design_1_i.axi_noc_1.inst.mc0_ddrc_noc2dmc_valid_in_0    = nps_6_mnpp_n_valid;
  assign nps_6_snpp_n_credit_rdy    = EP.design_1_i.axi_noc_1.inst.mc0_ddrc_dmc2noc_credit_rdy_0;
  assign EP.design_1_i.axi_noc_1.inst.mc0_ddrc_noc2dmc_credit_rtn_0  = nps_6_snpp_n_credit_return;
  assign nps_6_snpp_n_flit          = EP.design_1_i.axi_noc_1.inst.mc0_ddrc_dmc2noc_data_out_0;
  assign nps_6_snpp_n_valid         = EP.design_1_i.axi_noc_1.inst.mc0_ddrc_dmc2noc_valid_out_0;

  // nps_8 <-> axi_noc_0 M01_AXI NSU
  assign EP.design_1_i.axi_noc_0.inst.m01_axi_nsu_if_noc_npp_in_noc_credit_rdy    = nps_8_mnpp_s_credit_rdy;
  assign nps_8_mnpp_s_credit_return = EP.design_1_i.axi_noc_0.inst.m01_axi_nsu_if_noc_npp_in_noc_credit_return;
  assign EP.design_1_i.axi_noc_0.inst.m01_axi_nsu_if_noc_npp_in_noc_flit          = nps_8_mnpp_s_flit;
  assign EP.design_1_i.axi_noc_0.inst.m01_axi_nsu_if_noc_npp_in_noc_valid         = nps_8_mnpp_s_valid;
  assign nps_8_snpp_s_credit_rdy    = EP.design_1_i.axi_noc_0.inst.m01_axi_nsu_if_noc_npp_out_noc_credit_rdy;
  assign EP.design_1_i.axi_noc_0.inst.m01_axi_nsu_if_noc_npp_out_noc_credit_return = nps_8_snpp_s_credit_return;
  assign nps_8_snpp_s_flit          = EP.design_1_i.axi_noc_0.inst.m01_axi_nsu_if_noc_npp_out_noc_flit;
  assign nps_8_snpp_s_valid         = EP.design_1_i.axi_noc_0.inst.m01_axi_nsu_if_noc_npp_out_noc_valid;

  // nps_9 <-> axi_noc_0 S00_AXI NMU (CPM5 QDMA — this was the $fatal trigger)
  assign EP.design_1_i.axi_noc_0.inst.s00_axi_nmu_if_noc_npp_in_noc_credit_rdy    = nps_9_mnpp_s_credit_rdy;
  assign nps_9_mnpp_s_credit_return = EP.design_1_i.axi_noc_0.inst.s00_axi_nmu_if_noc_npp_in_noc_credit_return;
  assign EP.design_1_i.axi_noc_0.inst.s00_axi_nmu_if_noc_npp_in_noc_flit          = nps_9_mnpp_s_flit;
  assign EP.design_1_i.axi_noc_0.inst.s00_axi_nmu_if_noc_npp_in_noc_valid         = nps_9_mnpp_s_valid;
  assign nps_9_snpp_s_credit_rdy    = EP.design_1_i.axi_noc_0.inst.s00_axi_nmu_if_noc_npp_out_noc_credit_rdy;
  assign EP.design_1_i.axi_noc_0.inst.s00_axi_nmu_if_noc_npp_out_noc_credit_return = nps_9_snpp_s_credit_return;
  assign nps_9_snpp_s_flit          = EP.design_1_i.axi_noc_0.inst.s00_axi_nmu_if_noc_npp_out_noc_flit;
  assign nps_9_snpp_s_valid         = EP.design_1_i.axi_noc_0.inst.s00_axi_nmu_if_noc_npp_out_noc_valid;

  // Include DMA AXI bus monitors for debug
  `include "board_firesim_dma_mon.vh"
endmodule
