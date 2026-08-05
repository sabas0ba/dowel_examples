/* 内部の見出し。使う側には渡さない（`private` の includes にだけ入れる）。 */
#ifndef JSON_INTERNAL_H
#define JSON_INTERNAL_H

#include "json/json.h"

typedef struct {
    const char *text;
    size_t      len;
    size_t      pos;
    int         depth;
    json_status status;
} scanner;

typedef struct {
    char  *buf;
    size_t len;
    size_t cap;
    int    failed;
} sink;

void        sink_putc(sink *s, char c);
void        sink_puts(sink *s, const char *str);
void        sink_indent(sink *s, int width, int level);
void        scan_space(scanner *sc);
json_status scan_value(scanner *sc, sink *out, int indent, int level);

#endif
