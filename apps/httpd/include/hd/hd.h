/* httpd の公開見出し。 */
#ifndef HD_HD_H
#define HD_HD_H

#include <stddef.h>

/* 要求行を解析した結果。本文は扱わない（静的ファイルしか返さないため）。 */
typedef struct {
    char method[8];
    char path[512];
    int  keep_alive;
} hd_request;

/* 解析。戻り値は消費したバイト数、0 なら未完（もっと読む）、負なら誤り。 */
long hd_parse_request(const char *buf, size_t len, hd_request *out);

/* パスを実際のファイルへ落とす。`..` と絶対パスは拒む。
 * 成功なら 0、拒んだら -1。 */
int hd_resolve(const char *root, const char *path, char *out, size_t out_len);

const char *hd_mime_for(const char *path);

/* 待ち方の名前。どの実装が翻訳されたかを成果物自身に名乗らせる。 */
const char *hd_waiter_name(void);

/* 待ち方の実装。fd を1つ見張り、読めるようになるまで待つ。 */
int hd_wait_readable(int fd, int timeout_ms);

/* 1 接続ぶんを処理する。root の下のファイルだけを返す。 */
int hd_serve_connection(int fd, const char *root);

/* スレッドを使う版かどうか。構成が成果物に届いたかを外から読む。 */
int hd_uses_threads(void);

#endif
