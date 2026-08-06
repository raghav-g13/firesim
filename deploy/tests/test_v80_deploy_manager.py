#!/usr/bin/env python3
"""Dry-run verification tests for XilinxAlveoV80InstanceDeployManager.

Validates:
  (A) Import and instantiation — class is importable, expected methods exist
      with correct signatures.
  (B) QDMA BDF encoding — _compute_qdma_bdf() returns correct values for
      known inputs and produces correct hex formatting.
  (C) Command sequence audit — shell commands in load_qdma(), unload_qdma(),
      and flash_fpgas() follow the required ordering and conventions.
  (D) C++ driver / deploy manager cross-check — consistency between
      simif_xilinx_alveo_v80.cc and the deploy manager Python code.
"""

import inspect
import os
import re
import sys
import textwrap

# ──────────────────────────────────────────────────────────────────────
# Ensure the deploy directory is on sys.path so we can import the module
# ──────────────────────────────────────────────────────────────────────
DEPLOY_DIR = os.path.join(os.environ.get("FIRESIM", "/home/ray/chipyard/sims/firesim"), "deploy")
if DEPLOY_DIR not in sys.path:
    sys.path.insert(0, DEPLOY_DIR)

# ──────────────────────────────────────────────────────────────────────
# Test bookkeeping
# ──────────────────────────────────────────────────────────────────────
_results = []  # list of (category, name, pass_bool, detail_str)

def _record(category, name, passed, detail=""):
    status = "PASS" if passed else "FAIL"
    _results.append((category, name, passed, detail))
    print(f"  [{status}] {category} :: {name}" + (f"  -- {detail}" if detail else ""))

def _assert(category, name, condition, detail=""):
    _record(category, name, bool(condition), detail)

# ======================================================================
# (A) Import and instantiation test
# ======================================================================
print("=" * 70)
print("(A) Import and instantiation test")
print("=" * 70)

try:
    from runtools.run_farm_deploy_managers import XilinxAlveoV80InstanceDeployManager
    _assert("A", "import_class", True, "Class imported successfully")
except Exception as e:
    _assert("A", "import_class", False, f"Import failed: {e}")
    # Can't continue without the class
    print("\nFATAL: Cannot continue without the class import.\n")
    sys.exit(1)

# Check that the class is a proper class
_assert("A", "is_class", inspect.isclass(XilinxAlveoV80InstanceDeployManager))

# Expected V80-specific methods with their signatures
EXPECTED_METHODS = {
    "__init__":             "(self, parent_node: 'Inst') -> 'None'",
    "_compute_qdma_bdf":   "(self, bdf_str: 'str') -> 'int'",
    "load_qdma":           "(self) -> 'None'",
    "unload_qdma":         "(self) -> 'None'",
    "flash_fpgas":         "(self) -> 'None'",
    "infrasetup_instance": "(self, uridir: 'str') -> 'None'",
    "enumerate_fpgas":     "(self, uridir: 'str') -> 'None'",
    "start_sim_slot":      "(self, slotno: 'int') -> 'None'",
    "create_fpga_database":"(self, uridir: 'str') -> 'None'",
}

for mname, expected_sig_str in EXPECTED_METHODS.items():
    has_method = hasattr(XilinxAlveoV80InstanceDeployManager, mname)
    _assert("A", f"has_method_{mname}", has_method,
            f"{'found' if has_method else 'MISSING'}")
    if has_method:
        method = getattr(XilinxAlveoV80InstanceDeployManager, mname)
        sig = str(inspect.signature(method))
        _assert("A", f"sig_{mname}", sig == expected_sig_str,
                f"got {sig!r}, expected {expected_sig_str!r}")

# Verify the class is defined in the V80 class dict (not just inherited)
V80_OWN_METHODS = [
    "_compute_qdma_bdf", "load_qdma", "unload_qdma", "flash_fpgas",
    "infrasetup_instance", "enumerate_fpgas", "start_sim_slot",
    "create_fpga_database",
]
for mname in V80_OWN_METHODS:
    is_own = mname in XilinxAlveoV80InstanceDeployManager.__dict__
    _assert("A", f"own_method_{mname}", is_own,
            "defined on V80 class" if is_own else "INHERITED only (not overridden)")

# Check PLATFORM_NAME attribute default (from __init__)
src = inspect.getsource(XilinxAlveoV80InstanceDeployManager.__init__)
_assert("A", "platform_name_set",
        "xilinx_alveo_v80" in src,
        "PLATFORM_NAME = 'xilinx_alveo_v80' found in __init__")

# ======================================================================
# (B) QDMA BDF encoding unit test
# ======================================================================
print()
print("=" * 70)
print("(B) QDMA BDF encoding unit test")
print("=" * 70)

# We can call _compute_qdma_bdf as an unbound method (pass a dummy self)
class _DummySelf:
    pass

compute_bdf = XilinxAlveoV80InstanceDeployManager._compute_qdma_bdf

TEST_BDFS = [
    # (bdf_str, expected_int, expected_hex_5digit)
    ("b1:00.0", (0xb1 << 12) | (0x00 << 4) | 0x0, "b1000"),
    ("3b:00.0", (0x3b << 12) | (0x00 << 4) | 0x0, "3b000"),
    ("86:00.1", (0x86 << 12) | (0x00 << 4) | 0x1, "86001"),
    # Additional edge cases
    ("00:00.0", 0x00000, "00000"),
    ("ff:1f.7", (0xff << 12) | (0x1f << 4) | 0x7, "ff1f7"),
]

for bdf_str, expected_int, expected_hex in TEST_BDFS:
    dummy = _DummySelf()
    result = compute_bdf(dummy, bdf_str)

    _assert("B", f"bdf_{bdf_str}_value",
            result == expected_int,
            f"got {result} (0x{result:x}), expected {expected_int} (0x{expected_int:x})")

    hex_str = f"{result:05x}"
    _assert("B", f"bdf_{bdf_str}_hex",
            hex_str == expected_hex,
            f"got {hex_str!r}, expected {expected_hex!r}")

# Verify specific numeric values mentioned in the spec
_assert("B", "b1_is_724992", compute_bdf(_DummySelf(), "b1:00.0") == 724992,
        f"0xb1000 = {0xb1000}")
_assert("B", "3b_is_241664", compute_bdf(_DummySelf(), "3b:00.0") == 241664,
        f"0x3b000 = {0x3b000}")
_assert("B", "86_is_0x86001", compute_bdf(_DummySelf(), "86:00.1") == 0x86001,
        f"0x86001 = {0x86001}")

# ======================================================================
# (C) Command sequence audit
# ======================================================================
print()
print("=" * 70)
print("(C) Command sequence audit")
print("=" * 70)

# Read the source code of load_qdma, unload_qdma, flash_fpgas
load_qdma_src = inspect.getsource(XilinxAlveoV80InstanceDeployManager.load_qdma)
unload_qdma_src = inspect.getsource(XilinxAlveoV80InstanceDeployManager.unload_qdma)
flash_fpgas_src = inspect.getsource(XilinxAlveoV80InstanceDeployManager.flash_fpgas)

# (C1) load_qdma: qmax BEFORE adding queues
# Find positions of qmax and q add in source
qmax_pos = load_qdma_src.find("qmax")
q_add_pos = load_qdma_src.find("q add")
q_start_pos = load_qdma_src.find("q start")

_assert("C", "load_qmax_before_q_add",
        0 <= qmax_pos < q_add_pos,
        f"qmax at char {qmax_pos}, q add at char {q_add_pos}")

_assert("C", "load_q_add_before_q_start",
        0 <= q_add_pos < q_start_pos,
        f"q add at char {q_add_pos}, q start at char {q_start_pos}")

# (C2) load_qdma: mode mm dir bi (not mode st)
_assert("C", "load_uses_mode_mm",
        "mode mm" in load_qdma_src,
        "Found 'mode mm' in load_qdma")
_assert("C", "load_not_mode_st",
        "mode st" not in load_qdma_src,
        "'mode st' correctly absent from load_qdma")
_assert("C", "load_uses_dir_bi",
        "dir bi" in load_qdma_src,
        "Found 'dir bi' in load_qdma")

# (C3) flash_fpgas: PCIe rescan AFTER programming (not before)
# Find programming step (vivado batch) and rescan step
vivado_pos = flash_fpgas_src.find("-mode batch")
# Could also be vivado_lab
if vivado_pos < 0:
    vivado_pos = flash_fpgas_src.find("program_fpga")
rescan_pos = flash_fpgas_src.find("/sys/bus/pci/rescan")

_assert("C", "flash_rescan_after_program",
        0 <= vivado_pos < rescan_pos,
        f"vivado/program at char {vivado_pos}, rescan at char {rescan_pos}")

# Also check that disconnect is before programming
disconnect_pos = flash_fpgas_src.find("disconnect")
if disconnect_pos >= 0:
    _assert("C", "flash_disconnect_before_program",
            0 <= disconnect_pos < vivado_pos,
            f"disconnect at char {disconnect_pos}, program at char {vivado_pos}")

# (C4) unload_qdma: stop queues BEFORE deleting them
q_stop_pos = unload_qdma_src.find("q stop")
q_del_pos = unload_qdma_src.find("q del")

_assert("C", "unload_stop_before_delete",
        0 <= q_stop_pos < q_del_pos,
        f"q stop at char {q_stop_pos}, q del at char {q_del_pos}")

# Also check modprobe -r comes after queue teardown
modprobe_r_pos = unload_qdma_src.find("modprobe -r")
_assert("C", "unload_modprobe_r_after_queue_teardown",
        0 <= q_del_pos < modprobe_r_pos,
        f"q del at char {q_del_pos}, modprobe -r at char {modprobe_r_pos}")

# (C5) modprobe uses 'qdma-pf' (hyphen)
_assert("C", "load_modprobe_qdma_pf_hyphen",
        "modprobe qdma-pf" in load_qdma_src,
        "load_qdma uses 'modprobe qdma-pf' (hyphen)")
_assert("C", "unload_modprobe_r_qdma_pf_hyphen",
        "modprobe -r qdma-pf" in unload_qdma_src,
        "unload_qdma uses 'modprobe -r qdma-pf' (hyphen)")

# Check that qdma_pf (underscore) is only used in lsmod check (kernel module internal name)
# and NOT in modprobe commands
load_lines = load_qdma_src.split('\n')
for i, line in enumerate(load_lines):
    if 'modprobe' in line and 'qdma_pf' in line:
        _assert("C", "load_no_underscore_in_modprobe", False,
                f"Line {i}: {line.strip()} uses underscore in modprobe")
        break
else:
    _assert("C", "load_no_underscore_in_modprobe", True,
            "No 'qdma_pf' underscore in modprobe commands (correct)")

# Verify lsmod grep uses qdma_pf (the internal name, correct for lsmod)
_assert("C", "load_lsmod_uses_internal_name",
        "grep" in load_qdma_src and "qdma_pf" in load_qdma_src,
        "lsmod check correctly uses kernel internal name 'qdma_pf'")

# ======================================================================
# (D) C++ driver / deploy manager cross-check
# ======================================================================
print()
print("=" * 70)
print("(D) C++ driver / deploy manager cross-check")
print("=" * 70)

# Read the C++ driver source
CPP_DRIVER = os.path.join(
    os.environ.get("FIRESIM", "/home/ray/chipyard/sims/firesim"),
    "sim/midas/src/main/cc/simif_xilinx_alveo_v80.cc"
)

if not os.path.isfile(CPP_DRIVER):
    _assert("D", "cpp_driver_exists", False, f"File not found: {CPP_DRIVER}")
else:
    with open(CPP_DRIVER, 'r') as f:
        cpp_src = f.read()

    _assert("D", "cpp_driver_exists", True, f"Found: {CPP_DRIVER}")

    # ── (D1) BDF encoding consistency ──
    # C++ uses: (bus << 12) | (device << 4) | function
    # Look for the encoding in the C++ source
    bdf_pattern = re.search(
        r'bus_id\s*<<\s*12.*device_id\s*<<\s*4.*pf_id',
        cpp_src, re.DOTALL
    )
    _assert("D", "cpp_bdf_encoding_found",
            bdf_pattern is not None,
            f"Found BDF encoding pattern: {bdf_pattern.group(0)[:80] if bdf_pattern else 'NOT FOUND'}")

    # Verify the exact formula components
    has_bus_shift_12 = "bus_id << 12" in cpp_src or "bus_id<<12" in cpp_src
    has_dev_shift_4 = "device_id << 4" in cpp_src or "device_id<<4" in cpp_src
    has_pf_or = "pf_id" in cpp_src

    _assert("D", "cpp_bus_shift_12", has_bus_shift_12,
            "C++ uses bus_id << 12")
    _assert("D", "cpp_device_shift_4", has_dev_shift_4,
            "C++ uses device_id << 4")
    _assert("D", "cpp_pf_id_present", has_pf_or,
            "C++ uses pf_id (function)")

    # Python uses: (bus << 12) | (device << 4) | function
    py_bdf_src = inspect.getsource(XilinxAlveoV80InstanceDeployManager._compute_qdma_bdf)
    py_has_bus_12 = "bus << 12" in py_bdf_src or "bus<<12" in py_bdf_src
    py_has_dev_4 = "device << 4" in py_bdf_src or "device<<4" in py_bdf_src

    _assert("D", "py_bus_shift_12", py_has_bus_12,
            "Python uses bus << 12")
    _assert("D", "py_device_shift_4", py_has_dev_4,
            "Python uses device << 4")

    # Cross-check: both use the same formula
    _assert("D", "bdf_encoding_matches",
            has_bus_shift_12 and has_dev_shift_4 and py_has_bus_12 and py_has_dev_4,
            "BDF encoding formula matches between C++ and Python")

    # ── (D2) BAR index consistency ──
    # C++ default BAR ID is 1 (bar_id = 1 in defaults)
    cpp_bar_default = re.search(r'bar_id\s*=\s*1', cpp_src)
    _assert("D", "cpp_default_bar_1", cpp_bar_default is not None,
            "C++ defaults to BAR ID 1")

    # Python start_sim_slot passes +bar=0x1
    start_sim_src = inspect.getsource(XilinxAlveoV80InstanceDeployManager.start_sim_slot)
    py_bar_1 = "+bar=0x1" in start_sim_src
    _assert("D", "py_start_sim_bar_1", py_bar_1,
            "Python start_sim_slot passes +bar=0x1")

    _assert("D", "bar_index_matches",
            (cpp_bar_default is not None) and py_bar_1,
            "BAR index = 1 in both C++ driver and deploy manager")

    # ── (D3) BAR size consistency ──
    # C++ bar1_size = 0x2000000 = 32 MB
    bar_size_match = re.search(r'bar1_size\s*=\s*(0x[0-9a-fA-F]+)', cpp_src)
    if bar_size_match:
        bar_size_hex = bar_size_match.group(1)
        bar_size_int = int(bar_size_hex, 16)
        _assert("D", "cpp_bar_size_32mb",
                bar_size_int == 0x2000000,
                f"C++ BAR1 size = {bar_size_hex} = {bar_size_int} bytes = {bar_size_int // (1024*1024)} MB")
        # 2^25 = 33554432 = 0x2000000 = 32 MB, consistent with CtrlNastiKey addrBits=25
        _assert("D", "bar_size_matches_addrbits_25",
                bar_size_int == 2**25,
                f"BAR1 size {bar_size_int} == 2^25 = {2**25} (CtrlNastiKey addrBits=25)")
    else:
        _assert("D", "cpp_bar_size_32mb", False, "Could not find bar1_size in C++ source")

    # ── (D4) DMA device file pattern consistency ──
    # C++ opens /dev/qdma%05x-MM-0
    cpp_dev_pattern = re.search(r'/dev/qdma%05x-MM-0', cpp_src)
    _assert("D", "cpp_qdma_dev_pattern",
            cpp_dev_pattern is not None,
            "C++ uses /dev/qdma%05x-MM-0 device pattern")

    # Python load_qdma creates queue with: mode mm, idx 0, dir bi
    # This means the device file will be /dev/qdmaXXXXX-MM-0
    py_mm_mode = "mode mm" in load_qdma_src
    py_idx_0 = "idx 0" in load_qdma_src
    py_dir_bi = "dir bi" in load_qdma_src

    _assert("D", "py_qdma_queue_mm_mode", py_mm_mode,
            "Python creates MM (memory-mapped) queue")
    _assert("D", "py_qdma_queue_idx_0", py_idx_0,
            "Python uses queue idx 0")
    _assert("D", "py_qdma_queue_dir_bi", py_dir_bi,
            "Python uses bidirectional queue")

    # The combination of mode mm + idx 0 produces /dev/qdmaXXXXX-MM-0
    # MM = memory-mapped (not ST = streaming), 0 = queue index
    _assert("D", "device_pattern_matches",
            py_mm_mode and py_idx_0 and (cpp_dev_pattern is not None),
            "Device file pattern consistent: C++ /dev/qdmaXXXXX-MM-0 matches Python queue setup (mode mm, idx 0)")

    # ── (D5) PCI vendor/device ID consistency ──
    # C++ defaults: vendor 0x10ee, device 0x903f
    cpp_vendor_match = re.search(r'pci_vendor_id\s*=\s*(0x[0-9a-fA-F]+)', cpp_src)
    cpp_device_match = re.search(r'pci_device_id\s*=\s*(0x[0-9a-fA-F]+)', cpp_src)

    cpp_vendor = cpp_vendor_match.group(1) if cpp_vendor_match else None
    cpp_device = cpp_device_match.group(1) if cpp_device_match else None

    _assert("D", "cpp_vendor_id_10ee",
            cpp_vendor == "0x10ee",
            f"C++ PCI vendor ID = {cpp_vendor}")
    _assert("D", "cpp_device_id_903f",
            cpp_device == "0x903f",
            f"C++ PCI device ID = {cpp_device}")

    # Python start_sim_slot passes +pci-vendor=0x10ee +pci-device=0x903f
    py_vendor = "+pci-vendor=0x10ee" in start_sim_src
    py_device = "+pci-device=0x903f" in start_sim_src

    _assert("D", "py_vendor_id_10ee", py_vendor,
            "Python passes +pci-vendor=0x10ee")
    _assert("D", "py_device_id_903f", py_device,
            "Python passes +pci-device=0x903f")

    _assert("D", "pci_ids_match",
            (cpp_vendor == "0x10ee") and (cpp_device == "0x903f") and py_vendor and py_device,
            "PCI IDs match: vendor=0x10ee, device=0x903f in both C++ and Python")

# ======================================================================
# Summary
# ======================================================================
print()
print("=" * 70)
print("SUMMARY")
print("=" * 70)

total = len(_results)
passed = sum(1 for _, _, p, _ in _results if p)
failed = sum(1 for _, _, p, _ in _results if not p)

categories = {}
for cat, name, p, detail in _results:
    if cat not in categories:
        categories[cat] = {"pass": 0, "fail": 0}
    if p:
        categories[cat]["pass"] += 1
    else:
        categories[cat]["fail"] += 1

for cat in sorted(categories):
    c = categories[cat]
    status = "PASS" if c["fail"] == 0 else "FAIL"
    cat_labels = {
        "A": "(A) Import & instantiation",
        "B": "(B) QDMA BDF encoding",
        "C": "(C) Command sequence audit",
        "D": "(D) C++ driver cross-check",
    }
    label = cat_labels.get(cat, cat)
    print(f"  [{status}] {label}: {c['pass']}/{c['pass']+c['fail']} passed")

print()
if failed > 0:
    print(f"FAILED: {failed}/{total} tests failed")
    # Print failed tests
    print("\nFailed tests:")
    for cat, name, p, detail in _results:
        if not p:
            print(f"  {cat} :: {name}: {detail}")
    sys.exit(1)
else:
    print(f"ALL PASSED: {passed}/{total} tests passed")
    sys.exit(0)
