/* 実機（の代わりの qemu）で走るテスト。
 *
 * ホスト向けに組んだものを走らせても、周辺機器の番地も命令集合も違う。
 * ベアメタルの層で「動く」を確かめるには、**その機械の上で走らせる**しか
 * ない。結果は semihosting で返す。 */
#include "bl/bl.h"

void _reset(void);

static void hang(void)
{
    for (;;) {
    }
}

/* ベクタ表。テストも実体と同じ形で立ち上がる。 */
__attribute__((section(".vectors"), used))
void (*const vectors[])(void) = {
    (void (*)(void)) 0x20400000u,   /* [0] 初期スタックポインタ（RAM の末尾） */
    _reset,                         /* [1] リセット */
    hang, hang, hang, hang, hang,
};

#define LED 13u

void _reset(void)
{
    u32 before;

    bl_say("blink: running on emulated hardware\n");

    /* 向きを設定していない間は反転しない。 */
    before = bl_gpio_state();
    bl_gpio_toggle(LED);
    if (bl_gpio_state() != before) {
        bl_say("blink: FAIL toggling an input changed the state\n");
        bl_exit(1);
    }

    bl_gpio_output(LED);
    bl_gpio_toggle(LED);
    if (bl_gpio_state() == before) {
        bl_say("blink: FAIL toggling an output did not change the state\n");
        bl_exit(2);
    }
    bl_gpio_toggle(LED);
    if (bl_gpio_state() != before) {
        bl_say("blink: FAIL toggling twice did not return to the start\n");
        bl_exit(3);
    }

    /* 待ちが本当に回っていること。最適化で消えると 0 のままになる。 */
    bl_delay(1000u);
    if (bl_delay_count() != 1000u) {
        bl_say("blink: FAIL the delay loop did not run\n");
        bl_exit(4);
    }

    bl_say("blink: ok\n");
    bl_exit(0);
}
