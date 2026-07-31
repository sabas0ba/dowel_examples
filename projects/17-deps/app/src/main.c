#include <demokit.h>
#include <stdio.h>
#include <stdlib.h>

/* --cflags が翻訳に届かなければ、ここで止まる。リンカの誤りを待たない。 */
#ifndef DEMOKIT
#error "the module's --cflags did not reach the compile"
#endif

int main(int argc, char **argv)
{
    /* 実行時の値を渡す。定数だと畳み込まれ、-lm を要さなくなる。 */
    double x = argc > 1 ? atof(argv[1]) : 1764.0;
    printf("%d %d\n", DEMOKIT_ANSWER, (int) demokit_root(x));
    return 0;
}
