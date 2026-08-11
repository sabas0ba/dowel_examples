/* 描いた結果を読み返す。GL も OpenCV も、ここからは見えない——
 * 見えるのは C の見出し1枚だけである。それが「面を保つ」ということ。 */
#include "vis/vis.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int fails;

static void eq_long(long got, long want, const char *what)
{
    if (got != want) {
        printf("FAIL %s: want %ld got %ld\n", what, want, got);
        fails++;
    }
}

static void eq_hex(uint32_t got, uint32_t want, const char *what)
{
    if (got != want) {
        printf("FAIL %s: want 0x%06x got 0x%06x\n", what, want, got);
        fails++;
    }
}

static void yes(int cond, const char *what)
{
    if (!cond) { printf("FAIL %s\n", what); fails++; }
}

/* 背景だけの像。全画素が背景色であり、明るい画素は1つも無い。 */
static void case_blank(void)
{
    vis_image *im = vis_render_blank(64, 48);
    yes(im != NULL, "a blank render succeeds");
    if (im == NULL) { return; }

    eq_long(vis_image_width(im), 64, "the blank image keeps its width");
    eq_long(vis_image_height(im), 48, "and its height");
    eq_hex(vis_image_pixel(im, 0, 0), VIS_BACKGROUND, "the top-left pixel is the background");
    eq_hex(vis_image_pixel(im, 63, 47), VIS_BACKGROUND, "and so is the bottom-right");
    eq_long(vis_count_bright(im, 128), 0, "nothing is bright on a blank image");

    /* 範囲外は 0 を返す。落ちない。 */
    eq_hex(vis_image_pixel(im, -1, 0), 0, "a pixel left of the image reads as zero");
    eq_hex(vis_image_pixel(im, 64, 0), 0, "a pixel right of the image reads as zero");
    eq_hex(vis_image_pixel(NULL, 0, 0), 0, "a pixel of no image reads as zero");

    vis_image_free(im);
    vis_image_free(NULL);
}

/* 三角形。頂点は下辺の左右と上の中央にある。 */
static void case_triangle(void)
{
    vis_image *im = vis_render_triangle(64, 48);
    yes(im != NULL, "a triangle render succeeds");
    if (im == NULL) { return; }

    long bright = vis_count_bright(im, 128);
    yes(bright > 0, "drawing a triangle puts bright pixels on the image");
    yes(bright < 64L * 48L, "but does not fill the whole image");

    /* 隅は三角形の外である。上の2隅と、下辺の外側。 */
    eq_hex(vis_image_pixel(im, 0, 0), VIS_BACKGROUND, "the top-left corner is outside the triangle");
    eq_hex(vis_image_pixel(im, 63, 0), VIS_BACKGROUND, "and so is the top-right");

    /* 重心のあたりは中である。 */
    yes(vis_image_pixel(im, 32, 30) != VIS_BACKGROUND, "the middle of the triangle is not background");

    vis_image_free(im);
}

/* 閾値。上げれば数は減り、極端な値では 0 か全部になる。 */
static void case_threshold(void)
{
    vis_image *im = vis_render_triangle(64, 48);
    if (im == NULL) { printf("FAIL threshold: no image\n"); fails++; return; }

    long low  = vis_count_bright(im, 8);
    long mid  = vis_count_bright(im, 128);
    long high = vis_count_bright(im, 250);

    yes(low >= mid, "a lower threshold never counts fewer pixels");
    yes(mid >= high, "and a higher one never counts more");
    eq_long(vis_count_bright(im, 255), 0, "nothing is brighter than the brightest value");

    /* 誤った閾値は拒む。 */
    eq_long(vis_count_bright(im, -1), -1, "a negative threshold is refused");
    eq_long(vis_count_bright(im, 256), -1, "and one past the range");
    eq_long(vis_count_bright(NULL, 128), -1, "and counting no image at all");

    vis_image_free(im);
}

/* 拡大縮小。寸法が変わり、内容の性質は保たれる。 */
static void case_resize(void)
{
    vis_image *im = vis_render_triangle(64, 48);
    if (im == NULL) { printf("FAIL resize: no image\n"); fails++; return; }

    vis_image *big = vis_resize(im, 128, 96);
    yes(big != NULL, "an image can be resized");
    if (big != NULL) {
        eq_long(vis_image_width(big), 128, "the resized image has the width asked for");
        eq_long(vis_image_height(big), 96, "and the height");
        /* 最近傍で2倍にしたので、明るい画素はおよそ4倍になる。 */
        long a = vis_count_bright(im, 128);
        long b = vis_count_bright(big, 128);
        yes(b > a * 3 && b < a * 5, "and about four times as many bright pixels after doubling");
        vis_image_free(big);
    }

    yes(vis_resize(im, 0, 10) == NULL, "a resize to no width is refused");
    yes(vis_resize(NULL, 4, 4) == NULL, "and resizing no image at all");

    vis_image_free(im);
}

int main(int argc, char **argv)
{
    const char *what = argc > 1 ? argv[1] : "";

    if (strcmp(what, "blank") == 0)          { case_blank(); }
    else if (strcmp(what, "triangle") == 0)  { case_triangle(); }
    else if (strcmp(what, "threshold") == 0) { case_threshold(); }
    else if (strcmp(what, "resize") == 0)    { case_resize(); }
    else { printf("usage: unit <blank|triangle|threshold|resize>\n"); return 2; }

    printf("%s\n", fails ? "some checks failed" : "all checks passed");
    return fails ? 1 : 0;
}
