/* どの構成で翻訳されたかを成果物自身に名乗らせる。
 *
 * 「最適化されたか」を機械語の量で測ると、測っているのがコンパイラの
 * 世代なのか dowel の渡した引数なのかが分からなくなる。__OPTIMIZE__ は
 * gcc と clang の双方が最適化水準が 0 でないときにのみ定義するため、
 * 「-O0 が -O2 に勝ったかどうか」をそのまま読める。
 */
#include <stdio.h>

int main(void)
{
#ifdef NDEBUG
    printf("ndebug\n");
#else
    printf("assertions\n");
#endif
#ifdef __OPTIMIZE__
    printf("optimized\n");
#else
    printf("unoptimized\n");
#endif
    return 0;
}
