#include "shapes.h"
#include <math.h>

double shapes_area(double r)      { return M_PI * r * r; }
double shapes_perimeter(double r) { return 2.0 * M_PI * r; }
