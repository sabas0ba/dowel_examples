#include "greet.h"

int main(void)
{
    if (greet_value() != 3) return 1;
    if (extra_value() != 1) return 2;
    if (DEMO_MODE != 1) return 3;
    return 0;
}
