#pragma once

/* A public define of this library must reach every dependent. */
#ifndef PROBE_API
#error "PROBE_API is missing: public defines did not reach this translation unit"
#endif

/* Optimization configuration this library was built with. 0 = debug, 1 = release. */
int probe_opt(void);

/* Operating system of the build host. 1 = linux, 2 = macos, 3 = windows. */
int probe_os(void);

/* 1 when feature.trace was enabled. */
int probe_trace(void);
