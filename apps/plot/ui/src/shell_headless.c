/* 窓を開かない側。PPM (P6) で書き出す。形式を単純に保つのは、
 * 読み返す側（検査）が別の依存を要らないようにするためである。 */
#include "shell.h"

#include <stdio.h>

const char *shell_name(void) { return "headless"; }

int shell_show(const plot_canvas *c, const char *arg)
{
    FILE *f;
    int x, y, w, h;

    if (c == NULL) {
        return 2;
    }
    w = plot_canvas_width(c);
    h = plot_canvas_height(c);

    f = (arg == NULL) ? stdout : fopen(arg, "wb");
    if (f == NULL) {
        fprintf(stderr, "plot: cannot write %s\n", arg);
        return 2;
    }
    fprintf(f, "P6\n%d %d\n255\n", w, h);
    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            uint32_t p = plot_pixel(c, x, y);
            unsigned char rgb[3];
            rgb[0] = (unsigned char)((p >> 16) & 0xFFu);
            rgb[1] = (unsigned char)((p >> 8)  & 0xFFu);
            rgb[2] = (unsigned char)( p        & 0xFFu);
            fwrite(rgb, 1, 3, f);
        }
    }
    if (f != stdout) {
        fclose(f);
    } else {
        fflush(f);
    }
    return 0;
}
