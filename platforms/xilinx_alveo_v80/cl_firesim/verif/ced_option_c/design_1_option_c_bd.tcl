# design_1_option_c_bd.tcl — Production CIPS config + AXI BRAM slaves (no FireSim RTL)
# Based on cl_firesim/scripts/bd_lib/ with AXI BRAM replacing external ports

proc create_root_design { parentCell } {
  if { $parentCell eq "" } { set parentCell [get_bd_cells /] }
  set parentObj [get_bd_cells $parentCell]
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } { return }
  current_bd_instance $parentObj

  ##################################################################
  # Create interface ports (only PCIe GT + reference clock)
  ##################################################################
  set PCIE0_GT_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 PCIE0_GT_0 ]
  set gt_refclk0_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_refclk0_0 ]
  set_property -dict [ list CONFIG.FREQ_HZ {100000000} ] $gt_refclk0_0

  ##################################################################
  # Create CIPS — PRODUCTION CONFIG (CPM_PCIE0 DMA)
  ##################################################################
  set versal_cips_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips:3.4 versal_cips_0 ]
  set_property -dict [list \
    CONFIG.BOOT_MODE {Custom} \
    CONFIG.CLOCK_MODE {Custom} \
    CONFIG.CPM_CONFIG { \
      CPM_PCIE0_MODES {DMA} \
      CPM_PCIE0_PF0_BAR0_QDMA_64BIT {0} \
      CPM_PCIE0_PF0_BAR0_QDMA_TYPE {DMA} \
      CPM_PCIE0_PF0_BAR1_QDMA_ENABLED {1} \
      CPM_PCIE0_PF0_BAR1_QDMA_SCALE {Megabytes} \
      CPM_PCIE0_PF0_BAR1_QDMA_SIZE {32} \
      CPM_PCIE0_PF0_BAR2_QDMA_ENABLED {0} \
      CPM_PCIE0_PF0_CFG_DEV_ID {903F} \
      CPM_PCIE0_PF0_PCIEBAR2AXIBAR_QDMA_0 {0x0_202_0000_0000} \
      CPM_PCIE0_PF0_PCIEBAR2AXIBAR_QDMA_1 {0x0_201_0000_0000} \
      CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH {X8} \
    } \
    CONFIG.PS_PMC_CONFIG { \
      BOOT_MODE {Custom} \
      CLOCK_MODE {Custom} \
      DESIGN_MODE {1} \
      PCIE_APERTURES_DUAL_ENABLE {0} \
      PCIE_APERTURES_SINGLE_ENABLE {1} \
      PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
      PMC_MIO_EN_FOR_PL_PCIE {0} \
      PMC_OSPI_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 11}} {MODE Single}} \
      PMC_QSPI_FBCLK {{ENABLE 1} {IO {PMC_MIO 6}}} \
      PMC_QSPI_PERIPHERAL_ENABLE {0} \
      PMC_SD0 {{CD_ENABLE 0} {CD_IO {PMC_MIO 24}} {POW_ENABLE 0} {POW_IO {PMC_MIO 17}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 17}} {WP_ENABLE 0} {WP_IO {PMC_MIO 25}}} \
      PMC_SD0_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x00} {CLK_200_SDR_OTAP_DLY 0x00} {CLK_50_DDR_ITAP_DLY 0x00} {CLK_50_DDR_OTAP_DLY 0x00} {CLK_50_SDR_ITAP_DLY 0x00} {CLK_50_SDR_OTAP_DLY 0x00} {ENABLE 0} {IO {PMC_MIO 13 .. 25}}} \
      PMC_SD0_SLOT_TYPE {SD 2.0} \
      PMC_SMAP_PERIPHERAL {{ENABLE 0} {IO {32 Bit}}} \
      PS_BOARD_INTERFACE {Custom} \
      PS_NUM_FABRIC_RESETS {1} \
      PS_PCIE1_PERIPHERAL_ENABLE {1} \
      PS_PCIE2_PERIPHERAL_ENABLE {0} \
      PS_PCIE_EP_RESET1_IO {PMC_MIO 24} \
      PS_PCIE_EP_RESET2_IO {None} \
      PS_PCIE_RESET {ENABLE 1} \
      PS_USE_PMCPL_CLK0 {1} \
      SMON_ALARMS {Set_Alarms_On} \
      SMON_ENABLE_TEMP_AVERAGING {0} \
      SMON_TEMP_AVERAGING_SAMPLES {0} \
    } \
  ] $versal_cips_0

  ##################################################################
  # Create AXI NoC (PCIe → PL slaves, same as production)
  ##################################################################
  set axi_noc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_0 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {2} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {1} \
    CONFIG.SI_SIDEBAND_PINS {} \
    CONFIG.NUM_MC {0} \
    CONFIG.NUM_MCP {0} \
  ] $axi_noc_0

  set_property -dict [ list \
    CONFIG.APERTURES {{0x203_0000_0000 4G}} \
    CONFIG.CATEGORY {pl} \
  ] [get_bd_intf_pins /axi_noc_0/M00_AXI]

  set_property -dict [ list \
    CONFIG.APERTURES {{0x201_0000_0000 1G}} \
    CONFIG.CATEGORY {pl} \
  ] [get_bd_intf_pins /axi_noc_0/M01_AXI]

  set_property -dict [ list \
    CONFIG.CONNECTIONS {M01_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}} M00_AXI {read_bw {1720} write_bw {1720} read_avg_burst {4} write_avg_burst {4}}} \
    CONFIG.DEST_IDS {M01_AXI:0x40:M00_AXI:0xc0} \
    CONFIG.NOC_PARAMS {} \
    CONFIG.CATEGORY {ps_pcie} \
  ] [get_bd_intf_pins /axi_noc_0/S00_AXI]

  set_property -dict [ list CONFIG.ASSOCIATED_BUSIF {S00_AXI} ] [get_bd_pins /axi_noc_0/aclk0]
  set_property -dict [ list CONFIG.ASSOCIATED_BUSIF {M00_AXI:M01_AXI} ] [get_bd_pins /axi_noc_0/aclk1]

  ##################################################################
  # Create SmartConnect (downsize for AXI-Lite path)
  ##################################################################
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
  set_property -dict [list CONFIG.NUM_CLKS {1} CONFIG.NUM_SI {1} ] $smartconnect_0

  ##################################################################
  # AXI BRAM Controller 0 — replaces FireSim AXI slave (BAR0 DMA path)
  ##################################################################
  set axi_bram_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0 ]
  set_property -dict [list \
    CONFIG.DATA_WIDTH {512} \
    CONFIG.SINGLE_PORT_BRAM {1} \
  ] $axi_bram_ctrl_0

  set axi_bram_ctrl_0_bram [ create_bd_cell -type ip -vlnv xilinx.com:ip:emb_mem_gen:1.0 axi_bram_ctrl_0_bram ]
  set_property -dict [list CONFIG.MEMORY_TYPE {True_Dual_Port_RAM} ] $axi_bram_ctrl_0_bram

  ##################################################################
  # AXI BRAM Controller 1 — replaces FireSim AXI-Lite slave (BAR1 control path)
  ##################################################################
  set axi_bram_ctrl_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_1 ]
  set_property -dict [list \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.SINGLE_PORT_BRAM {1} \
    CONFIG.PROTOCOL {AXI4LITE} \
  ] $axi_bram_ctrl_1

  set axi_bram_ctrl_1_bram [ create_bd_cell -type ip -vlnv xilinx.com:ip:emb_mem_gen:1.0 axi_bram_ctrl_1_bram ]
  set_property -dict [list CONFIG.MEMORY_TYPE {True_Dual_Port_RAM} ] $axi_bram_ctrl_1_bram

  ##################################################################
  # Clock and reset
  ##################################################################
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  set clk_wizard_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard:1.0 clk_wizard_0 ]
  set_property -dict [list \
    CONFIG.CLKOUT_DRIVES {BUFG,BUFG,BUFG,BUFG,BUFG,BUFG,BUFG} \
    CONFIG.CLKOUT_DYN_PS {None,None,None,None,None,None,None} \
    CONFIG.CLKOUT_GROUPING {Auto,Auto,Auto,Auto,Auto,Auto,Auto} \
    CONFIG.CLKOUT_MATCHED_ROUTING {false,false,false,false,false,false,false} \
    CONFIG.CLKOUT_PORT {clk_out1,clk_out2,clk_out3,clk_out4,clk_out5,clk_out6,clk_out7} \
    CONFIG.CLKOUT_REQUESTED_DUTY_CYCLE {50.000,50.000,50.000,50.000,50.000,50.000,50.000} \
    CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {100.000,100.000,100.000,100.000,100.000,100.000,100.000} \
    CONFIG.CLKOUT_REQUESTED_PHASE {0.000,0.000,0.000,0.000,0.000,0.000,0.000} \
    CONFIG.CLKOUT_USED {true,false,false,false,false,false,false} \
    CONFIG.USE_RESET {false} \
  ] $clk_wizard_0

  ##################################################################
  # Connections
  ##################################################################

  # PCIe GT + refclk
  connect_bd_intf_net -intf_net versal_cips_0_PCIE0_GT [get_bd_intf_ports PCIE0_GT_0] [get_bd_intf_pins versal_cips_0/PCIE0_GT]
  connect_bd_intf_net -intf_net pcie_refclk [get_bd_intf_ports gt_refclk0_0] [get_bd_intf_pins versal_cips_0/gt_refclk0]

  # PCIe DMA → NoC → AXI BRAM (replaces FireSim RTL)
  connect_bd_intf_net -intf_net cips_to_noc [get_bd_intf_pins versal_cips_0/CPM_PCIE_NOC_0] [get_bd_intf_pins axi_noc_0/S00_AXI]
  connect_bd_intf_net -intf_net noc_to_bram [get_bd_intf_pins axi_noc_0/M00_AXI] [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
  connect_bd_intf_net -intf_net noc_to_sc [get_bd_intf_pins axi_noc_0/M01_AXI] [get_bd_intf_pins smartconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net sc_to_bram_lite [get_bd_intf_pins smartconnect_0/M00_AXI] [get_bd_intf_pins axi_bram_ctrl_1/S_AXI]

  # BRAM connections
  connect_bd_intf_net -intf_net bram0_port [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins axi_bram_ctrl_0_bram/BRAM_PORTA]
  connect_bd_intf_net -intf_net bram1_port [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTA] [get_bd_intf_pins axi_bram_ctrl_1_bram/BRAM_PORTA]

  # Clocks
  connect_bd_net -net cips_pcie_noc_clk [get_bd_pins versal_cips_0/cpm_pcie_noc_axi0_clk] [get_bd_pins axi_noc_0/aclk0]
  connect_bd_net -net cips_pl0_ref_clk [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins clk_wizard_0/clk_in1]
  connect_bd_net -net sys_clk_net [get_bd_pins clk_wizard_0/clk_out1] \
    [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
    [get_bd_pins axi_noc_0/aclk1] \
    [get_bd_pins versal_cips_0/dma0_intrfc_clk] \
    [get_bd_pins smartconnect_0/aclk] \
    [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] \
    [get_bd_pins axi_bram_ctrl_1/s_axi_aclk]

  # Resets
  connect_bd_net -net cips_pl0_resetn [get_bd_pins versal_cips_0/pl0_resetn] [get_bd_pins proc_sys_reset_0/ext_reset_in]
  connect_bd_net -net reset_n [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
    [get_bd_pins versal_cips_0/dma0_intrfc_resetn] \
    [get_bd_pins smartconnect_0/aresetn] \
    [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] \
    [get_bd_pins axi_bram_ctrl_1/s_axi_aresetn]

  # Address segments — match production BAR mapping
  assign_bd_address -offset 0x020200000000 -range 0x00002000 -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_0] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
  assign_bd_address -offset 0x020100000000 -range 0x00002000 -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_0] [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0] -force

  validate_bd_design
  save_bd_design
}
create_root_design ""
