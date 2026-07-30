#include "xlib.h"

int main(void)
{
    if (xlib_len("abcd") != 4) return 1;
    if (xlib_bits() != 64) return 2;
    return 0;
}
