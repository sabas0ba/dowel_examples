#include "core.h"

int core_v(void)
{
#ifdef PATCHED
    return 2;
#else
    return 1;
#endif
}
