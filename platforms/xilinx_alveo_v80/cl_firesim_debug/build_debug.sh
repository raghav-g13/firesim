#!/bin/bash
# build_debug.sh
#
# Build the V80 BRAM-loopback debug design.
# Run from the cl_firesim_debug/ directory.
#
# Usage:
#   cd platforms/xilinx_alveo_v80/cl_firesim_debug
#   ./build_debug.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo " V80 Debug BRAM Loopback Build"
echo " Working directory: $(pwd)"
echo "========================================"

# Check Vivado is available
if ! command -v vivado &>/dev/null; then
    echo "ERROR: vivado not found on PATH."
    echo "       Source your Vivado settings64.sh first, e.g.:"
    echo "         source /tools/Xilinx/Vivado/2025.1/settings64.sh"
    exit 1
fi

VIVADO_VER=$(vivado -version 2>/dev/null | head -1)
echo "Using: $VIVADO_VER"
echo ""

# Clean previous build
rm -rf vivado_proj

# Create log directory (Vivado needs it before the project is created)
mkdir -p vivado_proj

# Run Vivado in batch mode
echo "Launching Vivado batch build..."
vivado -mode batch -source scripts/main_debug.tcl -log vivado_proj/build.log -journal vivado_proj/build.jou 2>&1 | tee vivado_proj/build_console.log

# Check output
PDI_PATH="vivado_proj/firesim_debug.pdi"
if [ -f "$PDI_PATH" ]; then
    echo ""
    echo "========================================"
    echo " BUILD SUCCEEDED"
    echo " PDI: $(realpath $PDI_PATH)"
    echo "========================================"
else
    echo ""
    echo "========================================"
    echo " BUILD FAILED"
    echo " Check logs in vivado_proj/"
    echo "========================================"
    exit 1
fi
