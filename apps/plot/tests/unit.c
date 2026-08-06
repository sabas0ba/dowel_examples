/* 描いた画素を直に読む。GUI を機械で確かめるとは、こういうことである。
 * 「窓が出た」は確かめられないが、「何が描かれたか」は確かめられる。 */
#include "plot/plot.h"

#include <stdio.h>
#include <stdlib.h>

static int fails;

static void eq(uint32_t got, uint32_t want, const char *what)
{
    if (got != want) {
        printf("FAIL %s: want 0x%08x got 0x%08x\n", what, want, got);
        fails++;
    }
}

static void yes(int cond, const char *what)
{
    if (!cond) {
        printf("FAIL %s\n", what);
        fails++;
    }
}

int main(void)
{
    static const double up[]   = { 0.0, 1.0, 2.0, 3.0 };
    static const double flat[] = { 5.0, 5.0, 5.0, 5.0 };
    plot_canvas *c;
    int x, y, ink = 0;

    yes(plot_canvas_new(0, 10) == NULL, "a canvas with no width is refused");
    yes(plot_canvas_new(10, -1) == NULL, "a canvas with negative height is refused");

    c = plot_canvas_new(64, 32);
    yes(c != NULL, "a canvas of a sane size is made");
    if (c == NULL) {
        return 1;
    }
    yes(plot_canvas_width(c) == 64, "the canvas keeps its width");
    yes(plot_canvas_height(c) == 32, "the canvas keeps its height");

    /* 値を渡さない場合、全面が背景色である。単色塗りなので厳密に一致する。 */
    plot_draw(c, NULL, 0);
    eq(plot_pixel(c, 0, 0), PLOT_BACKGROUND, "the top-left pixel is the background");
    eq(plot_pixel(c, 63, 31), PLOT_BACKGROUND, "and so is the bottom-right");

    /* 範囲の外は 0 を返す。落ちない。 */
    eq(plot_pixel(c, -1, 0), 0, "a pixel left of the canvas reads as zero");
    eq(plot_pixel(c, 64, 0), 0, "a pixel right of the canvas reads as zero");
    eq(plot_pixel(NULL, 0, 0), 0, "a pixel of no canvas reads as zero");

    /* 折れ線を描くと、背景以外の画素が現れる。 */
    plot_draw(c, up, 4);
    for (y = 0; y < 32; y++) {
        for (x = 0; x < 64; x++) {
            if (plot_pixel(c, x, y) != PLOT_BACKGROUND) {
                ink++;
            }
        }
    }
    yes(ink > 0, "drawing a series puts ink on the canvas");

    /* 左下から右上へ上がる並びなので、左下の隅の近くに墨がある。 */
    yes(plot_pixel(c, 0, 31) != PLOT_BACKGROUND,
        "a rising series starts at the bottom-left");
    yes(plot_pixel(c, 63, 0) != PLOT_BACKGROUND,
        "and ends at the top-right");

    /* 平らな並びで割り算が壊れないこと。 */
    plot_draw(c, flat, 4);
    yes(plot_pixel(c, 32, 31) != 0, "a flat series does not divide by its own zero span");

    plot_canvas_free(c);
    plot_canvas_free(NULL);

    printf("%s\n", fails ? "some checks failed" : "all checks passed");
    return fails ? 1 : 0;
}
