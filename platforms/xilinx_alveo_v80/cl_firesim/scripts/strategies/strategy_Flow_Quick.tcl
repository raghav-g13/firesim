# Flow_Quick: Vivado's fastest implementation strategy for Versal.
# Uses Default opt_design (REQUIRED for Versal - XPHY/memory cores need it),
# Quick directives for place and route, skips phys_opt.

set synth_options "-retiming"
set synth_directive "default"

# opt_design MUST be enabled for Versal (XPHY cores, memory controllers)
set opt 1
set opt_options    ""
set opt_directive  "Default"

set place_options    ""
set place_directive  "Quick"

set phys_opt 0
set phys_options    ""
set phys_directive  "Default"

set route_options    ""
set route_directive  "Quick"

set route_phys_opt 0
set post_phys_options    ""
set post_phys_directive  "Default"
