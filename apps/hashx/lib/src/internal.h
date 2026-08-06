/* 内部の見出し。利用者には渡さない（`private` の includes にだけ入れる）。 */
#ifndef HASHX_INTERNAL_H
#define HASHX_INTERNAL_H

#include "hashx/hashx.h"

/* 翻訳単位を跨ぐ内部の名前は `hx_` で始める。公開する `hashx_` と
 * 見た目で区別が付き、成果物の側でも機械的に選り分けられる。 */
uint32_t hx_crc_step(uint32_t state, unsigned char byte);

#endif
