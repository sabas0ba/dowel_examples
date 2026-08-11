/* 実機（の代わりの qemu）で走る検査。
 *
 * 読む期待値は tests/golden.h であり、**ホスト向けの検査と同じ1枚**で
 * ある。libc が無いので実体は別になるが、突き合わせる数は同じでなければ
 * ならない。別の値を持たせた瞬間、「どの三つ組でも同じ答が出る」は
 * 検査ではなくなる。 */
#include "fw.h"

#include "dsp/dsp.h"
#include "golden.h"

/* 静的に置く。.bss に載るので、起動コードがゼロ埋めしていなければ
 * ここで答が変わる——つまりこの検査は起動コードも見ている。 */
static int16_t in[GOLDEN_N];
static int16_t out[GOLDEN_N];

static int check(const char *what, uint32_t got, uint32_t want)
{
    if (got == want) {
        return 0;
    }
    fw_say("onhw: ");
    fw_say(what);
    fw_say(": got ");
    fw_say_hex(got);
    fw_say(" want ");
    fw_say_hex(want);
    fw_say("\n");
    return 1;
}

int fw_main(void);

int fw_main(void)
{
    dsp_state s;
    int bad = 0;

    dsp_signal(in, GOLDEN_N);
    dsp_reset(&s);
    dsp_run(&dsp_lowpass, &s, in, out, GOLDEN_N);

    bad |= check("input crc",      dsp_crc32_samples(in, GOLDEN_N),  GOLDEN_IN_CRC);
    bad |= check("output crc",     dsp_crc32_samples(out, GOLDEN_N), GOLDEN_OUT_CRC);
    bad |= check("input rough",    dsp_roughness(in, GOLDEN_N),      GOLDEN_IN_ROUGH);
    bad |= check("output rough",   dsp_roughness(out, GOLDEN_N),     GOLDEN_OUT_ROUGH);

    if (bad == 0) {
        /* 走ったことの証。qemu の出力に現れる。 */
        fw_say("onhw: the same answers on bare metal\n");
    }
    return bad;
}
