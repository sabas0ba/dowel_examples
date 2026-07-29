#include "overlap.h"

int main(void)
{
    return overlap_observe(RUN_DIR, "t2") < 0 ? 1 : 0;
}
