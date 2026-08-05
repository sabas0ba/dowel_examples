/* 実行ファイルが本当に繋がっていることを、見出し越しに確かめる。
 * 引数の解釈そのものは expect.sh が実物を走らせて見る。 */
#include "json/json.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void)
{
    char  *out = NULL;
    size_t len = 0;

    if (json_format("[1]", 3, 0, &out, &len) != JSON_OK) {
        puts("FAIL: the library did not link into the cli package");
        return 1;
    }
    if (strcmp(out, "[1]\n") != 0) {
        printf("FAIL: got %s", out);
        free(out);
        return 1;
    }
    free(out);
    return 0;
}
