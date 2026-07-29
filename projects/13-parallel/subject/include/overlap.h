/* 同時に走っているかどうかを、テスト自身に観測させる。
   時間の閾値ではなく、他のテストが同時に居たという事実で判定する。

   各テストは自分の印を置き、少し待ち、その時点で見えた印の数を記録し、
   自分の印を消す。逐次なら常に1、並列なら2以上が現れる。 */
#ifndef OVERLAP_H
#define OVERLAP_H

#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static int overlap_count(const char *dir)
{
    DIR *d = opendir(dir);
    int n = 0;
    struct dirent *e;
    if (!d) return -1;
    while ((e = readdir(d)) != NULL)
        if (strstr(e->d_name, ".running") != NULL) n++;
    closedir(d);
    return n;
}

/* 戻り値は同時に見えたテストの数。失敗したら負。 */
static int overlap_observe(const char *dir, const char *name)
{
    char mine[512], seen[512];
    FILE *f;
    int n;

    snprintf(mine, sizeof mine, "%s/%s.running", dir, name);
    f = fopen(mine, "w");
    if (!f) return -1;
    fclose(f);

    /* 他のテストが起動しきるだけの間を置く。逐次ならこの間も1本だけである。 */
    nanosleep(&(struct timespec){0, 400 * 1000 * 1000}, NULL);

    n = overlap_count(dir);
    remove(mine);

    snprintf(seen, sizeof seen, "%s/%s.seen", dir, name);
    f = fopen(seen, "w");
    if (!f) return -1;
    fprintf(f, "%d\n", n);
    fclose(f);
    return n;
}

#endif
