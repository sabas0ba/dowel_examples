/* 1本で複数の事例を演じる。事例を分けるのは引数だけである（ADR-0022）。
 *
 * 引数で振る舞いを選ぶのは、`cases` が「同じ実行ファイルの別の起動」で
 * あることをそのまま写した形である。試験フレームワークは使わない。
 * dowel はハーネスの規約を採らないので、こちらも採らない。 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    const char *what = argc > 1 ? argv[1] : "(none)";
    int i;

    printf("case=%s argc=%d\n", what, argc);
    for (i = 0; i < argc; i++) {
        printf("  argv[%d]=%s\n", i, argv[i]);
    }
    {
        char b[4096];
        if (getcwd(b, sizeof b) != NULL) {
            printf("cwd=%s\n", b);
        }
    }
    fflush(stdout);

    if (strcmp(what, "fail") == 0)  { return 3; }
    if (strcmp(what, "crash") == 0) { *(volatile int *)0 = 1; }
    if (strcmp(what, "hang") == 0)  { for (;;) { sleep(1); } }
    if (strncmp(what, "sleep", 5) == 0) { sleep(atoi(what + 5)); return 0; }
    if (strcmp(what, "env") == 0) {
        const char *m = getenv("SUITE_MODE");
        printf("SUITE_MODE=%s\n", m ? m : "(unset)");
        return (m != NULL && strcmp(m, "strict") == 0) ? 0 : 1;
    }
    if (strcmp(what, "openrun") == 0) {
        FILE *f = fopen("run/mark", "w");     /* 作業ディレクトリ次第 */
        if (f == NULL) { return 4; }
        fclose(f);
        return 0;
    }
    return 0;
}
