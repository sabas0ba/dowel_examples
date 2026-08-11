/* wt — 行末と経路。Windows と POSIX で答が違う二つを、同じ見出しの
 * 裏で切り替える。切り替えるのはビルドの側であり、呼ぶ側は知らない。 */
#ifndef WT_WT_H
#define WT_WT_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* この構成の行末。Windows なら "\r\n"、それ以外は "\n"。 */
const char *wt_eol(void);

/* この構成の経路の区切り。Windows なら '\\'、それ以外は '/'。 */
char wt_sep(void);

/* 経路の最後の要素。Windows では '/' も '\\' も区切りとして扱う——
 * 混ざった経路は実際に来る。POSIX では '/' だけである。 */
const char *wt_base(const char *path);

/* in の裸の LF をこの構成の行末に直して out へ書く。必要な長さ（終端を
 * 含む）を返す。cap が足りなければ何も書かず、必要な長さだけを返す。
 * すでに CRLF になっているところは二重にしない。 */
size_t wt_normalize(const char *in, char *out, size_t cap);

#ifdef __cplusplus
}
#endif

#endif
