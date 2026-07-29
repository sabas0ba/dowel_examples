#include "cpplib.h"

/* この翻訳単位は C である。__cplusplus は定義されない。 */
int main(void)
{
#ifdef __cplusplus
    return 2;
#endif
    if (cpplib_len("abcd") != 4) return 1;
    if (!cpplib_is_cxx()) return 3;
    return 0;
}
