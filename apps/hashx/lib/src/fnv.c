#include "internal.h"

uint32_t hashx_fnv1a(const void *data, size_t len)
{
    const unsigned char *p = (const unsigned char *)data;
    uint32_t v = 2166136261u;
    size_t i;

    for (i = 0; i < len; i++) {
        v ^= p[i];
        v *= 16777619u;
    }
    return v;
}
