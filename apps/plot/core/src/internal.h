/* 内部の見出し。使う側には渡さない。 */
#ifndef PLOT_INTERNAL_H
#define PLOT_INTERNAL_H

#include "plot/plot.h"

#include <cairo.h>

struct plot_canvas {
    cairo_surface_t *surface;
    cairo_t         *cr;
    int              w, h;
};

/* 0xAARRGGBB を cairo の 0..1 の三つ組へ。 */
void pl_set_source(cairo_t *cr, uint32_t argb);

#endif
