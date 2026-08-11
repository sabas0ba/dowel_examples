/* 算法の検査。**この1本がすべてのホスト付き三つ組で走る。**
 *
 *   dowel test                                          x86_64（手元）
 *   dowel test --target=aarch64-unknown-linux-gnu       ARM
 *   dowel test --target=riscv64gc-unknown-linux-gnu     RISC-V
 *
 * ソースも期待値も1つである。三つ組ごとに分けた瞬間、「同じ答が出る」
 * という主張は検査できなくなる。 */
#include "dsp/dsp.h"
#include "golden.h"

#include <stdio.h>
#include <string.h>

static int16_t in[GOLDEN_N];
static int16_t out[GOLDEN_N];

static int fail(const char *what, unsigned long got, unsigned long want)
{
    fprintf(stderr, "vectors: %s: got %lu (0x%lX), want %lu (0x%lX)\n",
            what, got, got, want, want);
    return 1;
}

static void prepare(void)
{
    dsp_state s;

    dsp_signal(in, GOLDEN_N);
    dsp_reset(&s);
    dsp_run(&dsp_lowpass, &s, in, out, GOLDEN_N);
}

/* 波の生成が揃っていること。ここが違えばフィルタを見る意味が無い。 */
static int case_signal(void)
{
    uint32_t crc;

    prepare();
    crc = dsp_crc32_samples(in, GOLDEN_N);
    if (crc != GOLDEN_IN_CRC) {
        return fail("input crc", crc, GOLDEN_IN_CRC);
    }
    return 0;
}

/* 通したあとが1標本まで揃っていること。この検査が本体である。 */
static int case_filter(void)
{
    uint32_t crc;

    prepare();
    crc = dsp_crc32_samples(out, GOLDEN_N);
    if (crc != GOLDEN_OUT_CRC) {
        return fail("output crc", crc, GOLDEN_OUT_CRC);
    }
    return 0;
}

/* 平滑化が効いていること。CRC は「違う」しか言わないので、
 * どちらへ違うのかを見る量を別に持つ。 */
static int case_smooth(void)
{
    uint32_t a, b;

    prepare();
    a = dsp_roughness(in, GOLDEN_N);
    b = dsp_roughness(out, GOLDEN_N);
    if (a != GOLDEN_IN_ROUGH) {
        return fail("input roughness", a, GOLDEN_IN_ROUGH);
    }
    if (b != GOLDEN_OUT_ROUGH) {
        return fail("output roughness", b, GOLDEN_OUT_ROUGH);
    }
    if (b >= a) {
        return fail("output is not smoother than input", b, a);
    }
    return 0;
}

/* 桁あふれの縁。a1 * y1 は int32_t を溢れるので、64 ビットで持って
 * いなければここで三つ組ごとの差が出る。振り切った入力を通す。 */
static int case_saturate(void)
{
    dsp_state s;
    int16_t x[64], y[64];
    size_t i;

    for (i = 0; i < 64; i++) {
        x[i] = (int16_t)((i % 2) ? 32767 : -32768);
    }
    dsp_reset(&s);
    dsp_run(&dsp_lowpass, &s, x, y, 64);

    /* 飽和して収まっていること。int16_t の範囲を出ないのは型が保証する
     * ので、見るのは「暴れていない」こと——低域通過に全振幅の交番を
     * 入れれば、出力は小さく収まる。 */
    for (i = 0; i < 64; i++) {
        if (y[i] > GOLDEN_SAT_PEAK || y[i] < -GOLDEN_SAT_PEAK) {
            return fail("saturating input leaked through", (unsigned long)(long)y[i], GOLDEN_SAT_PEAK);
        }
    }
    return 0;
}

/* 標本ごとに通しても、まとめて通しても同じであること。
 * 状態の持ち回りが壊れていれば、ここだけが落ちる。 */
static int case_stream(void)
{
    dsp_state s;
    int16_t one[GOLDEN_N];
    size_t i;

    prepare();
    dsp_reset(&s);
    for (i = 0; i < GOLDEN_N; i++) {
        one[i] = dsp_step(&dsp_lowpass, &s, in[i]);
    }
    if (memcmp(one, out, sizeof one) != 0) {
        return fail("stepping one sample at a time differs from running the block", 1, 0);
    }
    return 0;
}

int main(int argc, char **argv)
{
    const char *which = (argc > 1) ? argv[1] : "";

    if (strcmp(which, "signal")   == 0) return case_signal();
    if (strcmp(which, "filter")   == 0) return case_filter();
    if (strcmp(which, "smooth")   == 0) return case_smooth();
    if (strcmp(which, "saturate") == 0) return case_saturate();
    if (strcmp(which, "stream")   == 0) return case_stream();
    fprintf(stderr, "vectors: no such case: %s\n", which);
    return 2;
}
