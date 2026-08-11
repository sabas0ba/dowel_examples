/* 波を見る。入力と出力を重ねて描く。
 *
 * 描くのは cairo だが、**描く中身は dsp-core が作る**。算法の側は cairo を
 * 知らないし、この木がベアメタルの側と同じ算法を使っていることも知らない。
 *
 * 出すのは PPM である。窓を開けるかどうかは `apps/plot` が見ている問題で、
 * ここで確かめたいのは「同じ算法が重い依存を持つ使う側からも引ける」ことと
 * 「描いたものが実際に平滑化を映している」ことの2つである。 */
#include "dsp/dsp.h"

#include <cairo/cairo.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define N 256
#define W 512
#define H 200

/* 背景。隅の画素を厳密に比べるため単色で塗る。 */
#define BG_R 0x10
#define BG_G 0x14
#define BG_B 0x18

static int16_t in[N];
static int16_t out[N];

/* 標本の値を y 座標へ。±16384 を高さに収める。 */
static double to_y(int16_t v)
{
    return (H / 2.0) - ((double)v * (H / 2.0) / 16384.0);
}

static void trace(cairo_t *cr, const int16_t *v, double r, double g, double b)
{
    int i;

    cairo_set_source_rgb(cr, r, g, b);
    cairo_set_line_width(cr, 1.5);
    cairo_move_to(cr, 0.0, to_y(v[0]));
    for (i = 1; i < N; i++) {
        cairo_line_to(cr, (double)i * W / N, to_y(v[i]));
    }
    cairo_stroke(cr);
}

/* PPM で書き出す。読み返す側に何のライブラリも要らない形にしておく。 */
static int write_ppm(const char *path, cairo_surface_t *sf)
{
    const unsigned char *data;
    int stride, x, y;
    FILE *f;

    cairo_surface_flush(sf);
    data = cairo_image_surface_get_data(sf);
    stride = cairo_image_surface_get_stride(sf);
    if (data == NULL) {
        return -1;
    }
    f = fopen(path, "wb");
    if (f == NULL) {
        return -1;
    }
    fprintf(f, "P6\n%d %d\n255\n", W, H);
    for (y = 0; y < H; y++) {
        for (x = 0; x < W; x++) {
            /* CAIRO_FORMAT_RGB24 は小端の 32 ビットに xRGB を詰める。 */
            const unsigned char *p = data + (size_t)y * stride + (size_t)x * 4;
            unsigned char rgb[3];

            rgb[0] = p[2];
            rgb[1] = p[1];
            rgb[2] = p[0];
            if (fwrite(rgb, 1, 3, f) != 3) {
                fclose(f);
                return -1;
            }
        }
    }
    return fclose(f);
}

int main(int argc, char **argv)
{
    const char *path = NULL;
    cairo_surface_t *sf;
    cairo_t *cr;
    dsp_state s;
    int i, rc;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--out") == 0 && i + 1 < argc) {
            path = argv[++i];
        } else {
            fprintf(stderr, "dspview: unknown argument: %s\n", argv[i]);
            return 2;
        }
    }
    if (path == NULL) {
        fprintf(stderr, "dspview --out <file.ppm>\n");
        return 2;
    }

    dsp_signal(in, N);
    dsp_reset(&s);
    dsp_run(&dsp_lowpass, &s, in, out, N);

    sf = cairo_image_surface_create(CAIRO_FORMAT_RGB24, W, H);
    if (cairo_surface_status(sf) != CAIRO_STATUS_SUCCESS) {
        fprintf(stderr, "dspview: cannot create a surface\n");
        return 1;
    }
    cr = cairo_create(sf);

    cairo_set_source_rgb(cr, BG_R / 255.0, BG_G / 255.0, BG_B / 255.0);
    cairo_paint(cr);

    trace(cr, in,  0.42, 0.45, 0.50);   /* 入力。荒い方 */
    trace(cr, out, 0.30, 0.80, 0.55);   /* 出力。滑らかな方 */

    cairo_destroy(cr);
    rc = write_ppm(path, sf);
    cairo_surface_destroy(sf);

    if (rc != 0) {
        fprintf(stderr, "dspview: cannot write %s\n", path);
        return 1;
    }
    printf("drew %dx%d from %d samples, rough_in=%u rough_out=%u\n",
           W, H, N, dsp_roughness(in, N), dsp_roughness(out, N));
    return 0;
}
