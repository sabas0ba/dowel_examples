/* 内部の見出し。使う側には渡さない。 */
#ifndef VIS_INTERNAL_H
#define VIS_INTERNAL_H

#include "vis/vis.h"

#include <opencv2/core.hpp>

/* 像の実体は OpenCV の行列である。使う側にはこの事実を見せない。 */
struct vis_image {
    cv::Mat rgb;          /* CV_8UC3、チャネルの並びは R G B */
};

vis_image *vs_wrap(const cv::Mat &rgb);

#endif
