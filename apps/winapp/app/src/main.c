/* 使う側。どちらの構成でも同じ引数を受け、構成ごとに違う答を返す。 */
#include "wt/wt.h"

#include <stdio.h>
#include <string.h>

unsigned long wt_page_size(void);

/* 見えない文字を見える形にする。CRLF と LF の違いは目では分からない。 */
static void show(const char *s)
{
    for (; *s != '\0'; s++) {
        if (*s == '\r')      fputs("\\r", stdout);
        else if (*s == '\n') fputs("\\n", stdout);
        else                 fputc(*s, stdout);
    }
    fputc('\n', stdout);
}

int main(int argc, char **argv)
{
    const char *what = (argc > 1) ? argv[1] : "info";

    if (strcmp(what, "eol") == 0) {
        show(wt_eol());
        return 0;
    }
    if (strcmp(what, "sep") == 0) {
        printf("%c\n", wt_sep());
        return 0;
    }
    if (strcmp(what, "base") == 0) {
        if (argc < 3) { fputs("wt base <path>\n", stderr); return 2; }
        printf("%s\n", wt_base(argv[2]));
        return 0;
    }
    if (strcmp(what, "norm") == 0) {
        char buf[512];
        if (argc < 3) { fputs("wt norm <text>\n", stderr); return 2; }
        if (wt_normalize(argv[2], buf, sizeof buf) > sizeof buf) {
            fputs("too long\n", stderr);
            return 2;
        }
        show(buf);
        return 0;
    }
    if (strcmp(what, "info") == 0) {
        printf("eol=%s sep=%c page=%lu\n",
               (strcmp(wt_eol(), "\r\n") == 0) ? "crlf" : "lf",
               wt_sep(), wt_page_size());
        return 0;
    }
    fprintf(stderr, "wt: unknown command: %s\n", what);
    return 2;
}
