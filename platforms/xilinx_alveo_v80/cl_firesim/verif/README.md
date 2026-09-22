# V80 XSim Simulation

Full block-design-level simulation of the V80 FireSim design in XSim. Simulates the CIPS CPM QDMA engine, NoC routing, DDR4 controller, and F1Shim — everything except the physical GT transceivers and DDR4 SDRAM chips.

Uses the Xilinx CPM5 QDMA CED (Configurable Example Design) simulation framework. A Root Port BFM generates PCIe TLPs that exercise the QDMA engine inside the CIPS CPM. Communication between EP and RP uses PIPESIM (pipe-level interface inside the CPM hard macro), which is orders of magnitude faster than GT-level simulation.

```
  Root Port BFM (RP)                 FireSim Endpoint (EP)
  ┌────────────────────────┐         ┌─────────────────────────────────┐
  │ xilinx_pcie5_versal_rp │         │ overall_fpga_top                │
  │                        │ PIPESIM │   design_1 (block design)       │
  │  CIPS CPM  ◄───────────┼─────────┼─► CIPS CPM (QDMA, pcie0)       │
  │  (root port mode)      │  pcie0  │      │                          │
  │                        │  pipe   │   axi_noc_0 ──► PCIE_M_AXI     │
  │  tx_usrapp (test tasks)│  sigs   │              └─► PCIE_M_AXI_LITE│
  │  rx_usrapp (checker)   │         │   axi_noc_1 ──► DDR4 MC        │
  └────────────────────────┘         │   F1Shim (FireSim logic)        │
                                     └─────────────────────────────────┘
```

## Prerequisites

- Vivado 2025.1 with XSim (already at `/ecad/tools/xilinx/2025.1/`)
- A completed V80 build with generated RTL (under `FIRESIM_BUILDS_DIR`)
- The Xilinx CPM5 QDMA CED installed (ships with Vivado at the path referenced by `setup_xsim.tcl`)

## Quick start

### 1. Create the simulation project

```bash
cd /scratch/raghavgupta/v80-chipyard/sims/firesim

vivado -mode batch -source \
  platforms/xilinx_alveo_v80/cl_firesim/verif/setup_xsim.tcl \
  -tclargs /scratch/raghavgupta/FIRESIM_BUILDS_DIR/platforms/xilinx_alveo_v80/cl_xilinx_alveo_v80-firesim-FireSim-FireSimRocket8GiBDRAMConfig-BaseXilinxAlveoV80Config
```

This takes 10–30 minutes (IP output product generation). Creates `<BUILD_DIR>/xsim_proj/`.

### 2. Run simulation (batch)

```bash
vivado -mode batch -source \
  /scratch/raghavgupta/FIRESIM_BUILDS_DIR/platforms/xilinx_alveo_v80/cl_xilinx_alveo_v80-firesim-FireSim-FireSimRocket8GiBDRAMConfig-BaseXilinxAlveoV80Config/xsim_proj/run_sim.tcl
```

### 3. Run simulation (GUI — recommended for debugging)

```bash
vivado /scratch/raghavgupta/FIRESIM_BUILDS_DIR/platforms/xilinx_alveo_v80/cl_xilinx_alveo_v80-firesim-FireSim-FireSimRocket8GiBDRAMConfig-BaseXilinxAlveoV80Config/xsim_proj/firesim_sim.xpr
```

Then in the Vivado Tcl console:

```tcl
launch_simulation
run 500us
```

## Selecting a test

The default test is `qdma_mm_test0`. Change it in the Tcl console before launching:

```tcl
set_property -name {xsim.simulate.xsim.more_options} \
  -value {-testplusarg testname=bar_test0} \
  -objects [get_filesets sim_1]
launch_simulation
```

Or pass it on the batch command line by editing `run_sim.tcl`.

### Available tests

| Test name | What it exercises |
|-----------|-------------------|
| `qdma_mm_test0` | Standard Xilinx QDMA MM H2C + C2H DMA (CED built-in) |
| `qdma_st_test0` | QDMA streaming H2C + C2H (CED built-in) |
| `qdma_mm_st_test0` | Combined MM + streaming (CED built-in) |
| `irq_test0` | QDMA interrupt test (CED built-in) |
| `bar_test0` | BAR1 MMIO read/write to F1Shim io_master (custom) |
| `qdma_mm_firesim_test0` | QDMA MM DMA through NoC to F1Shim io_pcis (custom) |

The `qdma_mm_test0` test is the most important for validating that the QDMA engine can move data through the NoC. If that passes, the PCIe/QDMA plumbing is correct and hardware issues are likely driver or address-map related.

## What gets simulated

- **CIPS CPM** — Full behavioral model of the CPM5 PCIe controller with QDMA engine. CDO programming, link training (at PIPE level), BAR configuration, descriptor processing — all happen in simulation.
- **NoC (axi_noc_0, axi_noc_1)** — Behavioral NoC model. Validates address aperture routing: does a TLP targeting `0x203_0000_0000` actually arrive at `PCIE_M_AXI`? Does `0x201_0000_0000` arrive at `PCIE_M_AXI_LITE`?
- **DDR4 MC** — The NoC DDR4 memory controller behavioral model. DDR4 physical pins are left floating in the testbench; the DDRMC sim model handles memory internally.
- **SmartConnect, clk_wizard, proc_sys_reset** — All block design IPs run their behavioral models.
- **F1Shim + FPGATop** — The full FireSim generated RTL.

## What does NOT get simulated

- GT transceivers (bypassed by PIPESIM)
- Physical DDR4 SDRAM timing (DDRMC behavioral model is cycle-approximate, not timing-accurate)
- PCIe electrical signaling

## File inventory

| File | Description |
|------|-------------|
| `setup_xsim.tcl` | Vivado project creation script. Sources our EP block design + CED RP block design, adds all sim/RTL files, configures XSim. |
| `board_firesim.v` | Top-level testbench. Instantiates `overall_fpga_top` (EP) and `xilinx_pcie5_versal_rp` (RP). Sets up PIPESIM cross-connections on `pcie0_pipe_*` signals. Configures PS9 VIP clocks, resets, and routing. |
| `tests.vh` | Test dispatcher include — chains CED `sample_tests.vh` + `tests_firesim.vh`. |
| `tests_firesim.vh` | Custom FireSim tests (`bar_test0`, `qdma_mm_firesim_test0`). |

CED simulation files referenced from the Vivado installation (not copied):

| CED file | Role |
|----------|------|
| `xilinx_pcie5_versal_rp.sv` | Root Port model (wraps a second CIPS in RP mode) |
| `usp_pci_exp_usrapp_tx.v` | TX user app — generates PCIe TLPs, contains QDMA test tasks |
| `usp_pci_exp_usrapp_rx.v` | RX user app — receives and checks completions |
| `usp_pci_exp_usrapp_cfg.v` | Configuration space handler |
| `usp_pci_exp_usrapp_com.v` | Common utilities |
| `pcie_4_0_rp.v` | PCIe 4.0 root port controller model |
| `xp4_usp_smsw_model_core_top.v` | Full PCIe switch/controller model core |
| `sys_clk_gen.v`, `sys_clk_gen_ds.v` | Differential clock generators |
| `board_common.vh` | Shared constants (TLP types, timeouts) |
| `sample_tests.vh` | Standard Xilinx QDMA test scenarios |

## Simulation timeline

Expect approximately:

| Phase | Sim time | What happens |
|-------|----------|--------------|
| Reset + POR | 0 – 5 us | PS9 VIP powers up, PL clocks/resets released |
| CDO programming | 5 – 30 us | CPM loads configuration (QDMA mode, BAR sizes, apertures) |
| PCIe link training | 30 – 60 us | PIPESIM link comes up (much faster than GT sim) |
| Enumeration | 60 – 80 us | RP BFM reads config space, assigns BARs |
| Test execution | 80+ us | TLPs flow, QDMA descriptors processed, data moves |

Total: ~100–300 us for a basic QDMA MM test. Wall clock depends on design complexity; expect 30–120 minutes for the full FireSim RTL.

## Troubleshooting

### PIPESIM pipe signal names

`board_firesim.v` uses `pcie0_pipe_*` for both EP and RP cross-connections. This matches `CPM_PCIE0_MODES {DMA}` in the block design. If you see link training failures, check:

```tcl
# In XSim Tcl console after launch_simulation:
get_value board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.pcie0_pipe_commands_out
```

If the signal doesn't exist, the CPM may expose its PIPE on a different port name. Check available signals:

```tcl
get_objects -r board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.*pipe*
```

### DDR4 returns X

The DDR4 physical pins are floating. If F1Shim reads from DDR4 and gets X, add the Xilinx Micron DDR4 RDIMM model:

```
/ecad/tools/xilinx/2025.1/Vivado/data/ip/xilinx/ddr_responder_v1_0/hdl/micron_model_rdimm/
```

Connect it to the `ddr4_sdram_c0_*` ports of `overall_fpga_top` in `board_firesim.v`.

### RP block design fails to create

The CED `design_rp_bd.tcl` is authored for a generic Versal part. If it fails on xcv80 (missing IP versions, board-part mismatch), try creating the RP block design manually in the Vivado GUI: add a CIPS configured as a PCIe Root Port on pcie0.

### Simulation hangs at CDO programming

Add to `board_firesim.v`:

```verilog
initial begin
  #200000000;  // 200 us timeout
  $display("[%t] TIMEOUT waiting for CDO programming", $realtime);
  $finish;
end
```

### Writing custom tests

Add new `else if` blocks to `tests_firesim.vh`. The RP BFM provides these tasks via `board.RP.tx_usrapp`:

```verilog
// 32-bit memory write TLP to an address
board.RP.tx_usrapp.TSK_MEM_WRITE_32(addr, data, byte_enables);

// 32-bit memory read TLP (completion arrives at rx_usrapp)
board.RP.tx_usrapp.TSK_MEM_READ_32(addr);

// QDMA MM host-to-card DMA
board.RP.tx_usrapp.TSK_QDMA_MM_H2C_TEST(qid, port, ring);

// QDMA MM card-to-host DMA
board.RP.tx_usrapp.TSK_QDMA_MM_C2H_TEST(qid, port, ring);

// Program QDMA host profile (call before any QDMA test)
board.RP.tx_usrapp.TSK_PROG_HOST_PROFILE;
```

BAR addresses are auto-discovered during enumeration and stored in `board.RP.tx_usrapp.BAR_INIT_P_BAR[n]`.
