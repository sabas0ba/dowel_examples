/* 双二次フィルタ、直接形 I。
 *
 * 中間の積は int64_t で持つ。a1 は Q15 で -58283 まで行き、y1 は最大
 * 32767 なので、積は 1.9e9 を超えて int32_t を溢れる。溢れた側は機械に
 * よって畳まれ方が変わるので、**そこで三つ組ごとの差が出る**。
 * 64 ビットで持てば、どの機械でも同じ値になる。 */
#include "dsp/dsp.h"

/* 2次バターワース低域通過、fc/fs = 0.05 を Q15 に丸めたもの。
 *
 *   b = [0.004824, 0.009648, 0.004824]
 *   a = [1, -1.778631, 0.797926]
 *
 * 係数は表に焼いてある。実行時に計算すると libm が要り、ベアメタルの
 * 側で組めなくなる——そして三つ組ごとに丸めが変わりうる。 */
const dsp_biquad dsp_lowpass = {
    158, 316, 158,      /* b0 b1 b2 */
    -58278, 26146,      /* a1 a2 */
};

/* Q15 の積和を切り詰めて int16_t へ収める。 */
static int16_t saturate(int64_t acc)
{
    int64_t v = acc >> DSP_Q;

    if (v > 32767) {
        return (int16_t)32767;
    }
    if (v < -32768) {
        return (int16_t)(-32768);
    }
    return (int16_t)v;
}

void dsp_reset(dsp_state *s)
{
    s->x1 = 0;
    s->x2 = 0;
    s->y1 = 0;
    s->y2 = 0;
}

int16_t dsp_step(const dsp_biquad *c, dsp_state *s, int16_t x)
{
    int64_t acc;
    int16_t y;

    acc  = (int64_t)c->b0 * x;
    acc += (int64_t)c->b1 * s->x1;
    acc += (int64_t)c->b2 * s->x2;
    acc -= (int64_t)c->a1 * s->y1;
    acc -= (int64_t)c->a2 * s->y2;

    y = saturate(acc);

    s->x2 = s->x1;
    s->x1 = x;
    s->y2 = s->y1;
    s->y1 = y;
    return y;
}

void dsp_run(const dsp_biquad *c, dsp_state *s,
             const int16_t *in, int16_t *out, size_t n)
{
    size_t i;

    for (i = 0; i < n; i++) {
        out[i] = dsp_step(c, s, in[i]);
    }
}

void dsp_signal(int16_t *out, size_t n)
{
    size_t i;

    for (i = 0; i < n; i++) {
        /* 緩やかな三角波。周期 64、振れ幅 ±9000。 */
        int32_t phase = (int32_t)(i % 64);
        int32_t tri = (phase < 32) ? (phase * 562 - 9000)
                                   : (9000 - (phase - 32) * 562);
        /* 速い矩形波。周期 4、振れ幅 ±5000。低域通過が落とす側。 */
        int32_t fast = ((i % 4) < 2) ? 5000 : -5000;

        out[i] = (int16_t)(tri + fast);
    }
}

uint32_t dsp_roughness(const int16_t *v, size_t n)
{
    uint32_t sum = 0;
    size_t i;

    for (i = 1; i < n; i++) {
        int32_t d = (int32_t)v[i] - (int32_t)v[i - 1];

        sum += (uint32_t)((d < 0) ? -d : d);
    }
    return sum;
}
