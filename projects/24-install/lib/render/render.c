#include "include/render.h"
#include "shapes.h"

double render_ratio(double r) { return shapes_area(r) / shapes_perimeter(r); }
