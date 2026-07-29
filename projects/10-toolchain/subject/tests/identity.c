/* 宣言したツールチェーンと、実際に翻訳したコンパイラが一致すること。
   EXPECTED は expect.sh が -D で与える。 */
#include <string.h>
#include "which.h"

int main(void)
{
    return strcmp(COMPILED_BY, EXPECTED) == 0 ? 0 : 1;
}
