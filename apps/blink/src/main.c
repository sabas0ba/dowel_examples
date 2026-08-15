/* 入口。libc も起動コードも無いので、ここが本当の先頭である。 */
#include "bl/bl.h"

#define LED 13u

/* 外から読めるようにしておく印。生イメージの中に現れる。 */
__attribute__((used))
const char build_marker[] = "DOWEL-BLINK";

void bl_main(void)
{
    bl_gpio_output(LED);
    for (;;) {
        bl_gpio_toggle(LED);
        bl_delay(100000u);
    }
}
