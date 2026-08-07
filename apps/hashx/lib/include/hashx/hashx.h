/* hashx — 配ることを前提にしたハッシュのライブラリ。
 *
 * この見出し1枚が公開する面のすべてである。`src/` の中は渡さない。
 * C からも C++ からも呼べる。名前の飾りが付かないよう `extern "C"` で
 * 囲み、公開する記号にだけ既定の可視性を与える。 */
#ifndef HASHX_H
#define HASHX_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 版。`dowel.toml` の version と一致していなければならないが、
 * マニフェストの値をここへ届ける手立てが無いため手で写している
 * （docs/10-findings.md F-030）。 */
#define HASHX_VERSION "0.4.0"

/* 翻訳単位の外へ出す記号は、これを付けたものだけである。
 * それ以外は -fvisibility=hidden により隠れる。 */
#define HASHX_API __attribute__((visibility("default")))

/* 一度に渡すとき。 */
HASHX_API uint32_t hashx_fnv1a(const void *data, size_t len);
HASHX_API uint32_t hashx_crc32(const void *data, size_t len);

/* 少しずつ渡すとき。中身は利用者が触ってよいものではないが、
 * 大きさを知る必要があるため見えている。 */
typedef struct {
    uint32_t state;
} hashx_crc;

HASHX_API void     hashx_crc_begin(hashx_crc *h);
HASHX_API void     hashx_crc_feed(hashx_crc *h, const void *data, size_t len);
HASHX_API uint32_t hashx_crc_end(const hashx_crc *h);

/* 組み込まれた版。見出しの HASHX_VERSION と一致する。 */
HASHX_API const char *hashx_version(void);

#ifdef __cplusplus
}
#endif

#endif
