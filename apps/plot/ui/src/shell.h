#ifndef PLOT_SHELL_H
#define PLOT_SHELL_H

#include "plot/plot.h"

/* 描いたものを見せる。0 で成功。arg は実装ごとの意味を持つ
 * （窓の側は無視、ファイルの側は書き出す先）。 */
int shell_show(const plot_canvas *c, const char *arg);

/* 実装の名乗り。成果物に何がリンクされたかを外から確かめるため。 */
const char *shell_name(void);

#endif
