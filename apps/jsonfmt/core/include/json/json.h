/* jsonfmt の公開見出し。使う側が要るのはこの1枚だけである。 */
#ifndef JSON_JSON_H
#define JSON_JSON_H

#include <stddef.h>

typedef enum {
    JSON_OK = 0,
    JSON_ERR_SYNTAX,
    JSON_ERR_DEPTH,
    JSON_ERR_MEMORY
} json_status;

/* 整形した結果を新しく確保した文字列で返す。呼び出し側が free する。
 * indent が 0 なら1行に詰める。 */
json_status json_format(const char *text, size_t len, int indent,
                        char **out, size_t *out_len);

/* 診断のための位置。json_format が JSON_ERR_SYNTAX を返したときだけ意味を持つ。 */
size_t json_error_offset(void);

const char *json_status_text(json_status s);

/* 構成で決まる上限。使う側が自分の入力と突き合わせられるように公開する。 */
int json_max_depth(void);

#endif
