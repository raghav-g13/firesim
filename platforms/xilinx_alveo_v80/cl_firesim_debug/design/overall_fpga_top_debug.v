`timescale 1 ps / 1 ps

`include "helpers.vh"

module overall_fpga_top_debug(
    `DDR4_PDEF(ddr4_sdram_c0),

    `DIFF_CLK_PDEF(sys_clk0_1),

    input  wire [15:0] pci_express_x16_grx_n,
    input  wire [15:0] pci_express_x16_grx_p,
    output wire [15:0] pci_express_x16_gtx_n,
    output wire [15:0] pci_express_x16_gtx_p,

    `DIFF_CLK_PDEF(pcie_refclk)
);

    wire        sys_clk;
    wire [0:0]  sys_reset_n;

    design_1 design_1_i (
        .sys_clk               (sys_clk),
        .sys_reset_n           (sys_reset_n)

        `define DDR4_PAR
        `DDR4_CONNECT(ddr4_sdram_c0, ddr4_sdram_c0)
        `undef DDR4_PAR

        `DIFF_CLK_CONNECT(sys_clk0_1, sys_clk0_1)

        , .pci_express_x16_grx_n (pci_express_x16_grx_n)
        , .pci_express_x16_grx_p (pci_express_x16_grx_p)
        , .pci_express_x16_gtx_n (pci_express_x16_gtx_n)
        , .pci_express_x16_gtx_p (pci_express_x16_gtx_p)
        `DIFF_CLK_CONNECT(pcie_refclk, pcie_refclk)
    );

endmodule
