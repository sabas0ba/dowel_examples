/* 描く側。OSMesa は表示を持たない機械でも GL の文脈を作れるので、
 * 「窓が開いたか」ではなく「何が描かれたか」を機械にかけられる。 */
#include "internal.h"

#include <opencv2/imgproc.hpp>

#include <GL/osmesa.h>
#include <GL/gl.h>

#include <vector>

namespace {

/* 0xRRGGBB を 0..1 の三つ組へ。 */
void set_colour(uint32_t rgb, float out[3])
{
    out[0] = ((rgb >> 16) & 0xFFu) / 255.0f;
    out[1] = ((rgb >> 8) & 0xFFu) / 255.0f;
    out[2] = (rgb & 0xFFu) / 255.0f;
}

/* 文脈を作り、描き、読み戻す。draw が false なら背景だけ。 */
vis_image *render(int w, int h, bool draw)
{
    if (w <= 0 || h <= 0) {
        return nullptr;
    }

    OSMesaContext ctx = OSMesaCreateContextExt(OSMESA_RGBA, 16, 0, 0, nullptr);
    if (ctx == nullptr) {
        return nullptr;
    }

    std::vector<unsigned char> buf(static_cast<size_t>(w) * h * 4);
    if (!OSMesaMakeCurrent(ctx, buf.data(), GL_UNSIGNED_BYTE, w, h)) {
        OSMesaDestroyContext(ctx);
        return nullptr;
    }
    /* 読み戻す向きを画像と揃える。既定では下から上である。 */
    OSMesaPixelStore(OSMESA_Y_UP, 0);

    float c[3];
    set_colour(VIS_BACKGROUND, c);
    glClearColor(c[0], c[1], c[2], 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    if (draw) {
        set_colour(VIS_INK, c);
        glColor3f(c[0], c[1], c[2]);
        glBegin(GL_TRIANGLES);
        glVertex2f(-0.8f, -0.8f);
        glVertex2f(0.8f, -0.8f);
        glVertex2f(0.0f, 0.8f);
        glEnd();
    }
    glFinish();

    /* RGBA を RGB に落とす。OpenCV の側へ渡すのはここからである。 */
    cv::Mat rgba(h, w, CV_8UC4, buf.data());
    cv::Mat rgb;
    cv::cvtColor(rgba, rgb, cv::COLOR_RGBA2RGB);

    OSMesaDestroyContext(ctx);
    return vs_wrap(rgb);
}

}  // namespace

extern "C" vis_image *vis_render_triangle(int w, int h) { return render(w, h, true); }
extern "C" vis_image *vis_render_blank(int w, int h)    { return render(w, h, false); }
