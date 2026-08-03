#pragma once

#include <math.h>

#define DEMOKIT_ANSWER 42

/* この見出しを使うと libm への参照が生まれる。モジュールの --libs が
 * -lm であることに対応しており、書庫を作るだけでは落ちず、最終リンクで
 * 初めて解けなくなる。private な依存の扱いを見るのに要る性質である
 * （docs/10-findings.md F-018）。
 *
 * 定数を渡すと畳み込まれてしまうため、呼ぶ側は実行時の値を渡すこと。 */
static inline double demokit_root(double x)
{
    return sqrt(x);
}
