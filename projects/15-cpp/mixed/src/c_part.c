#include "parts.h"

/* .c は C の driver へ渡る。ここで __cplusplus が定義されていたら、
   拡張子による選択が効いていない。 */
int c_part(void)
{
#ifdef __cplusplus
    return 0;
#else
    return 1;
#endif
}
