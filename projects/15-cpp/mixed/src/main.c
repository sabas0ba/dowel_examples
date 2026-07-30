#include "parts.h"

/* 終了状態に両方の値を載せる。増分で片方だけが古いまま残ったことを、
   件数ではなく中身で観測するための仕掛けである。 */
int main(void) { return c_part() * 10 + cxx_part(); }
