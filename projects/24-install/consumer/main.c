/* dowel を知らない使う側。翻訳も結合も pkg-config が刷る引数だけで行う。 */
#include <shapes.h>
#include <stdio.h>

int main(void) { printf("%.4f\n", shapes_perimeter(2.0)); return 0; }
