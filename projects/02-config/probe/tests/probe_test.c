/* 終了状態 0 が成功。公開ヘッダだけで組み上がることも併せて確かめる。 */
#include "probe.h"

/* テストは probe の private ブロックの外にいる。
   非公開の定義がここまで来ていたら、伝播の分離が壊れている。 */
#ifdef PROBE_OS
#error "PROBE_OS leaked out of private.defines"
#endif
#ifdef PROBE_TRACE
#error "PROBE_TRACE leaked out of private.flags"
#endif

int main(void) {
    if (probe_opt() != PROBE_OPT) return 1;
    if (probe_os() < 1 || probe_os() > 3) return 2;
    return 0;
}
