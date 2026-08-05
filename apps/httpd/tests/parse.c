/* 要求の解析とパスの解決。どちらもソケットを開かずに確かめられる。 */
#include "hd/hd.h"

#include <stdio.h>
#include <string.h>

static int failures;

static void ok_parse(const char *raw, const char *method, const char *path,
                     int keep_alive)
{
    hd_request r;
    long n = hd_parse_request(raw, strlen(raw), &r);

    if (n <= 0) {
        printf("FAIL parse %s -> %ld\n", raw, n);
        failures++;
        return;
    }
    if (strcmp(r.method, method) != 0 || strcmp(r.path, path) != 0
        || r.keep_alive != keep_alive) {
        printf("FAIL parse: method=%s path=%s keep=%d\n",
               r.method, r.path, r.keep_alive);
        failures++;
    }
}

static void bad_parse(const char *raw, long want)
{
    hd_request r;
    long n = hd_parse_request(raw, strlen(raw), &r);

    if ((want == 0 && n != 0) || (want < 0 && n >= 0)) {
        printf("FAIL parse %s -> %ld (wanted %ld)\n", raw, n, want);
        failures++;
    }
}

static void resolves(const char *path, const char *want)
{
    char out[256];
    int  rc = hd_resolve("/srv", path, out, sizeof out);

    if (want == NULL) {
        if (rc == 0) {
            printf("FAIL resolve %s was accepted as %s\n", path, out);
            failures++;
        }
        return;
    }
    if (rc != 0 || strcmp(out, want) != 0) {
        printf("FAIL resolve %s -> rc=%d %s\n", path, rc, out);
        failures++;
    }
}

int main(void)
{
    ok_parse("GET /a.html HTTP/1.1\r\nHost: x\r\n\r\n", "GET", "/a.html", 1);
    ok_parse("GET / HTTP/1.0\r\n\r\n", "GET", "/", 0);
    ok_parse("HEAD /x HTTP/1.1\r\nConnection: close\r\n\r\n", "HEAD", "/x", 0);

    bad_parse("GET /a HTTP/1.1\r\n", 0);          /* 未完 */
    bad_parse("GET\r\n\r\n", -1);                 /* 空白が足りない */
    bad_parse(" /a HTTP/1.1\r\n\r\n", -1);        /* method が空 */

    resolves("/", "/srv/index.html");
    resolves("/a/b.css", "/srv/a/b.css");
    resolves("/../etc/passwd", NULL);
    resolves("/a/../../etc", NULL);
    resolves("relative", NULL);

    if (strcmp(hd_mime_for("/a.html"), "text/html; charset=utf-8") != 0) {
        puts("FAIL mime html");
        failures++;
    }
    if (strcmp(hd_mime_for("/a.bin"), "application/octet-stream") != 0) {
        puts("FAIL mime unknown");
        failures++;
    }

    /* 待ち方は構成が決める。名前が空でないことだけを見る（どちらが
     * 選ばれたかは expect.sh が構成ごとに確かめる）。 */
    if (hd_waiter_name() == NULL || hd_waiter_name()[0] == '\0') {
        puts("FAIL waiter has no name");
        failures++;
    }

    if (failures != 0) {
        printf("%d failures\n", failures);
        return 1;
    }
    return 0;
}
