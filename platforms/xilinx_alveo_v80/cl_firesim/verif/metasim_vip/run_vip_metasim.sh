#!/usr/bin/env bash
# run_vip_metasim.sh — Run VIP-based VCS FPGA-level metasimulation for V80
#
# Uses the full Vivado block design with real Xilinx VIPs:
#   - versal_cips (CPM5 QDMA) with PIPESIM
#   - axi_noc (NoC fabric with NMU/NSU sim models)
#   - SmartConnect (AXI4→AXI-Lite conversion)
#   - clk_wizard (PLL)
#   - proc_sys_reset
#   - xlnoc (NoC fabric BFM for NPS routing)
#   - xilinx_pcie5_versal_rp (Root Port BFM)
#
# Prerequisites:
#   1. Run setup_vip_metasim.tcl in Vivado first to create the project and export VCS scripts
#   2. Compiled Xilinx VCS sim libs at ../vcs_xilinx_lib/ (built with VCS W-2024.09-1)
#
# Usage:
#   bash run_vip_metasim.sh [compile|elaborate|simulate|all] [CL_DIR] [+TESTNAME=...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIF_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIRESIM_DIR="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

CED_SIM="/ecad/tools/xilinx/2025.1/data/xhub/ced/XilinxCEDStore/ced/Xilinx/IPI/Versal_CPM_QDMA_EP_Simulation_Design/cpm5_qdma/sim_files"
VIVADO_PROJ="$SCRIPT_DIR/vivado_proj"
DESIGN_RP_GEN="$VIVADO_PROJ/vip_metasim.gen/sources_1/bd/design_rp"

# ── VCS W-2024.09-1 (matches compiled sim libs) ─────────────────────
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
fi

# /usr/bin/time wrapper
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

export VCS_HOME="$PATCHED_VCS"
export PATH="$VCS_HOME/bin:/tmp/bin_fixes:$PATH"
export VCS_ARCH_OVERRIDE=linux

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
    CL_DIR="$(ls -d "$FIRESIM_DIR"/platforms/xilinx_alveo_v80/cl_xilinx_alveo_v80-*Kodiak* 2>/dev/null | sort | tail -1)"
fi
if [[ -z "$CL_DIR" ]]; then
    CL_DIR="$(ls -d "$FIRESIM_DIR"/platforms/xilinx_alveo_v80/cl_xilinx_alveo_v80-* 2>/dev/null | sort | tail -1)"
fi
if [[ -z "$CL_DIR" || ! -d "$CL_DIR" ]]; then
    echo "ERROR: Could not find cl_xilinx_alveo_v80-* directory."
    exit 1
fi

VCS_EXPORT_DIR="$CL_DIR/vcs_vip"
VCS_SIM_DIR="$VCS_EXPORT_DIR/vcs"
EXPORTED_SH="$VCS_SIM_DIR/overall_fpga_top_sim_wrapper.sh"

if [[ ! -f "$EXPORTED_SH" ]]; then
    echo "ERROR: $EXPORTED_SH not found."
    echo "Run setup_vip_metasim.tcl in Vivado first:"
    echo "  source /ecad/tools/xilinx/2025.1/Vivado/settings64.sh"
    echo "  vivado -mode batch -stack 2000 -source $SCRIPT_DIR/setup_vip_metasim.tcl -tclargs $CL_DIR"
    exit 1
fi

echo "=== V80 VIP-based VCS Metasimulation ==="
echo "CL_DIR     : $CL_DIR"
echo "VCS_DIR    : $VCS_SIM_DIR"
echo "STEP       : $STEP"
echo "VCS_HOME   : $VCS_HOME"
[[ -n "$TESTNAME_ARG" ]] && echo "TESTNAME   : $TESTNAME_VALUE"
echo ""

# ── Patch exported script ────────────────────────────────────────────
fix_sim_lib_paths() {
    echo "=== Fixing pre-compiled sim lib paths ==="
    local lib_dir="$VERIF_DIR/vcs_xilinx_lib"
    local setup="$lib_dir/synopsys_sim.setup"
    if [[ ! -f "$setup" ]]; then
        echo "  WARNING: $setup not found"
        return
    fi

    # Fix any stale /home/ray/ paths
    if grep -q '/home/ray/chipyard' "$setup"; then
        local local_base
        local_base="$(cd "$VERIF_DIR/../.." && pwd)"
        sed -i "s|/home/ray/chipyard/sims/firesim|$local_base|g" "$setup"
        echo "  Fixed /home/ray/ paths"
    fi

    # Fix doubled path segments (compile_simlib bug)
    if grep -q 'platforms/xilinx_alveo_v80/platforms/xilinx_alveo_v80' "$setup"; then
        sed -i 's|platforms/xilinx_alveo_v80/platforms/xilinx_alveo_v80|platforms/xilinx_alveo_v80|g' "$setup"
        echo "  Fixed doubled path segments"
    fi

    # Add entries for all library dirs not yet in the setup file
    local added=0
    for dir in "$lib_dir"/*/; do
        local name
        name=$(basename "$dir")
        if ! grep -q "^${name} " "$setup" && ! grep -q "^${name}	" "$setup"; then
            echo "${name} : ${dir%/}" >> "$setup"
            added=$((added + 1))
        fi
    done
    if [[ $added -gt 0 ]]; then
        echo "  Added $added missing library mappings to synopsys_sim.setup"
    else
        echo "  All library mappings already present"
    fi
    echo ""
}

patch_exported_sh() {
    echo "=== Patching overall_fpga_top_sim_wrapper.sh ==="
    if ! grep -q '+define+SIMULATION=' "$EXPORTED_SH"; then
        sed -i 's/+define+FIRESIM_EP=/+define+FIRESIM_EP= +define+SIMULATION=/g' "$EXPORTED_SH"
        echo "  Added +define+SIMULATION="
    else echo "  +define+SIMULATION= already present"; fi

    if ! grep -q 'Xcheck_p1800_2009=char' "$EXPORTED_SH"; then
        sed -i 's/vlogan_opts="-full64 -l .tmp_log"/vlogan_opts="-full64 -l .tmp_log -Xcheck_p1800_2009=char"/' "$EXPORTED_SH"
        echo "  Added -Xcheck_p1800_2009=char"
    else echo "  -Xcheck_p1800_2009=char already present"; fi

    if ! grep -q 'xlrm uniq_prior_final' "$EXPORTED_SH"; then
        sed -i 's/vcs_elab_opts="-full64 -debug_acc -t ps -licqueue -l elaborate.log"/vcs_elab_opts="-full64 -debug_acc -t ps -licqueue -l elaborate.log +error+999 -xlrm uniq_prior_final"/' "$EXPORTED_SH"
        echo "  Added +error+999 -xlrm uniq_prior_final"
    else echo "  VCS elaborate flags already present"; fi
    echo ""
}

# ── Patch RP to match EP link width/speed ────────────────────────────
patch_rp_link_config() {
    echo "=== Patching RP link config to match EP (x16 Gen3) ==="
    local rp_sv="$DESIGN_RP_GEN/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/sim/bd_e4ca_cpm_0_0.sv"
    local rp_cdo="$DESIGN_RP_GEN/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/bd_e4ca_cpm_0_0_sim.cdo"

    if [[ -f "$rp_sv" ]]; then
        # Patch SV: link width 8→16
        if grep -q 'C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH(8)' "$rp_sv"; then
            sed -i 's/C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH(8)/C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH(16)/g' "$rp_sv"
            sed -i 's/C_CPM_PCIE0_LINK_WIDTH_FOR_POWER(8)/C_CPM_PCIE0_LINK_WIDTH_FOR_POWER(16)/g' "$rp_sv"
            echo "  SV: link width 8 → 16"
        fi
        # Patch SV: link speed GEN4→GEN3
        if grep -q 'C_CPM_PCIE0_LINK_SPEED_FOR_POWER("GEN4")' "$rp_sv"; then
            sed -i 's/C_CPM_PCIE0_LINK_SPEED_FOR_POWER("GEN4")/C_CPM_PCIE0_LINK_SPEED_FOR_POWER("GEN3")/g' "$rp_sv"
            echo "  SV: link speed GEN4 → GEN3"
        fi
    else
        echo "  WARNING: RP SV not found: $rp_sv"
    fi

    # Patch CDO in both source (gen) and exported (vcs_vip/vcs/) locations
    local rp_cdo_exported="$VCS_SIM_DIR/bd_e4ca_cpm_0_0_sim.cdo"
    for cdo_file in "$rp_cdo" "$rp_cdo_exported"; do
        if [[ -f "$cdo_file" ]]; then
            if grep -q 'fce080e0' "$cdo_file"; then
                python3 -c "
with open('$cdo_file', 'r') as f:
    lines = f.readlines()
patched = 0
for i, line in enumerate(lines):
    s = line.strip()
    if s == 'fce080e0' and i+1 < len(lines):
        old = lines[i+1].strip()
        if old == '00000008':
            lines[i+1] = '00000010\n'
            patched += 1
    elif s == 'fce080e4' and i+1 < len(lines):
        old = lines[i+1].strip()
        if old == '00000008':
            lines[i+1] = '00000004\n'
            patched += 1
with open('$cdo_file', 'w') as f:
    f.writelines(lines)
print(f'  CDO [{\"exported\" if \"vcs_vip\" in \"$cdo_file\" else \"source\"}]: patched {patched} registers')
"
            else
                echo "  CDO: $cdo_file — already patched or different format"
            fi
        else
            echo "  CDO: $cdo_file — not found (skipping)"
        fi
    done
    echo ""
}

# ── Common vlogan options for extra compile steps ────────────────────
VLOGAN_SV_OPTS="-full64 -l .tmp_log -Xcheck_p1800_2009=char -sverilog +define+SIMULATION= +define+FIRESIM_EP="
VLOGAN_V2K_OPTS="-full64 -l .tmp_log -Xcheck_p1800_2009=char +v2k +define+SIMULATION= +define+FIRESIM_EP="

# Common include dirs (covers design_1, design_rp, CED, xlnoc, FireSim)
COMMON_INCDIRS=(
    "+incdir+$VERIF_DIR"
    "+incdir+$CED_SIM"
    "+incdir+$CL_DIR/design"
    "+incdir+$DESIGN_RP_GEN/ipshared/f0b6/hdl/verilog"
    "+incdir+$DESIGN_RP_GEN/ipshared/a8e4/hdl/verilog"
    "+incdir+$DESIGN_RP_GEN/ipshared/ec67/hdl"
    "+incdir+$DESIGN_RP_GEN/ipshared/ca60/hdl"
    "+incdir+$DESIGN_RP_GEN/ipshared/a5a9/ttcl"
    "+incdir+$DESIGN_RP_GEN/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_0"
    "+incdir+$DESIGN_RP_GEN/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_1"
    "+incdir+$DESIGN_RP_GEN/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_2"
    "+incdir+$DESIGN_RP_GEN/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_3"
    "+incdir+$DESIGN_RP_GEN/ipshared/35e5/hdl/verilog"
    "+incdir+$DESIGN_RP_GEN/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/hdl"
    "+incdir+$DESIGN_RP_GEN/ipshared/4eed/hdl/verilog"
    "+incdir+$VIVADO_PROJ/vip_metasim.gen/sim_1/bd/xlnoc/ipshared/7c30/hdl/bfm"
    "+incdir+/ecad/tools/xilinx/2025.1/Vivado/data/xilinx_vip/include"
    "+incdir+$SCRIPT_DIR"
)

vlogan_sv() {
    vlogan -work xil_defaultlib "$CL_DIR/design/FireSim-generated.defines.vh" \
        $VLOGAN_SV_OPTS "${COMMON_INCDIRS[@]}" "$@" 2>&1 | tee -a compile.log
}

vlogan_v2k() {
    vlogan -work xil_defaultlib "$CL_DIR/design/FireSim-generated.defines.vh" \
        $VLOGAN_V2K_OPTS "${COMMON_INCDIRS[@]}" "$@" 2>&1 | tee -a compile.log
}

# ── Compile design_rp (Root Port BD) IP sources ─────────────────────
compile_design_rp() {
    echo "=== Compiling design_rp (Root Port) IP sources ==="
    local RP="$DESIGN_RP_GEN"

    # RP PS9 VIP
    vlogan_sv "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_0/ip_0/sim/versal_cips_ps_vip_0.sv"
    # RP PSPMC sim model
    vlogan_v2k "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_0/hdl/pspmc_v1_4_6_sim.v" \
               "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_0/sim/bd_e4ca_pspmc_0_0.v"

    # RP GT Quad 0 functions + sim wrapper
    vlogan_v2k "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_0/bd_e4ca_cpm_0_0_gt_quad_0_inst.v" \
               "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_0/bd_e4ca_cpm_0_0_gt_quad_0_rx_function.v" \
               "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_0/bd_e4ca_cpm_0_0_gt_quad_0_tx_function.v" \
               "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_0/sim/bd_e4ca_cpm_0_0_gt_quad_0.v"

    # RP GT Quad 1 functions + sim wrapper
    vlogan_v2k "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_1/bd_e4ca_cpm_0_0_gt_quad_1_inst.v" \
               "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_1/bd_e4ca_cpm_0_0_gt_quad_1_rx_function.v" \
               "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_1/bd_e4ca_cpm_0_0_gt_quad_1_tx_function.v" \
               "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_1/sim/bd_e4ca_cpm_0_0_gt_quad_1.v"

    # RP GT Quad 2 functions + sim wrapper (x16 only)
    if [[ -d "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_2" ]]; then
        vlogan_v2k "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_2/bd_e4ca_cpm_0_0_gt_quad_2_inst.v" \
                   "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_2/bd_e4ca_cpm_0_0_gt_quad_2_rx_function.v" \
                   "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_2/bd_e4ca_cpm_0_0_gt_quad_2_tx_function.v" \
                   "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_2/sim/bd_e4ca_cpm_0_0_gt_quad_2.v"
    fi

    # RP GT Quad 3 functions + sim wrapper (x16 only)
    if [[ -d "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_3" ]]; then
        vlogan_v2k "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_3/bd_e4ca_cpm_0_0_gt_quad_3_inst.v" \
                   "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_3/bd_e4ca_cpm_0_0_gt_quad_3_rx_function.v" \
                   "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_3/bd_e4ca_cpm_0_0_gt_quad_3_tx_function.v" \
                   "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/ip_3/sim/bd_e4ca_cpm_0_0_gt_quad_3.v"
    fi

    # RP CPM5 DPLL + core_top + CPM wrapper
    vlogan_sv "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/hdl/cpm5_v1_0_18_dpll_fd_cal.sv" \
              "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/hdl/cpm5_v1_0_18_dpll_edr_fd_cal.sv" \
              "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/hdl/verilog/cfg_mgmt_dualread.sv" \
              "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/hdl/verilog/pcie_wrapper.sv" \
              "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/sim/verilog/bd_e4ca_cpm_0_0_core_top.sv" \
              "$RP/ip/design_rp_versal_cips_0_0/bd_0/ip/ip_1/sim/bd_e4ca_cpm_0_0.sv"

    # RP versal_cips BD + wrapper
    vlogan_v2k "$RP/ip/design_rp_versal_cips_0_0/bd_0/sim/bd_e4ca.v"
    vlogan_sv  "$RP/ip/design_rp_versal_cips_0_0/sim/design_rp_versal_cips_0_0.sv"

    # RP BD + wrapper
    vlogan_v2k "$RP/sim/design_rp.v" \
               "$RP/hdl/design_rp_wrapper.v"

    echo "  design_rp compilation complete"
    echo ""
}

# ── Compile CED simulation infrastructure ────────────────────────────
compile_ced_sim() {
    echo "=== Compiling CED simulation infrastructure ==="

    vlogan_v2k "$CED_SIM/sys_clk_gen.v" \
               "$CED_SIM/sys_clk_gen_ds.v" \
               "$CED_SIM/pcie_4_0_rp.v" \
               "$CED_SIM/xp4_usp_smsw_model_core_top.v"

    vlogan_sv "$CED_SIM/xilinx_pcie5_versal_rp.sv"

    vlogan_v2k "$CED_SIM/usp_pci_exp_usrapp_com.v" \
               "$CED_SIM/usp_pci_exp_usrapp_cfg.v" \
               "$CED_SIM/usp_pci_exp_usrapp_rx.v" \
               "$VERIF_DIR/usp_pci_exp_usrapp_tx.v"

    vlogan_sv "$CED_SIM/usp_pci_exp_usrapp_tx_sriov.sv"

    echo "  CED sim infrastructure compilation complete"
    echo ""
}

# ── Compile testbench ────────────────────────────────────────────────
compile_testbench() {
    echo "=== Compiling VIP testbench ==="
    vlogan_v2k "+incdir+$VERIF_DIR" "+incdir+$CED_SIM" "+incdir+$CL_DIR/design" "+incdir+$SCRIPT_DIR" \
        "$SCRIPT_DIR/board_vip.v"
    echo "  board_vip.v compilation complete"
    echo ""
}

# ── Update simulate.do ───────────────────────────────────────────────
update_simulate_do() {
    local do_file="$VCS_SIM_DIR/simulate.do"
    printf 'run 20ms\nquit\n' > "$do_file"
    echo "  simulate.do: run 20ms; quit"
}

# ── Run steps ────────────────────────────────────────────────────────
cd "$VCS_SIM_DIR"

patch_ep_link_to_x8() {
    echo "=== Patching EP to x8 (match RP native width) ==="
    local ep_sv
    ep_sv=$(find "$DESIGN_RP_GEN/../design_1" -path "*/ip_1/sim/bd_*_cpm_0_0.sv" 2>/dev/null | head -1)
    if [[ -n "$ep_sv" && -f "$ep_sv" ]]; then
        if grep -q 'C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH(16)' "$ep_sv"; then
            sed -i 's/C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH(16)/C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH(8)/g' "$ep_sv"
            sed -i 's/C_CPM_PCIE0_LINK_WIDTH_FOR_POWER(16)/C_CPM_PCIE0_LINK_WIDTH_FOR_POWER(8)/g' "$ep_sv"
            echo "  EP SV: link width 16 → 8"
        else
            echo "  EP SV: already x8"
        fi
    fi
    local ep_cdo="$VCS_SIM_DIR/bd_70da_cpm_0_0_sim.cdo"
    if [[ -f "$ep_cdo" ]]; then
        python3 -c "
with open('$ep_cdo', 'r') as f:
    lines = f.readlines()
patched = 0
for i, line in enumerate(lines):
    s = line.strip()
    if s == 'fce080e0' and i+1 < len(lines):
        old = lines[i+1].strip()
        if old == '00000010':
            lines[i+1] = '00000008\n'
            patched += 1
with open('$ep_cdo', 'w') as f:
    f.writelines(lines)
print(f'  EP CDO: patched {patched} width register(s)')
"
    fi
    echo ""
}

do_compile() {
    echo "=== Step 1: EP compile (Vivado-exported) ==="
    fix_sim_lib_paths
    patch_exported_sh
    # EP link patching disabled — RP was reconfigured to x8 Gen3 via Vivado
    # patch_ep_link_to_x8
    bash overall_fpga_top_sim_wrapper.sh -step compile 2>&1 | tee ep_compile.log
    echo ""

    echo "=== Step 2: RP + CED + testbench compile ==="
    compile_design_rp
    compile_ced_sim
    compile_testbench
    echo "=== Compile complete ==="
    echo ""
}

do_elaborate() {
    echo "=== Elaborate (top=board) ==="
    local elab_opts="-full64 -debug_acc -t ps -licqueue -l elaborate.log +error+999 -xlrm uniq_prior_final"
    vcs $elab_opts xil_defaultlib.board xil_defaultlib.glbl -o board_simv 2>&1 | tee elaborate_full.log
    local rc=${PIPESTATUS[0]}
    if [[ -f "board_simv" ]]; then
        echo "SUCCESS: board_simv binary produced"
        ls -la board_simv
    else
        echo "ERROR: board_simv not produced"
    fi
    echo ""
    return $rc
}

do_simulate() {
    echo "=== Simulate ==="
    update_simulate_do

    if [[ ! -f "board_simv" ]]; then
        echo "ERROR: board_simv not found. Run compile+elaborate first."
        exit 1
    fi

    if [[ -n "$TESTNAME_ARG" ]]; then
        echo "Running: ./board_simv -ucli -licqueue -l simulate.log -do simulate.do $TESTNAME_ARG"
        ./board_simv -ucli -licqueue -l simulate.log -do simulate.do "$TESTNAME_ARG" 2>&1 | tee simulate_full.log
    else
        echo "Running: ./board_simv -ucli -licqueue -l simulate.log -do simulate.do"
        ./board_simv -ucli -licqueue -l simulate.log -do simulate.do 2>&1 | tee simulate_full.log
    fi
    local RC=${PIPESTATUS[0]}

    local logfile="simulate.log"
    [[ ! -f "$logfile" ]] && logfile="simulate_full.log"
    if [[ -f "$logfile" ]]; then
        echo ""
        echo "=== Simulation Summary ==="
        grep -q "CDO programming done" "$logfile" 2>/dev/null && echo "  CDO programming completed"
        grep -qi 'user_lnk_up.*=.*1' "$logfile" 2>/dev/null && echo "  PCIe link-up achieved"
        grep -q 'PASSED' "$logfile" 2>/dev/null && echo "  Test PASSED"
        grep -q 'ERROR.*FAILED\|TEST FAILED' "$logfile" 2>/dev/null && echo "  Test FAILED"
        grep -q '\$finish' "$logfile" 2>/dev/null && echo "  Simulation reached \$finish"
    fi
    return $RC
}

case "$STEP" in
    compile)   do_compile ;;
    elaborate) do_elaborate ;;
    simulate)  do_simulate; exit $? ;;
    all)
        do_compile
        do_elaborate
        do_simulate
        exit $?
        ;;
esac
