/* 取ってきた toolchain の sysroot からしか見えない見出しを取り込む。 */
#include <kit.h>
#include <stdio.h>

int main(void) { printf("%d\n", FROM_SYSROOT); return 0; }
