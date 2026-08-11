/* vis — 描いて、数える。
 *
 * 中身は OpenGL（描画）と OpenCV（画像処理）だが、面は C ABI である。
 * 使う側はどちらのライブラリも知らない。見出しにも現れない。 */
#ifndef VIS_H
#define VIS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define VIS_API __attribute__((visibility("default")))

/* 画像。RGB を1画素3バイトで、行の詰め物なしに持つ。 */
typedef struct vis_image vis_image;

VIS_API void       vis_image_free(vis_image *im);
VIS_API int        vis_image_width(const vis_image *im);
VIS_API int        vis_image_height(const vis_image *im);
/* 0xRRGGBB。範囲外は 0。 */
VIS_API uint32_t   vis_image_pixel(const vis_image *im, int x, int y);

/* 表示を持たない機械で GL の文脈を作り、三角形を1つ描いて読み戻す。
 * 失敗したら NULL。 */
VIS_API vis_image *vis_render_triangle(int w, int h);

/* 何も描かない。背景だけの像。 */
VIS_API vis_image *vis_render_blank(int w, int h);

/* 明るさで2値化し、白い画素の数を返す。負なら失敗。 */
VIS_API long       vis_count_bright(const vis_image *im, int threshold);

/* 拡大縮小した像を返す。 */
VIS_API vis_image *vis_resize(const vis_image *im, int w, int h);

/* 背景の色。描画は必ずこれで塗りつぶしてから始める。 */
#define VIS_BACKGROUND 0x101418u
/* 三角形の色。 */
#define VIS_INK        0xE0E0E0u

#ifdef __cplusplus
}
#endif

#endif
