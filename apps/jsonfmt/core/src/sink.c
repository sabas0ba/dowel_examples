#include "internal.h"

#include <stdlib.h>
#include <string.h>

static int sink_reserve(sink *s, size_t extra)
{
    size_t want;

    if (s->failed) {
        return 0;
    }
    want = s->len + extra + 1;
    if (want <= s->cap) {
        return 1;
    }
    while (s->cap < want) {
        s->cap = s->cap ? s->cap * 2 : 256;
    }
    {
        char *grown = realloc(s->buf, s->cap);
        if (grown == NULL) {
            s->failed = 1;
            return 0;
        }
        s->buf = grown;
    }
    return 1;
}

void sink_putc(sink *s, char c)
{
    if (!sink_reserve(s, 1)) {
        return;
    }
    s->buf[s->len++] = c;
    s->buf[s->len] = '\0';
}

void sink_puts(sink *s, const char *str)
{
    size_t n = strlen(str);

    if (!sink_reserve(s, n)) {
        return;
    }
    memcpy(s->buf + s->len, str, n);
    s->len += n;
    s->buf[s->len] = '\0';
}

void sink_indent(sink *s, int width, int level)
{
    int i;

    if (width <= 0) {
        return;
    }
    sink_putc(s, '\n');
    for (i = 0; i < width * level; i++) {
        sink_putc(s, ' ');
    }
}
