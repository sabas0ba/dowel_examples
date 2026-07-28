/* Exit status 0 means success. There is no test harness. */
#include "probe.h"

/* This test sits outside probe's private block. Anything declared there
   reaching here would mean the public / private split is broken. */
#ifdef PROBE_OS
#error "PROBE_OS leaked out of private.defines"
#endif
#ifdef PROBE_TRACE
#error "PROBE_TRACE leaked out of private.flags"
#endif

int main(void) {
    if (probe_opt() != PROBE_OPT) return 1;
    if (probe_os() < 1 || probe_os() > 3) return 2;
    return 0;
}
