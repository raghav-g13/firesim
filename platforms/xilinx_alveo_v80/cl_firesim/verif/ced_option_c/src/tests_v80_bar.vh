// tests_v80_bar.vh — Targeted BAR0/BAR1 tests for V80 production CIPS config
//
// Exercises the specific BAR address map used by the FireSim QDMA driver:
//   BAR0 (xdma_bar): 512K QDMA DMA registers  (PCIEBAR2AXIBAR = 0x020200000000)
//   BAR1 (user_bar): 32MB AXI4LITE user space  (PCIEBAR2AXIBAR = 0x020180000000)
//
// CED user_control registers used for readback verification:
//   0x60: scratch_reg1 (RW)
//   0x64: scratch_reg2 (RW)
//
// Included by tests.vh alongside sample_tests.vh.

// ── bar1_scratch_test0: BAR1 scratch register write/readback ──────────
//
// Verifies the full BAR1 → PCIEBAR2AXIBAR_QDMA_1 → NoC → M_AXIL →
// user_control path. This is the exact path that broke when
// PCIEBAR2AXIBAR_QDMA_1 pointed at BRAM (0x020100000000) instead of
// M_AXIL (0x020180000000).
//
else if (testname == "bar1_scratch_test0")
begin
    $display("[%t] === bar1_scratch_test0: BAR1 scratch register write/readback ===", $realtime);
    $display("[%t]   user_bar=%0d  xdma_bar=%0d", $realtime, user_bar, xdma_bar);

    board.RP.tx_usrapp.test_state = 0;

    // Pattern 1: all-ones
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h60, 32'hFFFFFFFF, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h64, 32'hFFFFFFFF, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h60);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'hFFFFFFFF) begin
        $display("ERROR: [%t] scratch_reg1 all-ones: expected FFFFFFFF, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h64);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'hFFFFFFFF) begin
        $display("ERROR: [%t] scratch_reg2 all-ones: expected FFFFFFFF, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end

    // Pattern 2: all-zeros
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h60, 32'h00000000, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h64, 32'h00000000, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h60);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h00000000) begin
        $display("ERROR: [%t] scratch_reg1 all-zeros: expected 00000000, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h64);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h00000000) begin
        $display("ERROR: [%t] scratch_reg2 all-zeros: expected 00000000, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end

    // Pattern 3: checkerboard
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h60, 32'hA5A5A5A5, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h64, 32'h5A5A5A5A, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h60);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'hA5A5A5A5) begin
        $display("ERROR: [%t] scratch_reg1 checkerboard: expected A5A5A5A5, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h64);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h5A5A5A5A) begin
        $display("ERROR: [%t] scratch_reg2 checkerboard: expected 5A5A5A5A, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end

    // Pattern 4: unique per-register
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h60, 32'hDEADBEEF, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h64, 32'hCAFEBABE, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h60);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'hDEADBEEF) begin
        $display("ERROR: [%t] scratch_reg1 unique: expected DEADBEEF, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h64);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'hCAFEBABE) begin
        $display("ERROR: [%t] scratch_reg2 unique: expected CAFEBABE, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end

    #1000;
    board.RP.tx_usrapp.pfTestIteration = board.RP.tx_usrapp.pfTestIteration + 1;
    if (board.RP.tx_usrapp.test_state == 1)
        $display("[%t] ERROR: bar1_scratch_test0 FAILED", $realtime);
    else
        $display("[%t] bar1_scratch_test0 PASSED — BAR1 M_AXIL path verified", $realtime);
    #1000;
    $finish;
end

// ── bar0_qdma_ident_test0: BAR0 QDMA identification register read ────
//
// Reads the QDMA IP identifier via BAR0 (xdma_bar) offset 0x0.
// Expected upper 16 bits: 0x1fd3 (QDMA subsystem signature).
// Verifies BAR0 → PCIEBAR2AXIBAR_QDMA_0 → NoC → QDMA DMA register path.
//
else if (testname == "bar0_qdma_ident_test0")
begin
    $display("[%t] === bar0_qdma_ident_test0: BAR0 QDMA identification ===", $realtime);
    $display("[%t]   user_bar=%0d  xdma_bar=%0d", $realtime, user_bar, xdma_bar);

    board.RP.tx_usrapp.test_state = 0;

    // Read QDMA subsystem identifier at BAR0 + 0x0
    board.RP.tx_usrapp.TSK_REG_READ(xdma_bar, 16'h0);
    $display("[%t]   QDMA ID register = %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
    if (board.RP.tx_usrapp.P_READ_DATA[31:16] !== 16'h1fd3) begin
        $display("ERROR: [%t] QDMA ID mismatch: expected 1fd3xxxx, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end

    // Read QDMA config at BAR0 + 0x04 (QDMA_GLBL_RING_SZ offset)
    board.RP.tx_usrapp.TSK_REG_READ(xdma_bar, 16'h04);
    $display("[%t]   QDMA register 0x04 = %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);

    // Read QDMA config at BAR0 + 0x08
    board.RP.tx_usrapp.TSK_REG_READ(xdma_bar, 16'h08);
    $display("[%t]   QDMA register 0x08 = %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);

    #1000;
    board.RP.tx_usrapp.pfTestIteration = board.RP.tx_usrapp.pfTestIteration + 1;
    if (board.RP.tx_usrapp.test_state == 1)
        $display("[%t] ERROR: bar0_qdma_ident_test0 FAILED", $realtime);
    else
        $display("[%t] bar0_qdma_ident_test0 PASSED — BAR0 QDMA registers accessible", $realtime);
    #1000;
    $finish;
end

// ── bar_interleave_test0: Interleaved BAR0/BAR1 accesses ─────────────
//
// Alternates BAR0 reads (QDMA regs) with BAR1 writes/reads (scratch regs),
// matching the real driver pattern: configure QDMA via BAR0, access widgets
// via BAR1, repeat. Tests that the NoC correctly routes both BARs
// concurrently without cross-contamination.
//
else if (testname == "bar_interleave_test0")
begin
    $display("[%t] === bar_interleave_test0: Interleaved BAR0/BAR1 accesses ===", $realtime);
    $display("[%t]   user_bar=%0d  xdma_bar=%0d", $realtime, user_bar, xdma_bar);

    board.RP.tx_usrapp.test_state = 0;

    // Round 1: BAR0 read → BAR1 write → BAR1 read
    board.RP.tx_usrapp.TSK_REG_READ(xdma_bar, 16'h0);
    if (board.RP.tx_usrapp.P_READ_DATA[31:16] !== 16'h1fd3) begin
        $display("ERROR: [%t] Round 1 BAR0 QDMA ID failed: %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h60, 32'h11111111, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h60);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h11111111) begin
        $display("ERROR: [%t] Round 1 BAR1 scratch_reg1: expected 11111111, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end

    // Round 2: BAR1 write → BAR0 read → BAR1 read (ensure BAR0 access doesn't corrupt BAR1 state)
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h60, 32'h22222222, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h64, 32'h33333333, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(xdma_bar, 16'h0);
    if (board.RP.tx_usrapp.P_READ_DATA[31:16] !== 16'h1fd3) begin
        $display("ERROR: [%t] Round 2 BAR0 QDMA ID failed: %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h60);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h22222222) begin
        $display("ERROR: [%t] Round 2 BAR1 scratch_reg1: expected 22222222, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h64);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h33333333) begin
        $display("ERROR: [%t] Round 2 BAR1 scratch_reg2: expected 33333333, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end

    // Round 3: rapid alternation — simulates driver init + MMIO polling
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h60, 32'hAAAA0001, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(xdma_bar, 16'h0);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h64, 32'hBBBB0002, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(xdma_bar, 16'h0);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h60);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'hAAAA0001) begin
        $display("ERROR: [%t] Round 3 BAR1 scratch_reg1: expected AAAA0001, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h64);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'hBBBB0002) begin
        $display("ERROR: [%t] Round 3 BAR1 scratch_reg2: expected BBBB0002, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end

    #1000;
    board.RP.tx_usrapp.pfTestIteration = board.RP.tx_usrapp.pfTestIteration + 1;
    if (board.RP.tx_usrapp.test_state == 1)
        $display("[%t] ERROR: bar_interleave_test0 FAILED", $realtime);
    else
        $display("[%t] bar_interleave_test0 PASSED — BAR0/BAR1 interleave verified", $realtime);
    #1000;
    $finish;
end

// ── bar1_regmap_test0: BAR1 user_control register map exercise ────────
//
// Writes/reads across the full user_control register map, hitting offsets
// that correspond to what FireSim widgets would occupy in production:
//   0x00 (QID), 0x04 (C2H length), 0x08 (C2H control), 0x20 (C2H pkt cnt),
//   0x30-0x4C (C2H writeback data), 0x60/0x64 (scratch), 0x84 (buf size).
// Each register is written and read back with the mask of bits that are
// actually stored (some registers are partial-width).
//
else if (testname == "bar1_regmap_test0")
begin : bar1_regmap_test0_blk
    reg [31:0] exp;
    integer fail_count;

    $display("[%t] === bar1_regmap_test0: BAR1 register map exercise ===", $realtime);
    $display("[%t]   user_bar=%0d", $realtime, user_bar);

    board.RP.tx_usrapp.test_state = 0;
    fail_count = 0;

    // 0x00: c2h_st_qid — 12-bit register
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h00, 32'h00000ABC, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h00);
    exp = 32'h00000ABC;
    if (board.RP.tx_usrapp.P_READ_DATA !== exp) begin
        $display("ERROR: [%t] reg 0x00 (QID): expected %h, got %h", $realtime, exp, board.RP.tx_usrapp.P_READ_DATA);
        fail_count = fail_count + 1;
    end

    // 0x04: c2h_st_len — 16-bit register
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h04, 32'h00001234, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h04);
    exp = 32'h00001234;
    if (board.RP.tx_usrapp.P_READ_DATA !== exp) begin
        $display("ERROR: [%t] reg 0x04 (C2H len): expected %h, got %h", $realtime, exp, board.RP.tx_usrapp.P_READ_DATA);
        fail_count = fail_count + 1;
    end

    // 0x20: c2h_num_pkt — 11-bit register
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h20, 32'h000003FF, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h20);
    exp = 32'h000003FF;
    if (board.RP.tx_usrapp.P_READ_DATA !== exp) begin
        $display("ERROR: [%t] reg 0x20 (pkt cnt): expected %h, got %h", $realtime, exp, board.RP.tx_usrapp.P_READ_DATA);
        fail_count = fail_count + 1;
    end

    // 0x30-0x4C: C2H writeback data — 8 x 32-bit registers (256 bits total)
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h30, 32'h10203040, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h34, 32'h50607080, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h38, 32'h90A0B0C0, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h3C, 32'hD0E0F000, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h40, 32'h01020304, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h44, 32'h05060708, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h48, 32'h090A0B0C, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h4C, 32'h0D0E0F00, 4'hF);

    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h30);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h10203040) begin
        $display("ERROR: [%t] reg 0x30: expected 10203040, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        fail_count = fail_count + 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h34);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h50607080) begin
        $display("ERROR: [%t] reg 0x34: expected 50607080, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        fail_count = fail_count + 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h40);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h01020304) begin
        $display("ERROR: [%t] reg 0x40: expected 01020304, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        fail_count = fail_count + 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h4C);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h0D0E0F00) begin
        $display("ERROR: [%t] reg 0x4C: expected 0D0E0F00, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        fail_count = fail_count + 1;
    end

    // 0x60/0x64: scratch registers — full 32-bit
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h60, 32'hFACEFEED, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h64, 32'hBAADF00D, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h60);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'hFACEFEED) begin
        $display("ERROR: [%t] reg 0x60: expected FACEFEED, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        fail_count = fail_count + 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h64);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'hBAADF00D) begin
        $display("ERROR: [%t] reg 0x64: expected BAADF00D, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        fail_count = fail_count + 1;
    end

    // 0x84: c2h_st_buffsz — 16-bit register
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h84, 32'h00002000, 4'hF);
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h84);
    exp = 32'h00002000;
    if (board.RP.tx_usrapp.P_READ_DATA !== exp) begin
        $display("ERROR: [%t] reg 0x84 (buf size): expected %h, got %h", $realtime, exp, board.RP.tx_usrapp.P_READ_DATA);
        fail_count = fail_count + 1;
    end

    #1000;
    board.RP.tx_usrapp.pfTestIteration = board.RP.tx_usrapp.pfTestIteration + 1;
    if (fail_count > 0) begin
        board.RP.tx_usrapp.test_state = 1;
        $display("[%t] ERROR: bar1_regmap_test0 FAILED — %0d register mismatches", $realtime, fail_count);
    end else
        $display("[%t] bar1_regmap_test0 PASSED — %0d registers verified", $realtime, 12);
    #1000;
    $finish;
end

// ── bar1_dma_combo_test0: BAR1 MMIO + DMA transfer ───────────────────
//
// Combines BAR1 register setup with a full QDMA MM DMA transfer.
// This is the closest to what the FireSim driver does: write widget
// config via BAR1, then trigger DMA via BAR0/QDMA engine.
// Uses the existing TSK_QDMA_MM_H2C/C2H tests after priming the
// scratch registers so we can verify BAR1 state survives DMA activity.
//
else if (testname == "bar1_dma_combo_test0")
begin
    $display("[%t] === bar1_dma_combo_test0: BAR1 MMIO + QDMA MM DMA ===", $realtime);
    $display("[%t]   user_bar=%0d  xdma_bar=%0d", $realtime, user_bar, xdma_bar);

    board.RP.tx_usrapp.test_state = 0;

    // Pre-DMA: write known pattern to scratch registers via BAR1
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h60, 32'h12345678, 4'hF);
    board.RP.tx_usrapp.TSK_REG_WRITE(user_bar, 32'h64, 32'h9ABCDEF0, 4'hF);

    // Run QDMA MM DMA (H2C then C2H)
    board.RP.tx_usrapp.TSK_PROG_HOST_PROFILE;
    qid = 11'h1;
    board.RP.tx_usrapp.TSK_QDMA_MM_H2C_TEST(qid, 0, 1);
    board.RP.tx_usrapp.TSK_QDMA_MM_C2H_TEST(qid, 0, 1);
    #1000;

    // Post-DMA: verify scratch registers still hold pre-DMA values
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h60);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h12345678) begin
        $display("ERROR: [%t] Post-DMA scratch_reg1: expected 12345678, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end
    board.RP.tx_usrapp.TSK_REG_READ(user_bar, 16'h64);
    if (board.RP.tx_usrapp.P_READ_DATA !== 32'h9ABCDEF0) begin
        $display("ERROR: [%t] Post-DMA scratch_reg2: expected 9ABCDEF0, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end

    // BAR0 check: QDMA identity still readable post-DMA
    board.RP.tx_usrapp.TSK_REG_READ(xdma_bar, 16'h0);
    if (board.RP.tx_usrapp.P_READ_DATA[31:16] !== 16'h1fd3) begin
        $display("ERROR: [%t] Post-DMA BAR0 QDMA ID: expected 1fd3xxxx, got %h", $realtime, board.RP.tx_usrapp.P_READ_DATA);
        board.RP.tx_usrapp.test_state = 1;
    end

    board.RP.tx_usrapp.pfTestIteration = board.RP.tx_usrapp.pfTestIteration + 1;
    if (board.RP.tx_usrapp.test_state == 1)
        $display("[%t] ERROR: bar1_dma_combo_test0 FAILED", $realtime);
    else
        $display("[%t] bar1_dma_combo_test0 PASSED — BAR1 state survives DMA", $realtime);
    #1000;
    $finish;
end
