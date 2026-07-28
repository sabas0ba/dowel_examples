#include <stdio.h>

#include "core.h"

int main(void) {
    printf("scale=%d offset=%d\n", core_scale(3), core_offset());
    return 0;
}
