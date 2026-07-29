#include "parts.h"

int main(void)
{
    if (c_part() != 1) return 1;    /* C 側が C として翻訳された */
    if (cxx_part() != 3) return 2;  /* C++ 側が動く */
    return 0;
}
