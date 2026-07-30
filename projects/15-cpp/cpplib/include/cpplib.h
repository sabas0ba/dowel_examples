/* C からも C++ からも読める公開ヘッダ。実装は C++ で、標準ライブラリと
   例外と大域構築子を使う。したがってこれを使う実行ファイルは、
   記号が解決するだけでなく C++ 実行時の機構が生きている必要がある。 */
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int cpplib_len(const char *s);   /* std::string を使う */
int cpplib_throws(int n);        /* 送出と捕捉。巻き戻しが要る */
int cpplib_ctor_ran(void);       /* 大域の構築子が走ったか */
int cpplib_is_cxx(void);         /* 実装が C++ として翻訳されたか */

#ifdef __cplusplus
}
#endif
