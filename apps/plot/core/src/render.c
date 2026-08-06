#include "internal.h"

void pl_set_source(cairo_t *cr, uint32_t argb)
{
    cairo_set_source_rgba(cr,
                          ((argb >> 16) & 0xFFu) / 255.0,
                          ((argb >> 8)  & 0xFFu) / 255.0,
                          ( argb        & 0xFFu) / 255.0,
                          ((argb >> 24) & 0xFFu) / 255.0);
}

void plot_draw(plot_canvas *c, const double *ys, size_t n)
{
    double lo, hi, span;
    size_t i;

    if (c == NULL) {
        return;
    }

    /* 背景。単色で塗るため、どの画素も厳密にこの値になる。 */
    pl_set_source(c->cr, PLOT_BACKGROUND);
    cairo_set_operator(c->cr, CAIRO_OPERATOR_SOURCE);
    cairo_paint(c->cr);
    cairo_set_operator(c->cr, CAIRO_OPERATOR_OVER);

    if (ys == NULL || n < 2) {
        cairo_surface_flush(c->surface);
        return;
    }

    lo = hi = ys[0];
    for (i = 1; i < n; i++) {
        if (ys[i] < lo) { lo = ys[i]; }
        if (ys[i] > hi) { hi = ys[i]; }
    }
    span = hi - lo;
    if (span <= 0.0) {
        span = 1.0;
    }

    pl_set_source(c->cr, PLOT_INK);
    cairo_set_line_width(c->cr, 2.0);
    for (i = 0; i < n; i++) {
        double x = (double)i * (double)(c->w - 1) / (double)(n - 1);
        double y = (double)(c->h - 1)
                 - (ys[i] - lo) / span * (double)(c->h - 1);
        if (i == 0) {
            cairo_move_to(c->cr, x, y);
        } else {
            cairo_line_to(c->cr, x, y);
        }
    }
    cairo_stroke(c->cr);
    cairo_surface_flush(c->surface);
}
