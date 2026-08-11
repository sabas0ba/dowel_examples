/* 描いて、数えて、答を1行で出す。 */
#include "vis/vis.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    int w = 64, h = 48, threshold = 128;
    int blank = 0, i;
    vis_image *im;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--blank") == 0) {
            blank = 1;
        } else if (strcmp(argv[i], "--size") == 0 && i + 1 < argc) {
            if (sscanf(argv[++i], "%dx%d", &w, &h) != 2) {
                fprintf(stderr, "vis: --size wants WxH\n");
                return 2;
            }
        } else if (strcmp(argv[i], "--threshold") == 0 && i + 1 < argc) {
            threshold = atoi(argv[++i]);
        } else {
            fprintf(stderr, "vis: unknown argument %s\n", argv[i]);
            return 2;
        }
    }

    im = blank ? vis_render_blank(w, h) : vis_render_triangle(w, h);
    if (im == NULL) {
        fprintf(stderr, "vis: cannot render %dx%d\n", w, h);
        return 2;
    }

    printf("size=%dx%d bright=%ld corner=%06x\n",
           vis_image_width(im), vis_image_height(im),
           vis_count_bright(im, threshold),
           vis_image_pixel(im, 0, 0));
    vis_image_free(im);
    return 0;
}
