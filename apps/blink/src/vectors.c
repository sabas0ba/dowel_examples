/* Cortex-M のベクタ表。
 *
 * リセット時、CPU は flash の先頭から2語を読む。[0] がスタックポインタの
 * 初期値、[1] が最初に実行する番地である。したがってこの表は flash の
 * 先頭になければならず、それを決めるのがリンカスクリプトである。
 *
 * 誰もこの表を参照しないため、`used` を付けないと削られる。削られると
 * 実機は立ち上がらない。 */
#include "bl/bl.h"

void _reset(void);

/* SRAM の末尾。ld/thumbv7em-none-eabihf.ld の RAM の ORIGIN + LENGTH と
 * 揃えてある。スクリプトの側で `_stack_top` を与える書き方もあるが、
 * スクリプトを使えない構成（F-025）でも組めるようにここへ置いている。 */
#define STACK_TOP 0x20010000u

static void hang(void)
{
    for (;;) {
    }
}

__attribute__((section(".vectors"), used))
void (*const vectors[])(void) = {
    (void (*)(void)) STACK_TOP,   /* [0] 初期スタックポインタ */
    _reset,                       /* [1] リセット */
    hang,                         /* [2] NMI */
    hang,                         /* [3] ハードフォールト */
    hang,                         /* [4] メモリ管理 */
    hang,                         /* [5] バスフォールト */
    hang,                         /* [6] 使用法フォールト */
};
