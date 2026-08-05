/* core の単体テスト。内部の見出しにも触れるため src/ を includes に足してある。 */
#include "json/json.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;

static void expect_format(const char *in, int indent, const char *want)
{
    char  *out = NULL;
    size_t len = 0;
    json_status st = json_format(in, strlen(in), indent, &out, &len);

    if (st != JSON_OK) {
        printf("FAIL %s -> %s\n", in, json_status_text(st));
        failures++;
        return;
    }
    if (strcmp(out, want) != 0) {
        printf("FAIL %s\n  want: %s  got: %s", in, want, out);
        failures++;
    }
    free(out);
}

static void expect_error(const char *in, json_status want)
{
    char  *out = NULL;
    size_t len = 0;
    json_status st = json_format(in, strlen(in), 2, &out, &len);

    if (st != want) {
        printf("FAIL %s -> %s (wanted %s)\n",
               in, json_status_text(st), json_status_text(want));
        failures++;
        free(out);
    }
}

int main(void)
{
    expect_format("{}", 2, "{}\n");
    expect_format("[]", 2, "[]\n");
    expect_format("  17  ", 2, "17\n");
    expect_format("\"a\\\"b\"", 2, "\"a\\\"b\"\n");
    expect_format("{\"a\":1}", 0, "{\"a\":1}\n");
    expect_format("[1,2]", 0, "[1,2]\n");
    expect_format("{\"a\":1}", 2, "{\n  \"a\": 1\n}\n");
    expect_format("[1,[2]]", 2, "[\n  1,\n  [\n    2\n  ]\n]\n");

    expect_error("{", JSON_ERR_SYNTAX);
    expect_error("[1,]", JSON_ERR_SYNTAX);
    expect_error("{\"a\" 1}", JSON_ERR_SYNTAX);
    expect_error("\"unterminated", JSON_ERR_SYNTAX);
    expect_error("{} trailing", JSON_ERR_SYNTAX);

    /* 上限は構成で決まる。機能フラグを立てた版では 4096 になる。 */
    {
        int depth = json_max_depth();
        char *deep = malloc((size_t) depth * 2 + 16);
        int i;
        for (i = 0; i < depth + 1; i++) {
            deep[i] = '[';
        }
        deep[depth + 1] = '\0';
        expect_error(deep, JSON_ERR_DEPTH);
        free(deep);
    }

    if (failures != 0) {
        printf("%d failures\n", failures);
        return 1;
    }
    return 0;
}
