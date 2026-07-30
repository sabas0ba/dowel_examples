#include "cpplib.h"

/* 純 C のテストから C++ の実装を呼ぶ。C++ 実行時が繋がっていなければ
   リンクで落ちる。通ればテストとして成功する。 */
int main(void) { return cpplib_len("xyz") == 3 ? 0 : 1; }
