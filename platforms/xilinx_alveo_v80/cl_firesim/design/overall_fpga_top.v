`timescale 1 ps / 1 ps

`include "helpers.vh"
`include "axi.vh"

module overall_fpga_top(
    `DDR4_PDEF(ddr4_sdram_c0),

    `DIFF_CLK_PDEF(sys_clk0_1),

    input wire [15:0] pci_express_x16_grx_n,
    input wire [15:0] pci_express_x16_grx_p,
    output wire [15:0] pci_express_x16_gtx_n,
    output wire [15:0] pci_express_x16_gtx_p,
    `DIFF_CLK_PDEF(pcie_refclk)
);

    wire sys_clk;
    wire sys_reset_n;

    `define AMBA_AXI4
    `define AMBA_AXI_CACHE
    `define AMBA_AXI_PROT
    `define AMBA_AXI_ID
    `AMBA_AXI_WIRE(PCIE_M_AXI, 2, 64, 512)
    `undef AMBA_AXI4
    `undef AMBA_AXI_CACHE
    `undef AMBA_AXI_PROT
    `undef AMBA_AXI_ID

    `define AMBA_AXI_PROT
    `AMBA_AXI_WIRE(PCIE_M_AXI_LITE, unused, 42, 32)
    `undef AMBA_AXI_PROT

    `define AMBA_AXI4
    `define AMBA_AXI_CACHE
    `define AMBA_AXI_PROT
    `define AMBA_AXI_QOS
    `define AMBA_AXI_ID
    `AMBA_AXI_WIRE(DDR4_0_S_AXI, 16, 64, 64)
    `undef AMBA_AXI4
    `undef AMBA_AXI_CACHE
    `undef AMBA_AXI_PROT
    `undef AMBA_AXI_QOS
    `undef AMBA_AXI_ID

    // F1Shim generates zero-based DDR addresses; NoC DDR_CH2 base is 0x600_0000_0000
    wire [34:0] firesim_slave_0_awaddr;
    wire [34:0] firesim_slave_0_araddr;
    assign DDR4_0_S_AXI_awaddr = {29'b0, firesim_slave_0_awaddr} + 64'h0000_0600_0000_0000;
    assign DDR4_0_S_AXI_araddr = {29'b0, firesim_slave_0_araddr} + 64'h0000_0600_0000_0000;

    design_1 design_1_i (
        .sys_clk(sys_clk)

	`define DDR4_PAR
	`DDR4_CONNECT(ddr4_sdram_c0, ddr4_sdram_c0)
	`undef DDR4_PAR

	`DIFF_CLK_CONNECT(sys_clk0_1, sys_clk0_1)

	`define AMBA_AXI4
	`define AMBA_AXI_CACHE
	`define AMBA_AXI_PROT
	`define AMBA_AXI_QOS
	`define AMBA_AXI_ID
	`AMBA_AXI_PORT_CONNECTION(DDR4_0_S_AXI, DDR4_0_S_AXI)
	`undef AMBA_AXI4
	`undef AMBA_AXI_CACHE
	`undef AMBA_AXI_PROT
	`undef AMBA_AXI_QOS
	`undef AMBA_AXI_ID

	`define AMBA_AXI4
	`define AMBA_AXI_CACHE
	`define AMBA_AXI_PROT
	`define AMBA_AXI_ID
	`AMBA_AXI_PORT_CONNECTION(PCIE_M_AXI, PCIE_M_AXI)
	`undef AMBA_AXI4
	`undef AMBA_AXI_CACHE
	`undef AMBA_AXI_PROT
	`undef AMBA_AXI_ID

	`define AMBA_AXI_PROT
	`AMBA_AXI_PORT_CONNECTION(PCIE_M_AXI_LITE, PCIE_M_AXI_LITE)
	`undef AMBA_AXI_PROT

        , .pci_express_x16_grx_n(pci_express_x16_grx_n)
        , .pci_express_x16_grx_p(pci_express_x16_grx_p)
        , .pci_express_x16_gtx_n(pci_express_x16_gtx_n)
        , .pci_express_x16_gtx_p(pci_express_x16_gtx_p)
	`DIFF_CLK_CONNECT(pcie_refclk, pcie_refclk)

        , .sys_reset_n(sys_reset_n)
    );

    // =========================================================================
    // Simulation-only AXI SRAM for QDMA DMA testing
    // =========================================================================
    // F1Shim's CPUManagedStreamEngine never generates AXI write responses
    // (b_valid is optimized to constant 0 by FIRRTL) and provides no memory
    // semantics for read-back. This SRAM sits on the PCIE_M_AXI bus during
    // simulation to provide proper AXI4 write/read responses for QDMA MM
    // DMA testing (H2C writes + C2H reads).
    //
    // Under ifndef SIMULATION, F1Shim drives the PCIE_M_AXI slave signals
    // directly as in the real FPGA design.
    // =========================================================================

`ifdef SIMULATION
    // Intermediate wires: F1Shim io_pcis slave outputs (unused in sim)
    wire        pcis_fs_awready;
    wire        pcis_fs_wready;
    wire        pcis_fs_bvalid;
    wire [1:0]  pcis_fs_bresp;
    wire [15:0] pcis_fs_bid;
    wire        pcis_fs_arready;
    wire        pcis_fs_rvalid;
    wire [511:0] pcis_fs_rdata;
    wire        pcis_fs_rlast;
    wire [1:0]  pcis_fs_rresp;
    wire [15:0] pcis_fs_rid;

    // 8KB SRAM for DMA data storage
    reg [7:0] pcis_mem [0:8191];

    // Write channel state
    reg        pcis_aw_active;
    reg [12:0] pcis_wr_base_addr;
    reg [7:0]  pcis_wr_len;
    reg [1:0]  pcis_wr_id;
    reg [7:0]  pcis_wr_beat;

    // B response state
    reg        pcis_b_pending;
    reg [1:0]  pcis_b_id_reg;

    // Read channel state
    reg        pcis_rd_active;
    reg [12:0] pcis_rd_base_addr;
    reg [7:0]  pcis_rd_len;
    reg [1:0]  pcis_rd_id;
    reg [7:0]  pcis_rd_beat;

    // Write channel control: SRAM drives PCIE_M_AXI slave signals
    assign PCIE_M_AXI_awready = !pcis_aw_active && !pcis_b_pending;
    assign PCIE_M_AXI_wready  = pcis_aw_active;
    assign PCIE_M_AXI_bvalid  = pcis_b_pending;
    assign PCIE_M_AXI_bresp   = 2'b00;
    assign PCIE_M_AXI_bid     = pcis_b_id_reg;

    // Read channel control: SRAM drives PCIE_M_AXI slave signals
    assign PCIE_M_AXI_arready = !pcis_rd_active;
    assign PCIE_M_AXI_rvalid  = pcis_rd_active;
    assign PCIE_M_AXI_rlast   = pcis_rd_active && (pcis_rd_beat == pcis_rd_len);
    assign PCIE_M_AXI_rresp   = 2'b00;
    assign PCIE_M_AXI_rid     = pcis_rd_id;

    // Read data from SRAM (combinational lookup)
    integer pcis_rd_byte_idx;
    reg [511:0] pcis_rdata_comb;
    always @(*) begin
        pcis_rdata_comb = 512'b0;
        for (pcis_rd_byte_idx = 0; pcis_rd_byte_idx < 64; pcis_rd_byte_idx = pcis_rd_byte_idx + 1) begin
            pcis_rdata_comb[pcis_rd_byte_idx*8 +: 8] = pcis_mem[((pcis_rd_base_addr + {5'b0, pcis_rd_beat, 6'b0} + pcis_rd_byte_idx) & 13'h1FFF)];
        end
    end
    assign PCIE_M_AXI_rdata = pcis_rdata_comb;

    // Sequential FSM for write and read channels
    integer pcis_wr_byte_idx;
    always @(posedge sys_clk) begin
        if (!sys_reset_n) begin
            pcis_aw_active <= 1'b0;
            pcis_b_pending <= 1'b0;
            pcis_rd_active <= 1'b0;
            pcis_wr_beat   <= 8'h0;
            pcis_rd_beat   <= 8'h0;
        end else begin
            // === AW channel: capture write address ===
            if (PCIE_M_AXI_awvalid && PCIE_M_AXI_awready) begin
                pcis_wr_base_addr <= PCIE_M_AXI_awaddr[12:0];
                pcis_wr_len       <= PCIE_M_AXI_awlen;
                pcis_wr_id        <= PCIE_M_AXI_awid;
                pcis_aw_active    <= 1'b1;
                pcis_wr_beat      <= 8'h0;
            end

            // === W channel: store data into SRAM ===
            if (pcis_aw_active && PCIE_M_AXI_wvalid) begin
                for (pcis_wr_byte_idx = 0; pcis_wr_byte_idx < 64; pcis_wr_byte_idx = pcis_wr_byte_idx + 1) begin
                    if (PCIE_M_AXI_wstrb[pcis_wr_byte_idx])
                        pcis_mem[((pcis_wr_base_addr + {5'b0, pcis_wr_beat, 6'b0} + pcis_wr_byte_idx) & 13'h1FFF)] <= PCIE_M_AXI_wdata[pcis_wr_byte_idx*8 +: 8];
                end
                pcis_wr_beat <= pcis_wr_beat + 8'h1;
                if (PCIE_M_AXI_wlast) begin
                    pcis_aw_active <= 1'b0;
                    pcis_b_pending <= 1'b1;
                    pcis_b_id_reg  <= pcis_wr_id;
                end
            end

            // === B channel: complete write response handshake ===
            if (pcis_b_pending && PCIE_M_AXI_bready) begin
                pcis_b_pending <= 1'b0;
            end

            // === AR channel: capture read address ===
            if (PCIE_M_AXI_arvalid && PCIE_M_AXI_arready) begin
                pcis_rd_base_addr <= PCIE_M_AXI_araddr[12:0];
                pcis_rd_len       <= PCIE_M_AXI_arlen;
                pcis_rd_id        <= PCIE_M_AXI_arid;
                pcis_rd_active    <= 1'b1;
                pcis_rd_beat      <= 8'h0;
            end

            // === R channel: deliver read data beats ===
            if (pcis_rd_active && PCIE_M_AXI_rready) begin
                if (pcis_rd_beat == pcis_rd_len) begin
                    pcis_rd_active <= 1'b0;
                end else begin
                    pcis_rd_beat <= pcis_rd_beat + 8'h1;
                end
            end
        end
    end

    // Initialize SRAM to zeros
    integer pcis_init_i;
    initial begin
        for (pcis_init_i = 0; pcis_init_i < 8192; pcis_init_i = pcis_init_i + 1)
            pcis_mem[pcis_init_i] = 8'h0;
    end
`endif // SIMULATION

    F1Shim firesim_top(
        .clock(sys_clk),
        .reset(!sys_reset_n),

        .io_master_aw_ready(PCIE_M_AXI_LITE_awready),
        .io_master_aw_valid(PCIE_M_AXI_LITE_awvalid),
        .io_master_aw_bits_addr(PCIE_M_AXI_LITE_awaddr[24:0]),
        .io_master_aw_bits_len(8'h0),
        .io_master_aw_bits_size(3'h2),
        .io_master_aw_bits_burst(2'h1),
        .io_master_aw_bits_lock(1'h0),
        .io_master_aw_bits_cache(4'h0),
        .io_master_aw_bits_prot(3'h0),
        .io_master_aw_bits_qos(4'h0),
        .io_master_aw_bits_region(4'h0),
        .io_master_aw_bits_id(12'h0),
        .io_master_aw_bits_user(1'h0),

        .io_master_w_ready(PCIE_M_AXI_LITE_wready),
        .io_master_w_valid(PCIE_M_AXI_LITE_wvalid),
        .io_master_w_bits_data(PCIE_M_AXI_LITE_wdata),
        .io_master_w_bits_last(1'h1),
        .io_master_w_bits_id(12'h0),
        .io_master_w_bits_strb(PCIE_M_AXI_LITE_wstrb),
        .io_master_w_bits_user(1'h0),

        .io_master_b_ready(PCIE_M_AXI_LITE_bready),
        .io_master_b_valid(PCIE_M_AXI_LITE_bvalid),
        .io_master_b_bits_resp(PCIE_M_AXI_LITE_bresp),
        .io_master_b_bits_id(),
        .io_master_b_bits_user(),

        .io_master_ar_ready(PCIE_M_AXI_LITE_arready),
        .io_master_ar_valid(PCIE_M_AXI_LITE_arvalid),
        .io_master_ar_bits_addr(PCIE_M_AXI_LITE_araddr[24:0]),
        .io_master_ar_bits_len(8'h0),
        .io_master_ar_bits_size(3'h2),
        .io_master_ar_bits_burst(2'h1),
        .io_master_ar_bits_lock(1'h0),
        .io_master_ar_bits_cache(4'h0),
        .io_master_ar_bits_prot(3'h0),
        .io_master_ar_bits_qos(4'h0),
        .io_master_ar_bits_region(4'h0),
        .io_master_ar_bits_id(12'h0),
        .io_master_ar_bits_user(1'h0),

        .io_master_r_ready(PCIE_M_AXI_LITE_rready),
        .io_master_r_valid(PCIE_M_AXI_LITE_rvalid),
        .io_master_r_bits_resp(PCIE_M_AXI_LITE_rresp),
        .io_master_r_bits_data(PCIE_M_AXI_LITE_rdata),
        .io_master_r_bits_last(),
        .io_master_r_bits_id(),
        .io_master_r_bits_user(),

`ifdef SIMULATION
        // In simulation, SRAM handles PCIE_M_AXI slave signals;
        // F1Shim io_pcis outputs go to intermediate wires (unused).
        .io_pcis_aw_ready(pcis_fs_awready),
        .io_pcis_w_ready(pcis_fs_wready),
        .io_pcis_b_valid(pcis_fs_bvalid),
        .io_pcis_b_bits_resp(pcis_fs_bresp),
        .io_pcis_b_bits_id(pcis_fs_bid),
        .io_pcis_ar_ready(pcis_fs_arready),
        .io_pcis_r_valid(pcis_fs_rvalid),
        .io_pcis_r_bits_data(pcis_fs_rdata),
        .io_pcis_r_bits_last(pcis_fs_rlast),
        .io_pcis_r_bits_resp(pcis_fs_rresp),
        .io_pcis_r_bits_id(pcis_fs_rid),
`else
        .io_pcis_aw_ready(PCIE_M_AXI_awready),
        .io_pcis_w_ready(PCIE_M_AXI_wready),
        .io_pcis_b_valid(PCIE_M_AXI_bvalid),
        .io_pcis_b_bits_resp(PCIE_M_AXI_bresp),
        .io_pcis_b_bits_id(PCIE_M_AXI_bid),
        .io_pcis_ar_ready(PCIE_M_AXI_arready),
        .io_pcis_r_valid(PCIE_M_AXI_rvalid),
        .io_pcis_r_bits_data(PCIE_M_AXI_rdata),
        .io_pcis_r_bits_last(PCIE_M_AXI_rlast),
        .io_pcis_r_bits_resp(PCIE_M_AXI_rresp),
        .io_pcis_r_bits_id(PCIE_M_AXI_rid),
`endif
        .io_pcis_b_bits_user(),
        .io_pcis_r_bits_user(),

        // io_pcis inputs: always connected to PCIE_M_AXI master signals
        .io_pcis_aw_valid(PCIE_M_AXI_awvalid),
        .io_pcis_aw_bits_addr({32'b0, PCIE_M_AXI_awaddr[31:0]}), // strip NoC base, keep lower 32 bits
        .io_pcis_aw_bits_len(PCIE_M_AXI_awlen),
        .io_pcis_aw_bits_size(PCIE_M_AXI_awsize),
        .io_pcis_aw_bits_burst(2'h1),
        .io_pcis_aw_bits_lock(1'h0),
        .io_pcis_aw_bits_cache(4'h0),
        .io_pcis_aw_bits_prot(3'h0),
        .io_pcis_aw_bits_qos(4'h0),
        .io_pcis_aw_bits_region(4'h0),
        .io_pcis_aw_bits_id({14'b0, PCIE_M_AXI_awid}),
        .io_pcis_aw_bits_user(1'h0),

        .io_pcis_w_valid(PCIE_M_AXI_wvalid),
        .io_pcis_w_bits_data(PCIE_M_AXI_wdata),
        .io_pcis_w_bits_last(PCIE_M_AXI_wlast),
        .io_pcis_w_bits_id(16'h0),
        .io_pcis_w_bits_strb(PCIE_M_AXI_wstrb),
        .io_pcis_w_bits_user(1'h0),

        .io_pcis_b_ready(PCIE_M_AXI_bready),

        .io_pcis_ar_valid(PCIE_M_AXI_arvalid),
        .io_pcis_ar_bits_addr({32'b0, PCIE_M_AXI_araddr[31:0]}),
        .io_pcis_ar_bits_len(PCIE_M_AXI_arlen),
        .io_pcis_ar_bits_size(PCIE_M_AXI_arsize),
        .io_pcis_ar_bits_burst(2'h1),
        .io_pcis_ar_bits_lock(1'h0),
        .io_pcis_ar_bits_cache(4'h0),
        .io_pcis_ar_bits_prot(3'h0),
        .io_pcis_ar_bits_qos(4'h0),
        .io_pcis_ar_bits_region(4'h0),
        .io_pcis_ar_bits_id({14'b0, PCIE_M_AXI_arid}),
        .io_pcis_ar_bits_user(1'h0),

        .io_pcis_r_ready(PCIE_M_AXI_rready),

        .io_slave_0_aw_ready(DDR4_0_S_AXI_awready),
        .io_slave_0_aw_valid(DDR4_0_S_AXI_awvalid),
        .io_slave_0_aw_bits_addr(firesim_slave_0_awaddr),
        .io_slave_0_aw_bits_len(DDR4_0_S_AXI_awlen),
        .io_slave_0_aw_bits_size(DDR4_0_S_AXI_awsize),
        .io_slave_0_aw_bits_burst(DDR4_0_S_AXI_awburst),
        .io_slave_0_aw_bits_lock(DDR4_0_S_AXI_awlock),
        .io_slave_0_aw_bits_cache(DDR4_0_S_AXI_awcache),
        .io_slave_0_aw_bits_prot(DDR4_0_S_AXI_awprot),
        .io_slave_0_aw_bits_qos(DDR4_0_S_AXI_awqos),
        .io_slave_0_aw_bits_id(DDR4_0_S_AXI_awid),

        .io_slave_0_w_ready(DDR4_0_S_AXI_wready),
        .io_slave_0_w_valid(DDR4_0_S_AXI_wvalid),
        .io_slave_0_w_bits_data(DDR4_0_S_AXI_wdata),
        .io_slave_0_w_bits_last(DDR4_0_S_AXI_wlast),
        .io_slave_0_w_bits_strb(DDR4_0_S_AXI_wstrb),

        .io_slave_0_b_ready(DDR4_0_S_AXI_bready),
        .io_slave_0_b_valid(DDR4_0_S_AXI_bvalid),
        .io_slave_0_b_bits_resp(DDR4_0_S_AXI_bresp),
        .io_slave_0_b_bits_id(DDR4_0_S_AXI_bid),

        .io_slave_0_ar_ready(DDR4_0_S_AXI_arready),
        .io_slave_0_ar_valid(DDR4_0_S_AXI_arvalid),
        .io_slave_0_ar_bits_addr(firesim_slave_0_araddr),
        .io_slave_0_ar_bits_len(DDR4_0_S_AXI_arlen),
        .io_slave_0_ar_bits_size(DDR4_0_S_AXI_arsize),
        .io_slave_0_ar_bits_burst(DDR4_0_S_AXI_arburst),
        .io_slave_0_ar_bits_lock(DDR4_0_S_AXI_arlock),
        .io_slave_0_ar_bits_cache(DDR4_0_S_AXI_arcache),
        .io_slave_0_ar_bits_prot(DDR4_0_S_AXI_arprot),
        .io_slave_0_ar_bits_qos(DDR4_0_S_AXI_arqos),
        .io_slave_0_ar_bits_id(DDR4_0_S_AXI_arid),

        .io_slave_0_r_ready(DDR4_0_S_AXI_rready),
        .io_slave_0_r_valid(DDR4_0_S_AXI_rvalid),
        .io_slave_0_r_bits_resp(DDR4_0_S_AXI_rresp),
        .io_slave_0_r_bits_data(DDR4_0_S_AXI_rdata),
        .io_slave_0_r_bits_last(DDR4_0_S_AXI_rlast),
        .io_slave_0_r_bits_id(DDR4_0_S_AXI_rid)

    );

endmodule
