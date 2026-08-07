/* 窓を開く側。実際に X の伺服体へ繋ぎ、窓を作り、画素を置き、
 * 最初の露出まで待ってから終える。Xvfb の上で走らせられる。 */
#include "shell.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const char *shell_name(void) { return "x11"; }

int shell_show(const plot_canvas *c, const char *arg)
{
    Display *dpy;
    Window win;
    GC gc;
    XImage *img;
    XEvent ev;
    int screen, w, h;
    char *buf;
    int rc = 0;

    (void)arg;
    if (c == NULL) {
        return 2;
    }
    w = plot_canvas_width(c);
    h = plot_canvas_height(c);

    dpy = XOpenDisplay(NULL);
    if (dpy == NULL) {
        /* 表示が無いのは異常ではなく、よくある状況である。
         * 落ちるのではなく、何が足りないかを言って終える。 */
        fprintf(stderr, "plot: cannot open display (is DISPLAY set?)\n");
        return 3;
    }
    screen = DefaultScreen(dpy);

    win = XCreateSimpleWindow(dpy, RootWindow(dpy, screen), 0, 0,
                              (unsigned)w, (unsigned)h, 0,
                              BlackPixel(dpy, screen), BlackPixel(dpy, screen));
    XStoreName(dpy, win, "plot");
    XSelectInput(dpy, win, ExposureMask);
    XMapWindow(dpy, win);

    /* XImage は自分が渡した記憶を所有する。canvas の側を渡すと
     * XDestroyImage が他人の記憶を解放してしまうため、写しを作る。 */
    buf = malloc((size_t)plot_canvas_stride(c) * (size_t)h);
    if (buf == NULL) {
        XCloseDisplay(dpy);
        return 2;
    }
    memcpy(buf, plot_canvas_pixels(c), (size_t)plot_canvas_stride(c) * (size_t)h);

    img = XCreateImage(dpy, DefaultVisual(dpy, screen),
                       (unsigned)DefaultDepth(dpy, screen), ZPixmap, 0,
                       buf, (unsigned)w, (unsigned)h, 32,
                       plot_canvas_stride(c));
    if (img == NULL) {
        free(buf);
        XCloseDisplay(dpy);
        return 2;
    }

    gc = XCreateGC(dpy, win, 0, NULL);

    /* 最初の露出を待って一度描く。待たずに描くと、窓が写像される前の
     * 描画になり、伺服体は黙って捨てる。 */
    for (;;) {
        XNextEvent(dpy, &ev);
        if (ev.type == Expose) {
            XPutImage(dpy, win, gc, img, 0, 0, 0, 0, (unsigned)w, (unsigned)h);
            XFlush(dpy);
            break;
        }
    }

    printf("plot: drew %dx%d on the display\n", w, h);
    fflush(stdout);

    XFreeGC(dpy, gc);
    XDestroyImage(img);          /* buf もこれが解放する */
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return rc;
}
