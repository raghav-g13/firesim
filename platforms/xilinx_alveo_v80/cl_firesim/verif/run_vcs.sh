#!/usr/bin/env bash
# run_vcs.sh — Run VCS simulation for FireSim V80 design
#
# Wrapper around the Vivado-generated board.sh VCS flow.
# Patches applied:
#   1. +define+SIMULATION= added to vlogan compile commands
#   2. VCS-specific elaborate flags: +error+999 -xlrm uniq_prior_final
#   3. synopsys_sim.setup OTHERS line corrected to /home/ray/... path
#   4. -Xcheck_p1800_2009=char added to vlogan_opts for SV compatibility
#   5. VCS shebang fix: #!/bin/sh -h → #!/bin/bash -h (dash doesn't support -h)
#   6. /usr/bin/time replacement (not available in container)
#
# Usage:
#   bash run_vcs.sh [compile|elaborate|simulate|all] [CL_DIR] [+TESTNAME=...]
#
# Examples:
#   bash run_vcs.sh compile
#   bash run_vcs.sh elaborate
#   bash run_vcs.sh all /path/to/cl_xilinx_alveo_v80-...
#   bash run_vcs.sh simulate +TESTNAME=qdma_mm_test0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIRESIM_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# ── libncurses.so.5 compatibility ────────────────────────────────────
if [[ ! -f /tmp/libncurses.so.5 ]]; then
    ln -sf /usr/lib/x86_64-linux-gnu/libncurses.so.6 /tmp/libncurses.so.5
    ln -sf /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /tmp/libtinfo.so.5
fi

# ── /usr/bin/time wrapper ────────────────────────────────────────────
TIME_WRAPPER=/tmp/bin_fixes/time
if [[ ! -x "$TIME_WRAPPER" ]]; then
    mkdir -p /tmp/bin_fixes
    cat > "$TIME_WRAPPER" << 'TWEOF'
#!/bin/bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p) shift ;; -f) shift; shift ;; -o) shift; shift ;; --append) shift ;; *) break ;;
    esac
done
exec "$@"
TWEOF
    chmod +x "$TIME_WRAPPER"
fi

# ── VCS shebang fix ─────────────────────────────────────────────────
REAL_VCS=/ecad/tools/synopsys/vcs/W-2024.09-1
PATCHED_VCS=/tmp/vcs_patched

if [[ ! -d "$PATCHED_VCS/bin" ]] || [[ ! -f "$PATCHED_VCS/bin/vlogan" ]]; then
    echo "=== Creating patched VCS installation ==="
    rm -rf "$PATCHED_VCS"
    mkdir -p "$PATCHED_VCS"
    for d in "$REAL_VCS"/*; do
        name=$(basename "$d")
        [[ "$name" != "bin" ]] && ln -s "$d" "$PATCHED_VCS/$name"
    done
    cp -r "$REAL_VCS/bin" "$PATCHED_VCS/bin"
    find "$PATCHED_VCS/bin" -type f -exec grep -l '#!/bin/sh -h' {} \; 2>/dev/null | \
        while read f; do sed -i '1s|#!/bin/sh -h|#!/bin/bash -h|' "$f"; done
    find "$PATCHED_VCS/bin" -type f -exec grep -l '^#!/bin/sh$' {} \; 2>/dev/null | \
        while read f; do sed -i '1s|^#!/bin/sh$|#!/bin/bash|' "$f"; done
    sed -i "s|/usr/bin/time|$TIME_WRAPPER|g" "$PATCHED_VCS/bin/vcs"
    echo "  Patched VCS installation created"
fi

# ── Environment ──────────────────────────────────────────────────────
export VCS_HOME="$PATCHED_VCS"
export PATH="$VCS_HOME/bin:$PATH"
export VCS_ARCH_OVERRIDE=linux
export LD_LIBRARY_PATH="/tmp:/home/ray/chipyard/.conda-env/lib:$SCRIPT_DIR/lib32/usr/lib/i386-linux-gnu:${LD_LIBRARY_PATH:-}"
export RDI_DATADIR="/ecad/tools/xilinx/2025.1/data"
source /ecad/tools/xilinx/2025.1/Vivado/settings64.sh

# ── Parse arguments ──────────────────────────────────────────────────
STEP="all"
CL_DIR=""
TESTNAME_ARG=""
TESTNAME_VALUE=""

for arg in "$@"; do
    case "$arg" in
        compile|elaborate|simulate|all) STEP="$arg" ;;
        +TESTNAME=*) TESTNAME_ARG="$arg"; TESTNAME_VALUE="${arg#+TESTNAME=}" ;;
        *) CL_DIR="$arg" ;;
    esac
done

# ── Resolve CL_DIR ──────────────────────────────────────────────────
if [[ -z "$CL_DIR" ]]; then
    CL_DIR="$(ls -d "$FIRESIM_DIR"/platforms/xilinx_alveo_v80/cl_xilinx_alveo_v80-* 2>/dev/null | sort | tail -1)"
fi
if [[ -z "$CL_DIR" || ! -d "$CL_DIR" ]]; then
    echo "ERROR: Could not find cl_xilinx_alveo_v80-* directory."
    exit 1
fi

VCS_SIM_DIR="$CL_DIR/vcs/vcs"
BOARD_SH="$VCS_SIM_DIR/board.sh"

if [[ ! -f "$BOARD_SH" ]]; then
    echo "ERROR: $BOARD_SH not found. Run gen_vcs_firesim.tcl first."
    exit 1
fi

echo "=== V80 FireSim VCS Simulation ==="
echo "CL_DIR   : $CL_DIR"
echo "VCS_DIR  : $VCS_SIM_DIR"
echo "STEP     : $STEP"
echo "VCS_HOME : $VCS_HOME"
[[ -n "$TESTNAME_ARG" ]] && echo "TESTNAME : $TESTNAME_VALUE"
echo ""

# ── Patch board.sh ───────────────────────────────────────────────────
echo "=== Patching board.sh ==="
if ! grep -q '+define+SIMULATION=' "$BOARD_SH"; then
    sed -i 's/+define+FIRESIM_EP=/+define+FIRESIM_EP= +define+SIMULATION=/g' "$BOARD_SH"
    echo "  Added +define+SIMULATION="
else echo "  +define+SIMULATION= already present"; fi

if ! grep -q 'Xcheck_p1800_2009=char' "$BOARD_SH"; then
    sed -i 's/vlogan_opts="-full64 -l .tmp_log"/vlogan_opts="-full64 -l .tmp_log -Xcheck_p1800_2009=char"/' "$BOARD_SH"
    echo "  Added -Xcheck_p1800_2009=char"
else echo "  -Xcheck_p1800_2009=char already present"; fi

if ! grep -q 'xlrm uniq_prior_final' "$BOARD_SH"; then
    sed -i 's/vcs_elab_opts="-full64 -debug_acc -t ps -licqueue -l elaborate.log"/vcs_elab_opts="-full64 -debug_acc -t ps -licqueue -l elaborate.log +error+999 -xlrm uniq_prior_final"/' "$BOARD_SH"
    echo "  Added +error+999 -xlrm uniq_prior_final"
else echo "  VCS elaborate flags already present"; fi

if grep -q '/scratch/raghavgupta/' "$BOARD_SH" 2>/dev/null; then
    sed -i "s|/scratch/raghavgupta/v80-chipyard/sims/firesim|/home/ray/chipyard/sims/firesim|g" "$BOARD_SH"
    echo "  Fixed paths"
else echo "  Paths already correct"; fi
echo ""


# ── Patch synopsys_sim.setup for xlnoc NPS library ──────────────────
patch_synopsys_sim_setup() {
    local setup_file="$VCS_SIM_DIR/synopsys_sim.setup"
    if [[ ! -f "$setup_file" ]]; then
        echo "  WARNING: synopsys_sim.setup not found"
        return
    fi
    if ! grep -q "noc_nps_v1_0_0" "$setup_file"; then
        sed -i '/^OTHERS=/i noc_nps_v1_0_0:vcs_lib/noc_nps_v1_0_0' "$setup_file"
        echo "  Added noc_nps_v1_0_0 library to synopsys_sim.setup"
    else
        echo "  noc_nps_v1_0_0 already in synopsys_sim.setup"
    fi
}

# ── Compile xlnoc NoC fabric BFM sources ─────────────────────────────
compile_xlnoc() {
    echo "=== Compiling xlnoc NoC fabric BFM ==="
    patch_synopsys_sim_setup
    cd "$VCS_SIM_DIR"

    local XLNOC_BD="$CL_DIR/vivado_proj/firesim.gen/sim_1/bd/xlnoc"
    local NPS_SHARED="$XLNOC_BD/ipshared/7c30"
    local XLNOC_VLOGAN_OPTS="-full64 -l .tmp_log -Xcheck_p1800_2009=char"
    local XLNOC_INCDIR="+incdir+$NPS_SHARED/hdl/bfm"

    # Create library directory
    mkdir -p vcs_lib/noc_nps_v1_0_0

    # Compile NPS BFM shared library (encrypted)
    echo "  Compiling noc_nps_v1_0 library..."
    vlogan -work noc_nps_v1_0_0 $XLNOC_VLOGAN_OPTS -sverilog "$XLNOC_INCDIR" "$NPS_SHARED/hdl/noc_nps_v1_0_vl_rfs.sv" 2>&1 | tee -a compile.log

    # Compile each NPS BFM instance (0..10)
    for i in 0 1 2 3 4 5 6 7 8 9 10; do
        local nps_dir="$XLNOC_BD/ip/xlnoc_nps_${i}_0/hdl/bfm"
        if [[ -d "$nps_dir" ]]; then
            echo "  Compiling xlnoc_nps_${i}_0..."
            vlogan -work xil_defaultlib $XLNOC_VLOGAN_OPTS -sverilog "$XLNOC_INCDIR" "$nps_dir/xlnoc_nps_${i}_0.sv" "$nps_dir/xlnoc_nps_${i}_0_top.sv" 2>&1 | tee -a compile.log
        fi
    done

    # Compile xlnoc top-level (Verilog-2001)
    echo "  Compiling xlnoc.v..."
    vlogan -work xil_defaultlib $XLNOC_VLOGAN_OPTS +v2k "$XLNOC_BD/sim/xlnoc.v" 2>&1 | tee -a compile.log

    echo "  xlnoc compilation complete"
    echo ""
}

# ── Helper: copy/check simulation data files ────────────────────────
copy_sim_data_files() {
    echo "=== Ensuring simulation data files are in VCS run directory ==="
    for pattern in "*.cdo" "*.mem" "nocattrs.dat" "*.csv" "xlnoc.bd" "xlnoc.bda"; do
        local count
        count=$(find "$VCS_SIM_DIR" -maxdepth 1 -name "$pattern" 2>/dev/null | wc -l)
        if [[ $count -eq 0 ]]; then
            echo "  WARNING: No $pattern files found"
        else
            echo "  Found $count $pattern file(s)"
        fi
    done
    echo ""
}

# ── Helper: update simulate.do ───────────────────────────────────────
update_simulate_do() {
    local do_file="$VCS_SIM_DIR/simulate.do"
    echo "=== Updating simulate.do ==="
    # CED VCS flow uses 'run 20ms; quit' — sufficient for CDO + PCIe link-up + DMA via NoC→F1Shim→FASED→DDR4
    printf 'run 20ms\nquit\n' > "$do_file"
    echo "  simulate.do: run 20ms; quit"
    echo ""
}

# ── Helper: check if recompile needed ────────────────────────────────
needs_recompile() {
    # If board_simv doesn't exist, definitely need compile+elaborate
    [[ ! -f "$VCS_SIM_DIR/board_simv" ]] && return 0

    # Check if testbench source files are newer than board_simv
    local simv_time
    simv_time=$(stat -c %Y "$VCS_SIM_DIR/board_simv" 2>/dev/null || echo 0)

    for src in "$SCRIPT_DIR/tests_firesim.vh" "$SCRIPT_DIR/tests.vh" \
               "$SCRIPT_DIR/usp_pci_exp_usrapp_tx.v" "$SCRIPT_DIR/board_firesim.v" \
               "$CL_DIR/design/overall_fpga_top.v"; do
        if [[ -f "$src" ]]; then
            local src_time
            src_time=$(stat -c %Y "$src" 2>/dev/null || echo 0)
            if [[ "$src_time" -gt "$simv_time" ]]; then
                echo "  Source $src is newer than board_simv — recompile needed"
                return 0
            fi
        fi
    done
    return 1
}

# ── Run VCS steps ────────────────────────────────────────────────────
cd "$VCS_SIM_DIR"

run_step() {
    local step_name="$1"
    local log_file="${step_name}_full.log"
    echo "=== VCS $step_name ==="
    bash board.sh -step "$step_name" 2>&1 | tee "$log_file"
    local rc=${PIPESTATUS[0]}
    echo ""
    echo "$step_name done (exit=$rc)"
    if [[ "$step_name" == "elaborate" && -f "board_simv" ]]; then
        echo "SUCCESS: board_simv binary produced"
        ls -la board_simv
    fi
    return $rc
}

run_simulate() {
    echo "=== VCS Simulate ==="

    # Auto-recompile if testbench sources changed
    if needs_recompile; then
        echo ""
        echo "=== Auto-recompiling (testbench sources changed) ==="
        run_step compile
        compile_xlnoc
        run_step elaborate
        echo ""
    fi

    # Update simulate.do with proper runtime
    update_simulate_do

    # Ensure data files are present
    copy_sim_data_files

    # Check board_simv exists
    if [[ ! -f "board_simv" ]]; then
        echo "ERROR: board_simv not found after compile+elaborate."
        exit 1
    fi

    if [[ -n "$TESTNAME_ARG" ]]; then
        echo "Running board_simv with $TESTNAME_ARG"
        echo "Command: ./board_simv -ucli -licqueue -l simulate.log -do simulate.do $TESTNAME_ARG"
        echo ""
        ./board_simv -ucli -licqueue -l simulate.log -do simulate.do "$TESTNAME_ARG" 2>&1 | tee simulate_full.log
    else
        echo "Running board_simv with default test (via board.sh)"
        bash board.sh -step simulate 2>&1 | tee simulate_full.log
    fi
    local RC=${PIPESTATUS[0]}
    echo ""
    echo "Simulate done (exit=$RC)"

    # Post-simulation analysis
    local logfile="simulate.log"
    [[ ! -f "$logfile" ]] && logfile="simulate_full.log"
    if [[ -f "$logfile" ]]; then
        echo ""
        echo "=== Simulation Summary ==="
        if grep -q "CDO programming done" "$logfile" 2>/dev/null; then
            echo "  CDO programming completed"
            grep "CDO programming done" "$logfile" | head -5
        else
            echo "  CDO programming NOT detected in log"
        fi
        if grep -qi 'LTSSM.*0x10\|LTSSM.*=.*10\b\|user_lnk_up.*=.*1' "$logfile" 2>/dev/null; then
            echo "  PCIe link-up achieved"
            grep -i 'LTSSM\|user_lnk_up' "$logfile" | tail -5
        else
            echo "  PCIe link-up NOT detected in log"
        fi
        if grep -q 'PASSED' "$logfile" 2>/dev/null; then
            echo "  Test PASSED"
            grep 'PASSED' "$logfile"
        elif grep -q 'ERROR.*FAILED\|TEST FAILED' "$logfile" 2>/dev/null; then
            echo "  Test FAILED"
            grep 'ERROR\|FAILED' "$logfile"
        fi
        if grep -q '\$finish' "$logfile" 2>/dev/null; then
            echo "  Simulation reached \$finish"
        fi
    fi
    return $RC
}

case "$STEP" in
    compile)   run_step compile; compile_xlnoc ;;
    elaborate) run_step elaborate ;;
    simulate)  run_simulate; exit $? ;;
    all)
        run_step compile
        compile_xlnoc
        run_step elaborate
        run_simulate
        exit $?
        ;;
esac
