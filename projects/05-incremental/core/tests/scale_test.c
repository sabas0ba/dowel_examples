/* Exit status 0 means success. There is no test harness. */
#include "core.h"

int main(void) { return core_scale(3) == 3 * CORE_SCALE ? 0 : 1; }
