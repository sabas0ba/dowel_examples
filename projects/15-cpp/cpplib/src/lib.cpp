#include <string>
#include <stdexcept>
#include "cpplib.h"

/* 標準ライブラリ。C の driver でリンクすると解決できない。 */
extern "C" int cpplib_len(const char *s) { return (int) std::string(s).size(); }

/* 例外。記号が解決するだけでは足りず、巻き戻しの機構が繋がっていないと
   捕まえられずに abort する。 */
extern "C" int cpplib_throws(int n)
{
    try {
        if (n < 0) throw std::runtime_error("negative");
        return n * 2;
    } catch (const std::runtime_error &) {
        return -1;
    }
}

/* 大域オブジェクトの構築子。C の driver でリンクすると .init_array が
   繋がらず、走らないことがある。書庫の中に居る点も効く。 */
static int g_flag = 0;
namespace {
struct Init { Init() { g_flag = 42; } };
Init g_init;
}
extern "C" int cpplib_ctor_ran(void) { return g_flag; }

extern "C" int cpplib_is_cxx(void)
{
#ifdef __cplusplus
    return 1;
#else
    return 0;
#endif
}
