/* 既知の答で固定する。ハッシュは値が合っていることが全てである。 */
#include "hashx/hashx.h"
#include "internal.h"

#include <stdio.h>
#include <string.h>

static int fails;

static void eq(uint32_t got, uint32_t want, const char *what)
{
    if (got != want) {
        printf("FAIL %s: want 0x%08x got 0x%08x\n", what, want, got);
        fails++;
    }
}

int main(void)
{
    hashx_crc h;

    /* 既知のベクタ。"123456789" の CRC-32 は 0xCBF43926 である。 */
    eq(hashx_crc32("123456789", 9), 0xCBF43926u, "crc32 of 123456789");
    eq(hashx_crc32("", 0), 0x00000000u, "crc32 of the empty string");
    eq(hashx_fnv1a("abc", 3), 0x1A47E90Bu, "fnv1a of abc");
    eq(hashx_fnv1a("", 0), 0x811C9DC5u, "fnv1a of the empty string");

    /* 少しずつ渡しても答は変わらない。 */
    hashx_crc_begin(&h);
    hashx_crc_feed(&h, "1234", 4);
    hashx_crc_feed(&h, "56789", 5);
    eq(hashx_crc_end(&h), 0xCBF43926u, "crc32 fed in two pieces");

    /* 版は見出しの値と一致する。 */
    if (strcmp(hashx_version(), HASHX_VERSION) != 0) {
        printf("FAIL version: want %s got %s\n", HASHX_VERSION, hashx_version());
        fails++;
    }

    /* 内部の名前も、内側からは呼べる。 */
    eq(hx_crc_step(0xFFFFFFFFu, '1') != 0, 1, "the internal step is reachable from inside");

    printf("%s\n", fails ? "some checks failed" : "all checks passed");
    return fails ? 1 : 0;
}
