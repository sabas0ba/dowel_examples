/* jsonfmt — JSON を読んで整形して書く。
 *
 *   jsonfmt [-c] [-i N] [FILE]
 *
 * FILE を省くと標準入力を読む。-c は1行に詰める。 */
#include "json/json.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHUNK 65536

static char *slurp(FILE *f, size_t *len)
{
    char  *buf = NULL;
    size_t cap = 0;
    size_t n = 0;

    for (;;) {
        size_t got;
        if (n + CHUNK + 1 > cap) {
            char *grown;
            cap = cap ? cap * 2 : CHUNK * 2;
            grown = realloc(buf, cap);
            if (grown == NULL) {
                free(buf);
                return NULL;
            }
            buf = grown;
        }
        got = fread(buf + n, 1, CHUNK, f);
        n += got;
        if (got < CHUNK) {
            break;
        }
    }
    buf[n] = '\0';
    *len = n;
    return buf;
}

static void usage(void)
{
    fputs("usage: jsonfmt [-c] [-i N] [FILE]\n", stderr);
}

int main(int argc, char **argv)
{
    int    indent = 2;
    const char *path = NULL;
    FILE  *in = stdin;
    char  *text;
    size_t len;
    char  *out;
    size_t out_len;
    json_status st;
    int i;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-c") == 0) {
            indent = 0;
        } else if (strcmp(argv[i], "-i") == 0 && i + 1 < argc) {
            indent = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--max-depth") == 0) {
            printf("%d\n", json_max_depth());
            return 0;
        } else if (argv[i][0] == '-' && argv[i][1] != '\0') {
            usage();
            return 2;
        } else {
            path = argv[i];
        }
    }

    if (path != NULL) {
        in = fopen(path, "rb");
        if (in == NULL) {
            fprintf(stderr, "jsonfmt: cannot open %s\n", path);
            return 2;
        }
    }
    text = slurp(in, &len);
    if (in != stdin) {
        fclose(in);
    }
    if (text == NULL) {
        fputs("jsonfmt: out of memory\n", stderr);
        return 2;
    }

    st = json_format(text, len, indent, &out, &out_len);
    if (st != JSON_OK) {
        fprintf(stderr, "jsonfmt: %s at byte %zu\n",
                json_status_text(st), json_error_offset());
        free(text);
        return 1;
    }
    fwrite(out, 1, out_len, stdout);
    free(out);
    free(text);
    return 0;
}
