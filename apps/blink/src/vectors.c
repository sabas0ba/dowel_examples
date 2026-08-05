/* ベクタ表。専用の節に置き、リンカスクリプトが先頭へ寄せる。
 * KEEP で囲まないと、誰も参照しないため削られる。 */
#include "bl/bl.h"

void _reset(void);

static void hang(void)
{
    for (;;) {
    }
}

__attribute__((section(".vectors"), used))
void (*const vectors[])(void) = {
    _reset,     /* 0: 立ち上がり */
    hang,       /* 1: 誤り */
    hang,       /* 2: 未定義命令 */
    hang,       /* 3: 番地の誤り */
};
