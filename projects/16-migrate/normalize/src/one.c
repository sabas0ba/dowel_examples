#include "one.h"

int one_value(void) { return A; }

int main(void)
{
    return one_value() + two_value() == 3 ? 0 : 1;
}
