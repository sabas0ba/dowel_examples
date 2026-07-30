#include <string>
#include "xlib.h"

extern "C" int xlib_len(const char *s) { return (int) std::string(s).size(); }

/* 翻訳先が本当に変わったかは、名前ではなく実体に効くもので見る。 */
extern "C" int xlib_bits(void) { return 8 * (int) sizeof(void *); }
