/* 算法の答をそのまま出す。
 *
 * この実行ファイルは3つの三つ組へ組める。どこで走らせても同じ行が
 * 出るはずであり、それを外から比べられるように、出すのは数だけに
 * してある（版も機械名も混ぜない）。 */
#include "dsp/dsp.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define N 256

static int16_t in[N];
static int16_t out[N];

static void run(void)
{
    dsp_state s;

    dsp_signal(in, N);
    dsp_reset(&s);
    dsp_run(&dsp_lowpass, &s, in, out, N);
}

int main(int argc, char **argv)
{
    const char *what = (argc > 1) ? argv[1] : "sums";

    run();

    if (strcmp(what, "sums") == 0) {
        printf("in=%08x out=%08x rough_in=%u rough_out=%u\n",
               dsp_crc32_samples(in, N), dsp_crc32_samples(out, N),
               dsp_roughness(in, N), dsp_roughness(out, N));
        return 0;
    }
    if (strcmp(what, "samples") == 0) {
        /* 標本そのもの。答が違ったときに、どこから違うのかを見る。 */
        long i, k = (argc > 2) ? strtol(argv[2], NULL, 10) : 8;

        if (k < 0 || k > N) {
            k = N;
        }
        for (i = 0; i < k; i++) {
            printf("%ld %d %d\n", i, in[i], out[i]);
        }
        return 0;
    }
    if (strcmp(what, "width") == 0) {
        /* 機械の語長。三つ組が本当に変わっていることの証であり、
         * それでも上の答は変わらないことの対照になる。 */
        printf("long=%zu ptr=%zu\n", sizeof(long), sizeof(void *));
        return 0;
    }
    fprintf(stderr, "dsp: unknown command: %s\n", what);
    return 2;
}
