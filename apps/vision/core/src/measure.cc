/* 数える側。OpenCV は C++ のライブラリだが、面は C ABI に保つ。 */
#include "internal.h"

#include <opencv2/imgproc.hpp>

vis_image *vs_wrap(const cv::Mat &rgb)
{
    vis_image *im = new (std::nothrow) vis_image;
    if (im != nullptr) {
        im->rgb = rgb.clone();
    }
    return im;
}

extern "C" void vis_image_free(vis_image *im) { delete im; }

extern "C" int vis_image_width(const vis_image *im)
{
    return (im != nullptr) ? im->rgb.cols : 0;
}

extern "C" int vis_image_height(const vis_image *im)
{
    return (im != nullptr) ? im->rgb.rows : 0;
}

extern "C" uint32_t vis_image_pixel(const vis_image *im, int x, int y)
{
    if (im == nullptr || x < 0 || y < 0 || x >= im->rgb.cols || y >= im->rgb.rows) {
        return 0;
    }
    const cv::Vec3b &p = im->rgb.at<cv::Vec3b>(y, x);
    return (static_cast<uint32_t>(p[0]) << 16) |
           (static_cast<uint32_t>(p[1]) << 8) |
            static_cast<uint32_t>(p[2]);
}

extern "C" long vis_count_bright(const vis_image *im, int threshold)
{
    if (im == nullptr || threshold < 0 || threshold > 255) {
        return -1;
    }
    cv::Mat grey, mask;
    cv::cvtColor(im->rgb, grey, cv::COLOR_RGB2GRAY);
    cv::threshold(grey, mask, threshold, 255, cv::THRESH_BINARY);
    return static_cast<long>(cv::countNonZero(mask));
}

extern "C" vis_image *vis_resize(const vis_image *im, int w, int h)
{
    if (im == nullptr || w <= 0 || h <= 0) {
        return nullptr;
    }
    cv::Mat out;
    cv::resize(im->rgb, out, cv::Size(w, h), 0, 0, cv::INTER_NEAREST);
    return vs_wrap(out);
}
