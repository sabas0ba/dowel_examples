#include "hd/hd.h"

#include <stdio.h>
#include <string.h>

long hd_parse_request(const char *buf, size_t len, hd_request *out)
{
    const char *end = memmem(buf, len, "\r\n\r\n", 4);
    const char *sp1;
    const char *sp2;
    const char *line_end;
    size_t n;

    if (end == NULL) {
        return 0;                       /* まだ揃っていない */
    }
    line_end = memchr(buf, '\r', len);
    if (line_end == NULL) {
        return -1;
    }
    sp1 = memchr(buf, ' ', (size_t) (line_end - buf));
    if (sp1 == NULL) {
        return -1;
    }
    sp2 = memchr(sp1 + 1, ' ', (size_t) (line_end - sp1 - 1));
    if (sp2 == NULL) {
        return -1;
    }

    n = (size_t) (sp1 - buf);
    if (n == 0 || n >= sizeof out->method) {
        return -1;
    }
    memcpy(out->method, buf, n);
    out->method[n] = '\0';

    n = (size_t) (sp2 - sp1 - 1);
    if (n == 0 || n >= sizeof out->path) {
        return -1;
    }
    memcpy(out->path, sp1 + 1, n);
    out->path[n] = '\0';

    /* HTTP/1.1 は既定で継続、1.0 は既定で切断。 */
    out->keep_alive = memmem(buf, len, "HTTP/1.1", 8) != NULL;
    if (memmem(buf, len, "Connection: close", 17) != NULL) {
        out->keep_alive = 0;
    }
    return (long) (end - buf) + 4;
}

int hd_resolve(const char *root, const char *path, char *out, size_t out_len)
{
    const char *p = path;
    int written;

    if (p[0] != '/') {
        return -1;
    }
    /* `..` を含む道は、正規化する前に拒む。正規化してから判定すると、
     * 記法の違い（%2e など）を1つ取りこぼすたびに穴が空く。 */
    if (strstr(p, "..") != NULL) {
        return -1;
    }
    if (strcmp(p, "/") == 0) {
        p = "/index.html";
    }
    written = snprintf(out, out_len, "%s%s", root, p);
    if (written < 0 || (size_t) written >= out_len) {
        return -1;
    }
    return 0;
}
