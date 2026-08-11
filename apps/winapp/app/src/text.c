/* 可搬な側。行末と区切りが何であるかは知らないが、それを使う規則はここにある。
 * plat_*.c が答を与え、この翻訳単位はどちらの構成でも同じものが使われる。 */
#include "wt/wt.h"
#include "internal.h"

#include <string.h>

const char *wt_base(const char *path)
{
    const char *last = path;
    const char *p;

    if (path == NULL) {
        return NULL;
    }
    for (p = path; *p != '\0'; p++) {
        if (wt_is_sep(*p)) {
            last = p + 1;
        }
    }
    return last;
}

size_t wt_normalize(const char *in, char *out, size_t cap)
{
    const char *eol = wt_eol();
    size_t eol_len = strlen(eol);
    size_t need = 1;              /* 終端の分 */
    size_t at = 0;
    const char *p;

    if (in == NULL) {
        return 0;
    }
    for (p = in; *p != '\0'; p++) {
        if (*p == '\r' && p[1] == '\n') {
            continue;             /* すでに CRLF。次の LF が書く */
        }
        need += (*p == '\n') ? eol_len : 1;
    }
    if (out == NULL || cap < need) {
        return need;
    }
    for (p = in; *p != '\0'; p++) {
        if (*p == '\r' && p[1] == '\n') {
            continue;
        }
        if (*p == '\n') {
            memcpy(out + at, eol, eol_len);
            at += eol_len;
        } else {
            out[at++] = *p;
        }
    }
    out[at] = '\0';
    return need;
}
