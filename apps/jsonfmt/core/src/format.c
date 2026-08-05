#include "internal.h"

#include <stdlib.h>

/* 直近の誤りの位置。診断のためだけに持つ。 */
static size_t last_error_offset;

int json_max_depth(void)
{
    return JSON_MAX_DEPTH;
}

const char *json_status_text(json_status s)
{
    switch (s) {
    case JSON_OK:         return "ok";
    case JSON_ERR_SYNTAX: return "syntax error";
    case JSON_ERR_DEPTH:  return "nesting too deep";
    case JSON_ERR_MEMORY: return "out of memory";
    }
    return "unknown";
}

size_t json_error_offset(void)
{
    return last_error_offset;
}

json_status json_format(const char *text, size_t len, int indent,
                        char **out, size_t *out_len)
{
    scanner sc;
    sink    sk;
    json_status st;

    sc.text = text;
    sc.len = len;
    sc.pos = 0;
    sc.depth = 0;
    sc.status = JSON_OK;

    sk.buf = NULL;
    sk.len = 0;
    sk.cap = 0;
    sk.failed = 0;

    st = scan_value(&sc, &sk, indent, 0);
    if (st == JSON_OK) {
        scan_space(&sc);
        if (sc.pos != sc.len) {
            st = JSON_ERR_SYNTAX;       /* 末尾に余りがある */
        }
    }
    if (sk.failed) {
        st = JSON_ERR_MEMORY;
    }
    if (st != JSON_OK) {
        last_error_offset = sc.pos;
        free(sk.buf);
        return st;
    }

    sink_putc(&sk, '\n');
    if (sk.failed) {
        free(sk.buf);
        return JSON_ERR_MEMORY;
    }
    *out = sk.buf;
    *out_len = sk.len;
    return JSON_OK;
}
