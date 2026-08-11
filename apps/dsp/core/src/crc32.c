/* CRC-32（多項式 0xEDB88320）。答を三つ組の間で比べるために使う。
 *
 * 表を持たずに桁ごとに回す。表を持つと 1KiB の .rodata が要り、
 * ベアメタルの側で置き場所を考えることになる。速さは要らない。 */
#include "dsp/dsp.h"

uint32_t dsp_crc32(const void *data, size_t len)
{
    const uint8_t *p = (const uint8_t *)data;
    uint32_t crc = 0xFFFFFFFFu;
    size_t i;
    int bit;

    for (i = 0; i < len; i++) {
        crc ^= p[i];
        for (bit = 0; bit < 8; bit++) {
            /* 符号なしで回す。符号つきの右シフトは負の値で実装定義に
             * なり、そこが三つ組ごとの差になりうる。 */
            crc = (crc >> 1) ^ (0xEDB88320u & (uint32_t)(-(int32_t)(crc & 1u)));
        }
    }
    return crc ^ 0xFFFFFFFFu;
}

uint32_t dsp_crc32_samples(const int16_t *v, size_t n)
{
    uint32_t crc = 0xFFFFFFFFu;
    size_t i;
    int bit, half;

    for (i = 0; i < n; i++) {
        /* 下位バイトから。記憶の並びを読まず、値から作る。 */
        uint16_t u = (uint16_t)v[i];

        for (half = 0; half < 2; half++) {
            crc ^= (uint32_t)((u >> (8 * half)) & 0xFFu);
            for (bit = 0; bit < 8; bit++) {
                crc = (crc >> 1) ^ (0xEDB88320u & (uint32_t)(-(int32_t)(crc & 1u)));
            }
        }
    }
    return crc ^ 0xFFFFFFFFu;
}
