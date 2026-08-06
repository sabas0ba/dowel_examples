#include "bl/bl.h"

/* 実機では BL_GPIO_BASE を直に叩く。ここでは記憶の1語を相手にして、
 * 同じ翻訳単位が freestanding で通ることを確かめられるようにしてある。 */
static volatile u32 mode;
static volatile u32 state;

void bl_gpio_output(u32 pin)
{
    mode |= 1u << (pin & 31u);
}

void bl_gpio_toggle(u32 pin)
{
    if ((mode & (1u << (pin & 31u))) != 0u) {
        state ^= 1u << (pin & 31u);
    }
}

u32 bl_gpio_state(void)
{
    return state;
}
