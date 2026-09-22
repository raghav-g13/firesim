#!/usr/bin/env bash
# run_xsim.sh — Run the exported XSim simulation with required patches
#
# Patches applied:
#   1. Vivado's ar (compatible with xelab object files)
#   2. -d FIRESIM_EP added to xvlog_opts (compile-time define)
#   3. --downgrade_fatal2warning on xsim (NoC NMU X during reset)
#   4. Locale fix for containers missing en_US.UTF-8
#   5. Test name selection via command-line argument
#
# Usage:
#   bash run_xsim.sh [CL_DIR] [TESTNAME]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIRESIM_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

if [[ $# -ge 1 ]]; then
    CL_DIR="$(cd "$FIRESIM_DIR" && cd "$1" && pwd)"
else
    CL_DIR="$(ls -d "$FIRESIM_DIR"/platforms/xilinx_alveo_v80/cl_xilinx_alveo_v80-* 2>/dev/null | sort | tail -1)"
fi


# Parse optional test name (default: bar_test0)
TESTNAME="${2:-bar_test0}"
XSIM_DIR="$CL_DIR/xsim/xsim"
BOARD_SH="$XSIM_DIR/board.sh"

if [[ ! -f "$BOARD_SH" ]]; then
    echo "ERROR: $BOARD_SH not found. Run setup_xsim.tcl first."
    exit 1
fi

echo "=== Patching board.sh ==="

# Patch 1: Add -d FIRESIM_EP to xvlog_opts if not already present
if ! grep -q '\-d FIRESIM_EP' "$BOARD_SH"; then
    sed -i 's/xvlog_opts="/xvlog_opts="-d FIRESIM_EP /' "$BOARD_SH"
    echo "  Added -d FIRESIM_EP to xvlog_opts"
else
    echo "  -d FIRESIM_EP already present"
fi

# Patch 2: Add --downgrade_fatal2warning to xsim command if not present
if ! grep -q 'downgrade_fatal2warning' "$BOARD_SH"; then
    sed -i 's/xsim board/xsim --downgrade_fatal2warning board/' "$BOARD_SH"
    echo "  Added --downgrade_fatal2warning to xsim"
else
    echo "  --downgrade_fatal2warning already present"
fi


# Patch 3: Set the test name in the xsim simulate command
if grep -q 'testplusarg testname=' "$BOARD_SH"; then
    sed -i "s/testplusarg testname=[^ ]*/testplusarg testname=$TESTNAME/" "$BOARD_SH"
    echo "  Set testname=$TESTNAME"
fi

echo ""
echo "=== Running XSim ==="
echo "Working dir: $XSIM_DIR"
echo ""

cd "$XSIM_DIR"

# Use Vivado's bundled ar (compatible with xelab-generated object files)
export PATH="/ecad/tools/xilinx/2025.1/Vivado/tps/lnx64/binutils-2.42/bin:$PATH"

# Fix locale: Vivado's rdiArgs.sh sets LC_ALL=en_US.UTF-8 which may not exist
# in containers. Create a symlink from en_US.UTF-8 -> C.utf8 in a temp LOCPATH.
if ! locale -a 2>/dev/null | grep -q 'en_US.utf8'; then
    mkdir -p /tmp/mylocale
    ln -sf /usr/lib/locale/C.utf8 /tmp/mylocale/en_US.UTF-8 2>/dev/null || true
    export LOCPATH=/tmp/mylocale:/usr/lib/locale
    echo "  Applied locale workaround (en_US.UTF-8 -> C.utf8)"
fi

exec bash board.sh 2>&1
