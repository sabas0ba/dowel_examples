#include <stdlib.h>

int mid_value(double);

/* demokit.h は読まない。mid の実装の都合であり、top には見えないはず。 */
int main(int argc, char **argv)
{
    double x = argc > 1 ? atof(argv[1]) : 4.0;
    return mid_value(x) == 44 ? 0 : 1;
}
