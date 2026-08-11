/* 測られる側。引数で仕事の量を変える。
 *
 * 測るのは過程の実時間なので、この実体は自分の時間を計らない。計ったと
 * しても dowel は読まない——それが「枠組みを課さない」ことの意味である。 */
#include <string.h>

static long work(long n)
{
    volatile long s = 0;
    long i;

    for (i = 0; i < n; i++) {
        s += i;
    }
    return s;
}

int main(int argc, char **argv)
{
    const char *what = (argc > 1) ? argv[1] : "small";

    if (strcmp(what, "small") == 0) { work(200000L);    return 0; }
    if (strcmp(what, "big")   == 0) { work(4000000L);   return 0; }
    if (strcmp(what, "slow")  == 0) { work(20000000L);  return 0; }
    if (strcmp(what, "boom")  == 0) { return 3; }        /* 走り切れない */
    if (strcmp(what, "hang")  == 0) { for (;;) { }  }    /* 止まらない */
    return 2;
}
