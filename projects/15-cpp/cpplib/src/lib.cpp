#include <string>
#include "cpplib.h"

/* std::string を使う。C の driver でリンクすると解決できない。 */
extern "C" int cpplib_len(const char *s) { return (int) std::string(s).size(); }

extern "C" int cpplib_is_cxx(void)
{
#ifdef __cplusplus
    return 1;
#else
    return 0;
#endif
}
