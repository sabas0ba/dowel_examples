#include "probe.h"

#include "internal.h"

/* private.defines must still apply to the target's own compilation. */
#ifndef PROBE_OS
#error "PROBE_OS is missing: match host.os did not reach the compiler"
#endif

/* A header reachable only through private.includes. */
#ifndef PROBE_INTERNAL_SEEN
#error "internal.h was not found: private.includes did not reach the compiler"
#endif

int probe_opt(void) { return PROBE_OPT; }

int probe_os(void) { return PROBE_OS; }

int probe_trace(void) {
#ifdef PROBE_TRACE
    return 1;
#else
    return 0;
#endif
}
