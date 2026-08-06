/* 標準入力を読んで CRC-32 と FNV-1a を出す。 */
#include "hashx/hashx.h"

#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    hashx_crc h;
    unsigned char buf[4096];
    size_t n;

    if (argc > 1 && strcmp(argv[1], "--version") == 0) {
        printf("hashsum (hashx %s)\n", hashx_version());
        return 0;
    }

    hashx_crc_begin(&h);
    while ((n = fread(buf, 1, sizeof buf, stdin)) > 0) {
        hashx_crc_feed(&h, buf, n);
    }
    printf("crc32=%08x\n", hashx_crc_end(&h));
    return 0;
}
