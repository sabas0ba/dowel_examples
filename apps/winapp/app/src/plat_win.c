/* Windows の側。この翻訳単位は Windows 向けの構成でだけ翻訳される。
 * <windows.h> を含むので、ほかの構成では組み上がらない。 */
#include "wt/wt.h"
#include "internal.h"

#include <windows.h>

const char *wt_eol(void) { return "\r\n"; }

char wt_sep(void) { return '\\'; }

/* Windows では '/' も区切りとして通る。API がそう扱う以上、
 * 経路を割る側もそう扱わなければ、混ざった経路で答が変わる。 */
int wt_is_sep(char c) { return c == '\\' || c == '/'; }

/* 本当に Win32 を呼んでいることの証。可搬な代わりでは答えられない。 */
unsigned long wt_page_size(void)
{
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    return (unsigned long)si.dwPageSize;
}
