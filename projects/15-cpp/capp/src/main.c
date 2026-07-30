#include "cpplib.h"

/* この翻訳単位は C である。__cplusplus は定義されない。
   それでも C++ 実行時の機構は繋がっていなければならない。 */
int main(void)
{
#ifdef __cplusplus
    return 9;
#endif
    if (cpplib_len("abcd") != 4)  return 1;  /* 標準ライブラリ */
    if (cpplib_throws(5) != 10)   return 2;  /* 通常経路 */
    if (cpplib_throws(-1) != -1)  return 3;  /* 例外が捕まる */
    if (cpplib_ctor_ran() != 42)  return 4;  /* 大域の構築子が走った */
    if (!cpplib_is_cxx())         return 5;
    return 0;
}
