/* plot — 折れ線を描く。窓のことは何も知らない。
 *
 * 描いた結果は画素の並びとして取り出せる。見せる相手（X11 の窓か、
 * ファイルか）は使う側が決める。GUI を機械で確かめられるかどうかは、
 * この境目を引けるかどうかで決まる。 */
#ifndef PLOT_H
#define PLOT_H

#include <stddef.h>
#include <stdint.h>

typedef struct plot_canvas plot_canvas;

/* 幅と高さを指定して作る。失敗したら NULL。 */
plot_canvas *plot_canvas_new(int w, int h);
void         plot_canvas_free(plot_canvas *c);

int plot_canvas_width(const plot_canvas *c);
int plot_canvas_height(const plot_canvas *c);

/* 画素の並び。1画素 4 バイト、行あたり plot_canvas_stride バイト。
 * 並びは little-endian の 0xAARRGGBB（記憶の上では B G R A）。 */
const unsigned char *plot_canvas_pixels(const plot_canvas *c);
int                  plot_canvas_stride(const plot_canvas *c);

/* 1画素を 0xAARRGGBB として読む。範囲外は 0。 */
uint32_t plot_pixel(const plot_canvas *c, int x, int y);

/* 背景を塗り、枠を描き、値の並びを折れ線にする。 */
void plot_draw(plot_canvas *c, const double *ys, size_t n);

/* 背景と枠の色。使う側が確かめられるよう公開する。 */
#define PLOT_BACKGROUND 0xFF101418u
#define PLOT_INK        0xFF6FA8DCu

#endif
