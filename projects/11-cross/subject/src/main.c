#include <stdio.h>
#include "arch.h"

int main(void)
{
    printf("%s %d\n", ARCH_NAME, PTR_BITS);
    return 0;
}
