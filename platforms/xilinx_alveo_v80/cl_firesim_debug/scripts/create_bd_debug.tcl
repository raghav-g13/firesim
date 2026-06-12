# create_bd_debug.tcl
#
# Self-contained Tcl script that creates a debug block design for the
# Xilinx Alveo V80.  The design replaces the F1Shim (and DDR NoC) with
# AXI BRAM Controllers so that the QDMA data path through the Versal NoC
# can be tested in isolation.
#
# Topology (same as production minus DDR, plus BRAMs):
#
#   QDMA (CPM5)
#     |
#   CPM_PCIE_NOC_0
#     |
#   axi_noc_0  ----M00_AXI----> axi_bram_ctrl_0 (AXI4, 512b)  + emb_mem_gen_0
#     |         \
#     |          +--M01_AXI---> smartconnect_0 --M00_AXI--> axi_bram_ctrl_1 (AXI4LITE, 32b) + emb_mem_gen_1
#     |          \
#     |           \-M02_AXI---> axi_noc_1 (DDR4 controller) ---> physical DDR4
#     |
#   clk_wizard_0 (10 MHz debug clock)
#   proc_sys_reset_0
#
# Usage:
#   source create_bd_debug.tcl
#   create_debug_design

proc create_debug_design {} {

    # ------------------------------------------------------------------
    # 1. Create the block design
    # ------------------------------------------------------------------
    set design_name design_1

    set cur_design [current_bd_design -quiet]
    if { $cur_design eq "" || [get_bd_cells -quiet] eq "" } {
        if { $cur_design ne "" && $cur_design ne $design_name } {
            set design_name $cur_design
        }
        if { [get_files -quiet ${design_name}.bd] ne "" } {
            puts "ERROR: design $design_name already exists"
            return 1
        }
        create_bd_design $design_name
        current_bd_design $design_name
    }

    set parentObj [get_bd_cells /]

    # ------------------------------------------------------------------
    # 2. Check required IPs
    # ------------------------------------------------------------------
    set required_ips {
        xilinx.com:ip:versal_cips:3.4
        xilinx.com:ip:clk_wizard:1.0
        xilinx.com:ip:proc_sys_reset:5.0
        xilinx.com:ip:axi_noc:1.1
        xilinx.com:ip:smartconnect:1.0
        xilinx.com:ip:axi_bram_ctrl:4.1
        xilinx.com:ip:emb_mem_gen:1.0
    }
    foreach ip $required_ips {
        if { [get_ipdefs -all $ip] eq "" } {
            puts "ERROR: IP $ip not found in catalog"
            return 1
        }
    }

    # ------------------------------------------------------------------
    # 3. Create interface ports (external)
    # ------------------------------------------------------------------

    # PCIe reference clock
    set pcie_refclk [ create_bd_intf_port -mode Slave \
        -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk ]
    set_property -dict [ list CONFIG.FREQ_HZ {100000000} ] $pcie_refclk

    # PCIe GT (x16)
    set pci_express_x16 [ create_bd_intf_port -mode Master \
        -vlnv xilinx.com:interface:gt_rtl:1.0 pci_express_x16 ]

    # DDR4 SDRAM
    set ddr4_sdram_c0 [ create_bd_intf_port -mode Master \
        -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c0 ]

    # DDR4 reference clock
    set sys_clk0_1 [ create_bd_intf_port -mode Slave \
        -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk0_1 ]
    set_property -dict [ list CONFIG.FREQ_HZ {200000000} ] $sys_clk0_1

    # Output clock and reset for debug probing
    set sys_clk [ create_bd_port -dir O -type clk sys_clk ]
    set sys_reset_n [ create_bd_port -dir O -from 0 -to 0 -type rst sys_reset_n ]

    # ------------------------------------------------------------------
    # 4. Create IP instances
    # ------------------------------------------------------------------

    # --- proc_sys_reset_0 ---
    set proc_sys_reset_0 [ create_bd_cell -type ip \
        -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

    # --- versal_cips_0 (CIPS with CPM5 QDMA) ---
    # Identical configuration to the production design.
    set versal_cips_0 [ create_bd_cell -type ip \
        -vlnv xilinx.com:ip:versal_cips:3.4 versal_cips_0 ]
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
          CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH {X16} \
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

    # --- clk_wizard_0 (10 MHz debug clock) ---
    set clk_wizard_0 [ create_bd_cell -type ip \
        -vlnv xilinx.com:ip:clk_wizard:1.0 clk_wizard_0 ]
    set_property -dict [list \
        CONFIG.CLKOUT_DRIVES {BUFG,BUFG,BUFG,BUFG,BUFG,BUFG,BUFG} \
        CONFIG.CLKOUT_DYN_PS {None,None,None,None,None,None,None} \
        CONFIG.CLKOUT_GROUPING {Auto,Auto,Auto,Auto,Auto,Auto,Auto} \
        CONFIG.CLKOUT_MATCHED_ROUTING {false,false,false,false,false,false,false} \
        CONFIG.CLKOUT_PORT {clk_out1,clk_out2,clk_out3,clk_out4,clk_out5,clk_out6,clk_out7} \
        CONFIG.CLKOUT_REQUESTED_DUTY_CYCLE {50.000,50.000,50.000,50.000,50.000,50.000,50.000} \
        CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {10.000,100.000,100.000,100.000,100.000,100.000,100.000} \
        CONFIG.CLKOUT_REQUESTED_PHASE {0.000,0.000,0.000,0.000,0.000,0.000,0.000} \
        CONFIG.CLKOUT_USED {true,false,false,false,false,false,false} \
        CONFIG.USE_RESET {false} \
    ] $clk_wizard_0

    # --- axi_noc_0 ---
    # S00_AXI from CPM_PCIE_NOC_0; M00_AXI to DMA BRAM; M01_AXI to MMIO; M00_INI to DDR NoC
    set axi_noc_0 [ create_bd_cell -type ip \
        -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_0 ]
    set_property -dict [list \
        CONFIG.NUM_CLKS {3} \
        CONFIG.NUM_MI {2} \
        CONFIG.NUM_NMI {1} \
        CONFIG.SI_SIDEBAND_PINS {} \
    ] $axi_noc_0

    # M00_AXI aperture: DMA data path at 0x203_0000_0000
    set_property -dict [ list \
       CONFIG.APERTURES {{0x203_0000_0000 4G}} \
       CONFIG.CATEGORY {pl} \
    ] [get_bd_intf_pins /axi_noc_0/M00_AXI]

    # M01_AXI aperture: MMIO path at 0x201_0000_0000
    set_property -dict [ list \
       CONFIG.APERTURES {{0x201_0000_0000 1G}} \
       CONFIG.CATEGORY {pl} \
    ] [get_bd_intf_pins /axi_noc_0/M01_AXI]

    # S00_AXI: from CPM PCIe NoC — routes to BRAM, MMIO, and DDR via INI
    set_property -dict [ list \
       CONFIG.CONNECTIONS {M01_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}} M00_AXI {read_bw {1720} write_bw {1720} read_avg_burst {4} write_avg_burst {4}} M00_INI {read_bw {1720} write_bw {1720} read_avg_burst {4} write_avg_burst {4}}} \
       CONFIG.DEST_IDS {M01_AXI:0x40:M00_AXI:0xc0} \
       CONFIG.NOC_PARAMS {} \
       CONFIG.CATEGORY {ps_pcie} \
    ] [get_bd_intf_pins /axi_noc_0/S00_AXI]

    # Clock associations
    set_property -dict [ list \
       CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
    ] [get_bd_pins /axi_noc_0/aclk0]

    set_property -dict [ list \
       CONFIG.ASSOCIATED_BUSIF {M00_AXI:M01_AXI} \
    ] [get_bd_pins /axi_noc_0/aclk1]

    set_property -dict [ list \
       CONFIG.ASSOCIATED_BUSIF {} \
    ] [get_bd_pins /axi_noc_0/aclk2]

    # --- smartconnect_0 ---
    # Bridges NoC M01_AXI (AXI-MM) to the AXI4-Lite BRAM controller
    set smartconnect_0 [ create_bd_cell -type ip \
        -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
    set_property -dict [list \
        CONFIG.NUM_CLKS {1} \
        CONFIG.NUM_SI {1} \
    ] $smartconnect_0

    # --- axi_bram_ctrl_0 (DMA data path, AXI4, 512-bit) ---
    # 8 KB BRAM -> depth = 8192 / 64 bytes-per-beat = 128 locations at 512b width
    set axi_bram_ctrl_0 [ create_bd_cell -type ip \
        -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0 ]
    set_property -dict [list \
        CONFIG.PROTOCOL {AXI4} \
        CONFIG.DATA_WIDTH {512} \
        CONFIG.SINGLE_PORT_BRAM {1} \
    ] $axi_bram_ctrl_0

    # --- emb_mem_gen_0 (BRAM for DMA data path) ---
    # Size is auto-propagated from axi_bram_ctrl_0 based on address assignment.
    set emb_mem_gen_0 [ create_bd_cell -type ip \
        -vlnv xilinx.com:ip:emb_mem_gen:1.0 emb_mem_gen_0 ]
    set_property -dict [list \
        CONFIG.MEMORY_TYPE {True_Dual_Port_RAM} \
        CONFIG.READ_LATENCY_A {1} \
        CONFIG.READ_LATENCY_B {1} \
    ] $emb_mem_gen_0

    # --- axi_bram_ctrl_1 (MMIO path, AXI4LITE, 32-bit) ---
    # 8 KB BRAM -> depth = 8192 / 4 = 2048 locations at 32b width
    set axi_bram_ctrl_1 [ create_bd_cell -type ip \
        -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_1 ]
    set_property -dict [list \
        CONFIG.PROTOCOL {AXI4LITE} \
        CONFIG.DATA_WIDTH {32} \
        CONFIG.SINGLE_PORT_BRAM {1} \
    ] $axi_bram_ctrl_1

    # --- emb_mem_gen_1 (BRAM for MMIO path) ---
    # Size is auto-propagated from axi_bram_ctrl_1 based on address assignment.
    set emb_mem_gen_1 [ create_bd_cell -type ip \
        -vlnv xilinx.com:ip:emb_mem_gen:1.0 emb_mem_gen_1 ]
    set_property -dict [list \
        CONFIG.MEMORY_TYPE {True_Dual_Port_RAM} \
        CONFIG.READ_LATENCY_A {1} \
        CONFIG.READ_LATENCY_B {1} \
    ] $emb_mem_gen_1

    # --- axi_noc_1 (DDR4 controller) ---
    # Connected via INI from axi_noc_0 (not PL AXI)
    set axi_noc_1 [ create_bd_cell -type ip \
        -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_1 ]
    set_property -dict [list \
        CONFIG.CONTROLLERTYPE {DDR4_SDRAM} \
        CONFIG.MC0_CONFIG_NUM {config21} \
        CONFIG.MC0_FLIPPED_PINOUT {false} \
        CONFIG.MC_CHAN_REGION0 {DDR_CH2} \
        CONFIG.MC_CHAN_REGION1 {NONE} \
        CONFIG.MC_COMPONENT_WIDTH {x4} \
        CONFIG.MC_DATAWIDTH {72} \
        CONFIG.MC_INPUTCLK0_PERIOD {5000} \
        CONFIG.MC_MEMORY_DEVICETYPE {RDIMMs} \
        CONFIG.MC_MEMORY_SPEEDGRADE {DDR4-3200AA(22-22-22)} \
        CONFIG.MC_NO_CHANNELS {Single} \
        CONFIG.MC_PARITY {true} \
        CONFIG.MC_RANK {1} \
        CONFIG.MC_ROWADDRESSWIDTH {18} \
        CONFIG.MC_STACKHEIGHT {1} \
        CONFIG.MC_SYSTEM_CLOCK {Differential} \
        CONFIG.NUM_MC {1} \
        CONFIG.NUM_MCP {4} \
        CONFIG.NUM_MI {0} \
        CONFIG.NUM_SI {0} \
        CONFIG.NUM_NSI {1} \
    ] $axi_noc_1

    # S00_INI: INI slave from axi_noc_0, routes to DDR MC
    set_property -dict [ list \
       CONFIG.CONNECTIONS {MC_0 {read_bw {1720} write_bw {1720} read_avg_burst {4} write_avg_burst {4}}} \
    ] [get_bd_intf_pins /axi_noc_1/S00_INI]

    # ------------------------------------------------------------------
    # 5. Interface connections
    # ------------------------------------------------------------------

    # PCIe GT
    connect_bd_intf_net -intf_net versal_cips_0_PCIE0_GT \
        [get_bd_intf_ports pci_express_x16] \
        [get_bd_intf_pins versal_cips_0/PCIE0_GT]

    # PCIe refclk
    connect_bd_intf_net -intf_net pcie_refclk_1 \
        [get_bd_intf_ports pcie_refclk] \
        [get_bd_intf_pins versal_cips_0/gt_refclk0]

    # CPM_PCIE_NOC_0 -> axi_noc_0 S00_AXI
    connect_bd_intf_net -intf_net versal_cips_0_CPM_PCIE_NOC_0 \
        [get_bd_intf_pins versal_cips_0/CPM_PCIE_NOC_0] \
        [get_bd_intf_pins axi_noc_0/S00_AXI]

    # NoC M00_AXI -> axi_bram_ctrl_0 (DMA data BRAM)
    connect_bd_intf_net -intf_net axi_noc_0_M00_AXI \
        [get_bd_intf_pins axi_noc_0/M00_AXI] \
        [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]

    # NoC M01_AXI -> smartconnect_0 S00_AXI
    connect_bd_intf_net -intf_net axi_noc_0_M01_AXI1 \
        [get_bd_intf_pins axi_noc_0/M01_AXI] \
        [get_bd_intf_pins smartconnect_0/S00_AXI]

    # smartconnect_0 M00_AXI -> axi_bram_ctrl_1 (MMIO BRAM)
    connect_bd_intf_net -intf_net smartconnect_0_M00_AXI \
        [get_bd_intf_pins smartconnect_0/M00_AXI] \
        [get_bd_intf_pins axi_bram_ctrl_1/S_AXI]

    # BRAM controller 0 -> emb_mem_gen_0
    connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA \
        [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] \
        [get_bd_intf_pins emb_mem_gen_0/BRAM_PORTA]

    # BRAM controller 1 -> emb_mem_gen_1
    connect_bd_intf_net -intf_net axi_bram_ctrl_1_BRAM_PORTA \
        [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTA] \
        [get_bd_intf_pins emb_mem_gen_1/BRAM_PORTA]

    # INI: axi_noc_0 -> axi_noc_1 (DDR path, NoC-level interconnect)
    connect_bd_intf_net -intf_net axi_noc_0_M00_INI \
        [get_bd_intf_pins axi_noc_0/M00_INI] \
        [get_bd_intf_pins axi_noc_1/S00_INI]

    # DDR4 physical interface
    connect_bd_intf_net -intf_net axi_noc_1_CH0_DDR4_0 \
        [get_bd_intf_ports ddr4_sdram_c0] \
        [get_bd_intf_pins axi_noc_1/CH0_DDR4_0]

    # DDR4 reference clock
    connect_bd_intf_net -intf_net sys_clk0_1_1 \
        [get_bd_intf_ports sys_clk0_1] \
        [get_bd_intf_pins axi_noc_1/sys_clk0]

    # ------------------------------------------------------------------
    # 6. Clock and reset connections
    # ------------------------------------------------------------------

    # sys_clk net: clk_wizard_0/clk_out1 -> everything on the PL side
    connect_bd_net -net sys_clk_net \
        [get_bd_pins clk_wizard_0/clk_out1] \
        [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
        [get_bd_pins axi_noc_0/aclk1] \
        [get_bd_pins axi_noc_0/aclk2] \
        [get_bd_pins versal_cips_0/dma0_intrfc_clk] \
        [get_bd_pins smartconnect_0/aclk] \
        [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] \
        [get_bd_pins axi_bram_ctrl_1/s_axi_aclk] \
        [get_bd_ports sys_clk]

    # CPM PCIe NoC clock -> axi_noc_0 aclk0
    connect_bd_net -net versal_cips_0_cpm_pcie_noc_axi0_clk \
        [get_bd_pins versal_cips_0/cpm_pcie_noc_axi0_clk] \
        [get_bd_pins axi_noc_0/aclk0]

    # pl0_ref_clk -> clk_wizard_0 input
    connect_bd_net -net versal_cips_0_pl0_ref_clk \
        [get_bd_pins versal_cips_0/pl0_ref_clk] \
        [get_bd_pins clk_wizard_0/clk_in1]

    # pl0_resetn -> proc_sys_reset_0
    connect_bd_net -net versal_cips_0_pl0_resetn \
        [get_bd_pins versal_cips_0/pl0_resetn] \
        [get_bd_pins proc_sys_reset_0/ext_reset_in]

    # interconnect_aresetn -> reset distribution
    connect_bd_net -net proc_sys_reset_0_interconnect_aresetn \
        [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
        [get_bd_ports sys_reset_n] \
        [get_bd_pins versal_cips_0/dma0_intrfc_resetn] \
        [get_bd_pins smartconnect_0/aresetn] \
        [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] \
        [get_bd_pins axi_bram_ctrl_1/s_axi_aresetn]

    # ------------------------------------------------------------------
    # 7. Address map
    # ------------------------------------------------------------------

    # DMA BRAM at 0x0203_0000_0000, range 8 KB (BRAM controller max is 2G;
    # range must match actual BRAM size since it propagates to emb_mem_gen)
    assign_bd_address -offset 0x020300000000 -range 0x2000 \
        -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_0] \
        [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force

    # MMIO BRAM at 0x0201_0000_0000, range 8 KB
    assign_bd_address -offset 0x020100000000 -range 0x2000 \
        -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_0] \
        [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0] -force

    # DDR4 at fixed DDR_CH2 address 0x600_0000_0000, range 8 GB (via INI)
    assign_bd_address -offset 0x060000000000 -range 0x000200000000 \
        -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_0] \
        [get_bd_addr_segs axi_noc_1/S00_INI/C0_DDR_CH2] -force

    # ------------------------------------------------------------------
    # 8. Validate and save
    # ------------------------------------------------------------------
    validate_bd_design
    save_bd_design

    puts "INFO: Debug block design created successfully."
    return 0
}
