/* 固定小数の信号処理。
 *
 * この見出しは**どの三つ組でも同じもの**である。含むのは <stdint.h> と
 * <stddef.h> だけで、どちらも freestanding の実装が備えることを規格が
 * 求めている。libc の在る機械でも、無い機械でも同じように読める。
 *
 * 演算は整数だけで書いてある。浮動小数を使うと、同じ式でも機械によって
 * 丸めが変わりうる——答が「だいたい合っている」になった瞬間、複数の
 * 三つ組で**同じ答が出ること**を検査にできなくなる。 */
#ifndef DSP_DSP_H
#define DSP_DSP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 係数と状態の小数点位置。1.0 は 1 << DSP_Q である。 */
#define DSP_Q 15

/* 双二次フィルタの係数。すべて Q15。 */
typedef struct {
    int32_t b0, b1, b2;
    int32_t a1, a2;
} dsp_biquad;

/* 直接形 I の状態。入力2つ、出力2つを憶える。 */
typedef struct {
    int32_t x1, x2;
    int32_t y1, y2;
} dsp_state;

/* 固定の低域通過（2次バターワース、fc/fs = 0.05）。
 * 係数を固定してあるのは、答を三つ組の間で比べるためである。 */
extern const dsp_biquad dsp_lowpass;

/* 状態を初期化する。 */
void dsp_reset(dsp_state *s);

/* 標本を1つ通す。飽和して返す。 */
int16_t dsp_step(const dsp_biquad *c, dsp_state *s, int16_t x);

/* 列を通す。in と out は重なってよい。 */
void dsp_run(const dsp_biquad *c, dsp_state *s,
             const int16_t *in, int16_t *out, size_t n);

/* 決まった試験波を作る。緩やかな三角波に、速い矩形波を重ねたもの。
 * 低域通過は後者だけを落とすので、効いたかどうかが数で見える。 */
void dsp_signal(int16_t *out, size_t n);

/* 列の振れ幅の総和。標本ごとの差の絶対値を足したもの。
 * 平滑化が効けば減る量であり、飽和や桁あふれでは増える。 */
uint32_t dsp_roughness(const int16_t *v, size_t n);

/* 生の八重奏の列を畳む（CRC-32、多項式 0xEDB88320）。 */
uint32_t dsp_crc32(const void *data, size_t len);

/* 標本の列を畳む。**各標本を明示的に下位バイトから**入れるので、
 * 答は機械の内部表現に依らない。
 *
 * `dsp_crc32(v, n * 2)` で済ませてはならない。それは記憶の中の並びを
 * そのまま読むので、大小の端が違う機械では違う値になる。いま相手にする
 * 4つの三つ組はすべて小端だが、**たまたま揃っているだけ**のものを検査の
 * 土台にすると、揃わなくなった日に「算法が違う」と読めてしまう。 */
uint32_t dsp_crc32_samples(const int16_t *v, size_t n);

#ifdef __cplusplus
}
#endif

#endif
