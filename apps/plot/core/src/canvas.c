#include "internal.h"

#include <stdlib.h>

plot_canvas *plot_canvas_new(int w, int h)
{
    plot_canvas *c;

    if (w <= 0 || h <= 0) {
        return NULL;
    }
    c = calloc(1, sizeof *c);
    if (c == NULL) {
        return NULL;
    }
    c->w = w;
    c->h = h;
    c->surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    if (cairo_surface_status(c->surface) != CAIRO_STATUS_SUCCESS) {
        plot_canvas_free(c);
        return NULL;
    }
    c->cr = cairo_create(c->surface);
    if (cairo_status(c->cr) != CAIRO_STATUS_SUCCESS) {
        plot_canvas_free(c);
        return NULL;
    }
    return c;
}

void plot_canvas_free(plot_canvas *c)
{
    if (c == NULL) {
        return;
    }
    if (c->cr != NULL) {
        cairo_destroy(c->cr);
    }
    if (c->surface != NULL) {
        cairo_surface_destroy(c->surface);
    }
    free(c);
}

int plot_canvas_width(const plot_canvas *c)  { return c ? c->w : 0; }
int plot_canvas_height(const plot_canvas *c) { return c ? c->h : 0; }

const unsigned char *plot_canvas_pixels(const plot_canvas *c)
{
    if (c == NULL) {
        return NULL;
    }
    cairo_surface_flush(c->surface);
    return cairo_image_surface_get_data(c->surface);
}

int plot_canvas_stride(const plot_canvas *c)
{
    return c ? cairo_image_surface_get_stride(c->surface) : 0;
}

uint32_t plot_pixel(const plot_canvas *c, int x, int y)
{
    const unsigned char *p;
    int stride;

    if (c == NULL || x < 0 || y < 0 || x >= c->w || y >= c->h) {
        return 0;
    }
    p = plot_canvas_pixels(c);
    stride = plot_canvas_stride(c);
    if (p == NULL || stride <= 0) {
        return 0;
    }
    p += (size_t)y * (size_t)stride + (size_t)x * 4u;
    /* 記憶の上の並びは B G R A である。 */
    return ((uint32_t)p[3] << 24) | ((uint32_t)p[2] << 16)
         | ((uint32_t)p[1] << 8)  |  (uint32_t)p[0];
}
