#include "internal.h"

void scan_space(scanner *sc)
{
    while (sc->pos < sc->len) {
        char c = sc->text[sc->pos];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            sc->pos++;
        } else {
            break;
        }
    }
}

static int at(const scanner *sc, char c)
{
    return sc->pos < sc->len && sc->text[sc->pos] == c;
}

static json_status scan_string(scanner *sc, sink *out)
{
    sink_putc(out, '"');
    sc->pos++;                                  /* 開きの " */
    while (sc->pos < sc->len) {
        char c = sc->text[sc->pos++];
        if (c == '\\') {
            if (sc->pos >= sc->len) {
                break;
            }
            sink_putc(out, c);
            sink_putc(out, sc->text[sc->pos++]);
            continue;
        }
        sink_putc(out, c);
        if (c == '"') {
            return JSON_OK;
        }
    }
    return JSON_ERR_SYNTAX;
}

static json_status scan_atom(scanner *sc, sink *out)
{
    size_t start = sc->pos;

    while (sc->pos < sc->len) {
        char c = sc->text[sc->pos];
        if (c == ',' || c == ']' || c == '}' || c == ' ' || c == '\t'
            || c == '\n' || c == '\r') {
            break;
        }
        sc->pos++;
    }
    if (sc->pos == start) {
        return JSON_ERR_SYNTAX;
    }
    {
        size_t i;
        for (i = start; i < sc->pos; i++) {
            sink_putc(out, sc->text[i]);
        }
    }
    return JSON_OK;
}

/* 配列とオブジェクトは要素の区切りだけが違う。 */
static json_status scan_group(scanner *sc, sink *out, int indent, int level,
                              char open, char close, int keyed)
{
    int first = 1;

    if (sc->depth >= JSON_MAX_DEPTH) {
        return JSON_ERR_DEPTH;
    }
    sc->depth++;
    sink_putc(out, open);
    sc->pos++;

    for (;;) {
        json_status st;

        scan_space(sc);
        if (at(sc, close)) {
            sc->pos++;
            if (!first) {
                sink_indent(out, indent, level);
            }
            sink_putc(out, close);
            sc->depth--;
            return JSON_OK;
        }
        if (!first) {
            if (!at(sc, ',')) {
                return JSON_ERR_SYNTAX;
            }
            sc->pos++;
            sink_putc(out, ',');
            scan_space(sc);
        }
        first = 0;
        sink_indent(out, indent, level + 1);

        if (keyed) {
            if (!at(sc, '"')) {
                return JSON_ERR_SYNTAX;
            }
            st = scan_string(sc, out);
            if (st != JSON_OK) {
                return st;
            }
            scan_space(sc);
            if (!at(sc, ':')) {
                return JSON_ERR_SYNTAX;
            }
            sc->pos++;
            sink_putc(out, ':');
            if (indent > 0) {
                sink_putc(out, ' ');
            }
            scan_space(sc);
        }

        st = scan_value(sc, out, indent, level + 1);
        if (st != JSON_OK) {
            return st;
        }
    }
}

json_status scan_value(scanner *sc, sink *out, int indent, int level)
{
    scan_space(sc);
    if (sc->pos >= sc->len) {
        return JSON_ERR_SYNTAX;
    }
    switch (sc->text[sc->pos]) {
    case '{':
        return scan_group(sc, out, indent, level, '{', '}', 1);
    case '[':
        return scan_group(sc, out, indent, level, '[', ']', 0);
    case '"':
        return scan_string(sc, out);
    default:
        return scan_atom(sc, out);
    }
}
