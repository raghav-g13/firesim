# Fix BUFGCE SIM_DEVICE inside the synthesis subprocess (TCL.POST hook).
# FIRRTL emits BUFGCE with SIM_DEVICE=ULTRASCALE; Versal requires VERSAL_HBM.
# Running this as SYNTH_DESIGN.TCL.POST ensures the fix is applied BEFORE the
# synthesis checkpoint is written to disk, so downstream steps (implementation,
# write_device_image) see the corrected value and ADEF-911 DRC passes cleanly.
foreach cell [get_cells -hierarchical -filter {REF_NAME == BUFGCE} -quiet] {
    set_property SIM_DEVICE VERSAL_HBM $cell
}
