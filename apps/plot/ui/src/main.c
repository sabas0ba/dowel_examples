/* 引数を読んで、描いて、見せる。見せ方は機能フラグが決める。 */
#include "shell.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    plot_canvas *c;
    double ys[64];
    size_t n = 0;
    const char *out = NULL;
    int w = 240, h = 120, i, rc;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--shell") == 0) {
            printf("%s\n", shell_name());
            return 0;
        }
        if (strcmp(argv[i], "--out") == 0 && i + 1 < argc) {
            out = argv[++i];
        } else if (strcmp(argv[i], "--size") == 0 && i + 1 < argc) {
            if (sscanf(argv[++i], "%dx%d", &w, &h) != 2) {
                fprintf(stderr, "plot: --size wants WxH\n");
                return 2;
            }
        } else if (n < sizeof ys / sizeof ys[0]) {
            ys[n++] = atof(argv[i]);
        }
    }

    if (n == 0) {
        for (n = 0; n < 16; n++) {
            ys[n] = (double)(n * n % 7);
        }
    }

    c = plot_canvas_new(w, h);
    if (c == NULL) {
        fprintf(stderr, "plot: cannot make a %dx%d canvas\n", w, h);
        return 2;
    }
    plot_draw(c, ys, n);
    rc = shell_show(c, out);
    plot_canvas_free(c);
    return rc;
}
