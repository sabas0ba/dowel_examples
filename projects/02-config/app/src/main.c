#include <stdio.h>

#include "probe.h"

/* This package's own match arms must reach the compiler. */
#ifndef APP_OPT
#error "APP_OPT is missing: match cfg.opt did not reach the compiler"
#endif
#ifndef APP_ARCH
#error "APP_ARCH is missing: match host.arch did not reach the compiler"
#endif

/* Nothing from probe's private block may reach a dependent. */
#ifdef PROBE_OS
#error "PROBE_OS leaked from probe's private block into a dependent"
#endif
#ifdef PROBE_TRACE
#error "PROBE_TRACE leaked from probe's private flags into a dependent"
#endif

/* Public defines arrive here and vary with the configuration. The constant
   this translation unit saw must agree with the library that was linked. */
int main(void) {
    if (probe_opt() != PROBE_OPT) {
        fprintf(stderr, "probe was built with opt=%d but APP sees %d\n", probe_opt(), PROBE_OPT);
        return 1;
    }
    printf("app_opt=%d probe_opt=%d arch=%d os=%d trace=%d\n", APP_OPT, PROBE_OPT, APP_ARCH,
           probe_os(), probe_trace());
    return 0;
}
