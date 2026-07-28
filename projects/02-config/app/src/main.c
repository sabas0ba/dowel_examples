#include <stdio.h>

#include "probe.h"

/* app 自身の match が届いていること。 */
#ifndef APP_OPT
#error "APP_OPT is missing: match cfg.opt did not reach the compiler"
#endif
#ifndef APP_ARCH
#error "APP_ARCH is missing: match host.arch did not reach the compiler"
#endif

/* probe の非公開な定義とフラグは、依存元であるここへ届いてはならない。 */
#ifdef PROBE_OS
#error "PROBE_OS leaked from probe's private block into a dependent"
#endif
#ifdef PROBE_TRACE
#error "PROBE_TRACE leaked from probe's private flags into a dependent"
#endif

/* 公開の定義は構成で変わりながら届く。ライブラリの実体と、
   このコンパイル単位に届いた定数が一致することを実行時に見る。 */
int main(void) {
    if (probe_opt() != PROBE_OPT) {
        fprintf(stderr, "probe was built with opt=%d but APP sees %d\n", probe_opt(), PROBE_OPT);
        return 1;
    }
    printf("app_opt=%d probe_opt=%d arch=%d os=%d trace=%d\n", APP_OPT, PROBE_OPT, APP_ARCH,
           probe_os(), probe_trace());
    return 0;
}
