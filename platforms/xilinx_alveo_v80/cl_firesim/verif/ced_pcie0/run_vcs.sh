#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VCS_SIM_DIR="$SCRIPT_DIR/proj/ced_pcie0.sim/sim_1/behav/vcs"

# Environment
export VCS_HOME=/ecad/tools/synopsys/vcs/W-2024.09-1
export LD_LIBRARY_PATH=/scratch/raghavgupta/v80-chipyard/sims/firesim/platforms/xilinx_alveo_v80/cl_firesim/verif/lib32/usr/lib/i386-linux-gnu:${LD_LIBRARY_PATH:-}
export RDI_DATADIR="/ecad/tools/xilinx/2025.1/data"
source /ecad/tools/xilinx/2025.1/Vivado/settings64.sh

cd "$VCS_SIM_DIR"

STEP="${1:-all}"

case "$STEP" in
  compile|all)
    echo "=== VCS Compile ==="
    bash compile.sh 2>&1 | tee compile_full.log
    echo "Compile done (exit=$?)"
    ;;&
  elaborate|all)
    echo "=== VCS Elaborate ==="
    bash elaborate.sh 2>&1 | tee elaborate_full.log
    echo "Elaborate done (exit=$?)"
    ;;&
  simulate|all)
    echo "=== VCS Simulate ==="
    bash simulate.sh 2>&1 | tee simulate_full.log
    echo "Simulate done (exit=$?)"
    ;;
esac
