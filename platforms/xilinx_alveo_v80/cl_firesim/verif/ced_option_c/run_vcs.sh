#!/bin/bash
# run_vcs.sh — compile, elaborate, simulate Option C in VCS
#
# Usage:
#   ./run_vcs.sh                          # full build + default test (qdma_mm_st_test0)
#   ./run_vcs.sh bar1_scratch_test0       # full build + named test
#   ./run_vcs.sh --sim-only <testname>    # skip compile/elaborate, run sim only
#
# Available custom tests (defined in tests_v80_bar.vh):
#   bar1_scratch_test0    — BAR1 scratch register write/readback
#   bar0_qdma_ident_test0 — BAR0 QDMA identification register
#   bar_interleave_test0  — Interleaved BAR0/BAR1 accesses
#   bar1_regmap_test0     — BAR1 user_control register map
#   bar1_dma_combo_test0  — BAR1 MMIO + QDMA MM DMA combo
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SIM_DIR="$SCRIPT_DIR/proj/ced_option_c.sim/sim_1/behav/vcs"

export VCS_HOME=/ecad/tools/synopsys/vcs/W-2024.09-1
export PATH=$VCS_HOME/bin:$PATH
VERIF_DIR="$SCRIPT_DIR/.."
export LD_LIBRARY_PATH=$VERIF_DIR/lib32:$VERIF_DIR/vcs_xilinx_lib/secureip:$LD_LIBRARY_PATH

SIM_ONLY=0
TESTNAME=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sim-only) SIM_ONLY=1; shift ;;
        *) TESTNAME="$1"; shift ;;
    esac
done

cd "$SIM_DIR"

if [[ $SIM_ONLY -eq 0 ]]; then
    echo "=== Phase 1: Compile ==="
    bash compile.sh 2>&1 | tee compile.log
    echo "=== Phase 2: Elaborate ==="
    bash elaborate.sh 2>&1 | tee elaborate.log
fi

echo "=== Phase 3: Simulate${TESTNAME:+ ($TESTNAME)} ==="
if [[ -n "$TESTNAME" ]]; then
    ./board_simv -ucli -licqueue +TESTNAME="$TESTNAME" -do board_simulate.do 2>&1 | tee simulate.log
else
    bash simulate.sh 2>&1 | tee simulate.log
fi
echo "=== Done ==="
