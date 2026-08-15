/* dowel を知らない使う側。pkg-config が刷る引数だけで組む。
 *
 * ライブラリを配るとはこういうことである——相手のビルドシステムは
 * CMake かも Meson かも Makefile かもしれず、dowel は入っていない。 */
#include <hashx/hashx.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    const char *s = "dowel";
    hashx_crc h;

    hashx_crc_begin(&h);
    hashx_crc_feed(&h, s, strlen(s));

    printf("%08x %08x %08x %s\n",
           hashx_fnv1a(s, strlen(s)),
           hashx_crc32(s, strlen(s)),
           hashx_crc_end(&h),
           hashx_version());
    return 0;
}
