/* 事例をコードの側に持つスイート。ハーネスの規約は dowel が知るのではなく、
 * マニフェストが宣言する（ADR-0023）。--list で1行1件を書き出し、
 * --run <名前> でその1件だけ走る。 */
#include <stdio.h>
#include <string.h>

static int alpha(void) { return 0; }
static int beta(void)  { return 0; }
static int gamma_(void) { return 0; }

int main(int argc, char **argv)
{
    if (argc >= 2 && strcmp(argv[1], "--list") == 0) {
        puts("# a comment line, skipped by the reader");
        puts("alpha");
        puts("");
        puts("beta");
        puts("gamma");
        return 0;
    }
    if (argc >= 3 && strcmp(argv[1], "--run") == 0) {
        if (strcmp(argv[2], "alpha") == 0) { return alpha(); }
        if (strcmp(argv[2], "beta") == 0)  { return beta(); }
        if (strcmp(argv[2], "gamma") == 0) { return gamma_(); }
        fprintf(stderr, "no such case: %s\n", argv[2]);
        return 99;
    }
    return 98;
}
