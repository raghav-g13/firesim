// ── DMA AXI bus monitors ──────────────────────────────────────────
// Monitor PCIE_M_AXI (io_pcis / DMA port) to diagnose DMA routing
initial begin
  wait(board.EP.design_1_i.versal_cips_0.inst.cpm_0.inst.CPM_INST.SIP_CPM5_INST.i_cpm_sim_cfg_wrap.u_cpm_sim_cfg.cdo_programming_done);
  $display("[%t] DMA_MON: Starting PCIE_M_AXI monitor after CDO done", $realtime);
  fork
    // AW channel monitor
    forever begin
      @(posedge EP.design_1_i.sys_clk);
      if (EP.PCIE_M_AXI_awvalid === 1'b1) begin
        $display("[%t] DMA_MON: PCIE_M_AXI AW valid=%b ready=%b addr=%h len=%h size=%h",
          $realtime,
          EP.PCIE_M_AXI_awvalid,
          EP.PCIE_M_AXI_awready,
          EP.PCIE_M_AXI_awaddr,
          EP.PCIE_M_AXI_awlen,
          EP.PCIE_M_AXI_awsize);
      end
    end
    // W channel monitor
    forever begin
      @(posedge EP.design_1_i.sys_clk);
      if (EP.PCIE_M_AXI_wvalid === 1'b1 && EP.PCIE_M_AXI_wready === 1'b1) begin
        $display("[%t] DMA_MON: PCIE_M_AXI W handshake data[31:0]=%h strb=%h last=%b",
          $realtime,
          EP.PCIE_M_AXI_wdata[31:0],
          EP.PCIE_M_AXI_wstrb,
          EP.PCIE_M_AXI_wlast);
      end
    end
    // B channel monitor
    forever begin
      @(posedge EP.design_1_i.sys_clk);
      if (EP.PCIE_M_AXI_bvalid === 1'b1) begin
        $display("[%t] DMA_MON: PCIE_M_AXI B valid=%b ready=%b resp=%b",
          $realtime,
          EP.PCIE_M_AXI_bvalid,
          EP.PCIE_M_AXI_bready,
          EP.PCIE_M_AXI_bresp);
      end
    end
    // AR channel monitor
    forever begin
      @(posedge EP.design_1_i.sys_clk);
      if (EP.PCIE_M_AXI_arvalid === 1'b1) begin
        $display("[%t] DMA_MON: PCIE_M_AXI AR valid=%b ready=%b addr=%h len=%h",
          $realtime,
          EP.PCIE_M_AXI_arvalid,
          EP.PCIE_M_AXI_arready,
          EP.PCIE_M_AXI_araddr,
          EP.PCIE_M_AXI_arlen);
      end
    end
    // R channel monitor
    forever begin
      @(posedge EP.design_1_i.sys_clk);
      if (EP.PCIE_M_AXI_rvalid === 1'b1 && EP.PCIE_M_AXI_rready === 1'b1) begin
        $display("[%t] DMA_MON: PCIE_M_AXI R handshake data[31:0]=%h resp=%b last=%b",
          $realtime,
          EP.PCIE_M_AXI_rdata[31:0],
          EP.PCIE_M_AXI_rresp,
          EP.PCIE_M_AXI_rlast);
      end
    end
    // Also monitor PCIE_M_AXI_LITE (io_master) for unexpected DMA on control port
    forever begin
      @(posedge EP.design_1_i.sys_clk);
      if (EP.PCIE_M_AXI_LITE_awvalid === 1'b1) begin
        $display("[%t] DMA_MON: PCIE_M_AXI_LITE AW valid=%b ready=%b addr=%h (UNEXPECTED if DMA)",
          $realtime,
          EP.PCIE_M_AXI_LITE_awvalid,
          EP.PCIE_M_AXI_LITE_awready,
          EP.PCIE_M_AXI_LITE_awaddr);
      end
    end
  join
end
