#include "internal.h"

/* 表を持つ版と、都度計算する版。記憶の小さい対象では後者を選ぶ。
 * 答は同じでなければならない——それは検査で確かめる。 */
#ifdef HASHX_SMALL_TABLE

uint32_t hx_crc_step(uint32_t state, unsigned char byte)
{
    int k;

    state ^= byte;
    for (k = 0; k < 8; k++) {
        state = (state >> 1) ^ (0xEDB88320u & (uint32_t)(-(int32_t)(state & 1)));
    }
    return state;
}

#else

static uint32_t table[256];
static int      ready;

static void build(void)
{
    uint32_t i;

    for (i = 0; i < 256; i++) {
        uint32_t c = i;
        int k;
        for (k = 0; k < 8; k++) {
            c = (c >> 1) ^ (0xEDB88320u & (uint32_t)(-(int32_t)(c & 1)));
        }
        table[i] = c;
    }
    ready = 1;
}

uint32_t hx_crc_step(uint32_t state, unsigned char byte)
{
    if (!ready) {
        build();
    }
    return table[(state ^ byte) & 0xFFu] ^ (state >> 8);
}

#endif

void hashx_crc_begin(hashx_crc *h)
{
    h->state = 0xFFFFFFFFu;
}

void hashx_crc_feed(hashx_crc *h, const void *data, size_t len)
{
    const unsigned char *p = (const unsigned char *)data;
    size_t i;

    for (i = 0; i < len; i++) {
        h->state = hx_crc_step(h->state, p[i]);
    }
}

uint32_t hashx_crc_end(const hashx_crc *h)
{
    return h->state ^ 0xFFFFFFFFu;
}

uint32_t hashx_crc32(const void *data, size_t len)
{
    hashx_crc h;

    hashx_crc_begin(&h);
    hashx_crc_feed(&h, data, len);
    return hashx_crc_end(&h);
}
