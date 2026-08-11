/* 公開の見出しだけを使う。中がどちらの構成かは、答の側から確かめる。 */
#include "wt/wt.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static int fail(const char *why)
{
    fprintf(stderr, "unit: %s\n", why);
    return 1;
}

/* この構成が Windows 向けか。行末が答である。 */
static int windows(void) { return strcmp(wt_eol(), "\r\n") == 0; }

static int case_eol(void)
{
    const char *e = wt_eol();
    if (windows()) {
        if (strcmp(e, "\r\n") != 0) return fail("expected CRLF");
    } else {
        if (strcmp(e, "\n") != 0)   return fail("expected LF");
    }
    return 0;
}

static int case_sep(void)
{
    char s = wt_sep();
    if (windows()) {
        if (s != '\\') return fail("expected a backslash");
    } else {
        if (s != '/')  return fail("expected a slash");
    }
    return 0;
}

static int case_base(void)
{
    if (strcmp(wt_base("/a/b/c.txt"), "c.txt") != 0) return fail("posix path");
    if (strcmp(wt_base("plain.txt"),  "plain.txt") != 0) return fail("no separator");
    if (strcmp(wt_base("/a/b/"),      "") != 0) return fail("trailing separator");

    /* 混ざった経路。Windows では '/' も区切りである。 */
    if (windows()) {
        if (strcmp(wt_base("C:\\a\\b.txt"), "b.txt") != 0) return fail("backslash path");
        if (strcmp(wt_base("C:\\a/b.txt"),  "b.txt") != 0) return fail("mixed path");
    } else {
        if (strcmp(wt_base("a\\b.txt"), "a\\b.txt") != 0) return fail("backslash is not a separator here");
    }
    return 0;
}

static int case_norm(void)
{
    char buf[64];
    const char *want = windows() ? "a\r\nb\r\n" : "a\nb\n";

    if (wt_normalize("a\nb\n", buf, sizeof buf) > sizeof buf) return fail("short buffer");
    if (strcmp(buf, want) != 0) return fail("bare LF was not converted");

    /* すでに正しい行末を二重にしない。 */
    if (wt_normalize("a\r\nb\r\n", buf, sizeof buf) > sizeof buf) return fail("short buffer");
    if (windows() && strcmp(buf, "a\r\nb\r\n") != 0) return fail("CRLF was doubled");

    /* 足りない容量では何も書かず、必要な長さを返す。 */
    if (wt_normalize("a\nb\n", buf, 2) <= 2) return fail("a short buffer should report the need");
    return 0;
}

int main(int argc, char **argv)
{
    const char *which = (argc > 1) ? argv[1] : "";

    if (strcmp(which, "eol")  == 0) return case_eol();
    if (strcmp(which, "sep")  == 0) return case_sep();
    if (strcmp(which, "base") == 0) return case_base();
    if (strcmp(which, "norm") == 0) return case_norm();
    fprintf(stderr, "unit: no such case: %s\n", which);
    return 2;
}
