/* semihosting の窓口。
 *
 * ARM の取り決めでは、`bkpt 0xAB` を実行すると r0 の操作番号と r1 の引数を
 * 見た側（デバッガ、あるいは qemu）が代わりに実行する。ベアメタルの
 * テストが結果を伝える唯一の手段である。 */
#include "bl/bl.h"

#define SYS_WRITE0       0x04u
#define SYS_EXIT_EXT     0x20u
#define ADP_APP_EXIT     0x20026u

static void call(u32 op, const void *arg)
{
    register u32 r0 __asm__("r0") = op;
    register const void *r1 __asm__("r1") = arg;

    __asm__ volatile ("bkpt 0xAB" :: "r"(r0), "r"(r1) : "memory");
}

void bl_say(const char *s)
{
    call(SYS_WRITE0, s);
}

void bl_exit(u32 code)
{
    /* 拡張形は2語を渡す。こちらでないと終了状態が伝わらず、
     * 失敗を失敗として返せない。 */
    u32 args[2];

    args[0] = ADP_APP_EXIT;
    args[1] = code;
    call(SYS_EXIT_EXT, args);
    for (;;) {
    }
}
