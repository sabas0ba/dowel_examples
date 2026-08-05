#include "bl/bl.h"

static volatile u64 ticks_waited;

void bl_delay(u32 ticks)
{
    u32 i;

    for (i = 0; i < ticks; i++) {
        /* 最適化で消させない。実機では読み書きが観測される。 */
        __asm__ volatile ("" ::: "memory");
    }
    ticks_waited += ticks;
}

u64 bl_delay_count(void)
{
    return ticks_waited;
}
