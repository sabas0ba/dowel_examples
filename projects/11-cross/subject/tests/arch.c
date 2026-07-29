/* 宣言したトリプルと、実際に翻訳された先が一致すること。
   EXPECTED_ARCH はマニフェストが cfg.target から与える。 */
#include <string.h>
#include "arch.h"

int main(void)
{
    if (strcmp(ARCH_NAME, EXPECTED_ARCH) != 0) return 1;
    if (PTR_BITS != 64) return 2;
    return 0;
}
