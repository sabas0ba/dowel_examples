/* C からも C++ からも読める公開ヘッダ。実装は C++ で、標準ライブラリを
   使う。したがってこれを使う実行ファイルは C++ 実行時を要する。 */
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int  cpplib_len(const char *s);
int  cpplib_is_cxx(void);   /* 実装が C++ として翻訳されたか */

#ifdef __cplusplus
}
#endif
