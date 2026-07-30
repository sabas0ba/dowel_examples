#include "cpplib.h"

/* 純 C のテストから C++ の実装を呼ぶ。実行時が繋がっていなければ
   リンクで落ちるか、例外で abort する。 */
int main(void)
{
    if (cpplib_len("xyz") != 3)  return 1;
    if (cpplib_throws(-1) != -1) return 2;
    if (cpplib_ctor_ran() != 42) return 3;
    return 0;
}
