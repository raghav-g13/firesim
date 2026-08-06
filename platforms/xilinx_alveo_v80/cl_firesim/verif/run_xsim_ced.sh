#!/usr/bin/env bash
# run_xsim_ced.sh — Run exported XSim for CED-based simulations
#
# Usage:
#   bash run_xsim_ced.sh <ced_stock|ced_pcie0>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VARIANT="${1:?Usage: run_xsim_ced.sh <ced_stock|ced_pcie0>}"
XSIM_DIR="$SCRIPT_DIR/$VARIANT/xsim/xsim"
BOARD_SH="$XSIM_DIR/board.sh"

if [[ ! -f "$BOARD_SH" ]]; then
    echo "ERROR: $BOARD_SH not found. Run setup_xsim_ced_${VARIANT#ced_}.tcl first."
    exit 1
fi

echo "=== Patching board.sh ($VARIANT) ==="

# Add --downgrade_fatal2warning to xsim command if not present
if ! grep -q 'downgrade_fatal2warning' "$BOARD_SH"; then
    sed -i 's/xsim board/xsim --downgrade_fatal2warning board/' "$BOARD_SH"
    echo "  Added --downgrade_fatal2warning to xsim"
else
    echo "  --downgrade_fatal2warning already present"
fi

echo ""
echo "=== Running XSim ($VARIANT) ==="
echo "Working dir: $XSIM_DIR"
echo ""

cd "$XSIM_DIR"

# Use Vivado's bundled ar
export PATH="/ecad/tools/xilinx/2025.1/Vivado/tps/lnx64/binutils-2.42/bin:$PATH"

exec bash board.sh 2>&1
