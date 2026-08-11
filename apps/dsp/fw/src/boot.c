/* 起動と、結果の返し方。ベアメタルではどちらも自分で書く。
 *
 * `apps/blink` が同じ機械（MPS2-AN386）で同じことをしている。こちらの
 * 主題は周辺機器ではなく**算法が同じ答を出すこと**なので、必要な最小限
 * だけを置いてある。 */
#include "fw.h"

void _reset(void);
int fw_main(void);

/* SRAM の末尾。ld/thumbv7em-none-eabihf.ld の RAM と揃えてある。 */
#define STACK_TOP 0x20400000u

static void hang(void)
{
    for (;;) {
    }
}

__attribute__((section(".vectors"), used))
void (*const vectors[])(void) = {
    (void (*)(void)) STACK_TOP,   /* [0] 初期スタックポインタ */
    _reset,                       /* [1] リセット */
    hang,                         /* [2] NMI */
    hang,                         /* [3] ハードフォールト */
    hang,                         /* [4] メモリ管理 */
    hang,                         /* [5] バスフォールト */
    hang,                         /* [6] 使用法フォールト */
};

/* semihosting。ARM の取り決めでは `bkpt 0xAB` を実行すると、r0 の操作番号と
 * r1 の引数を見た側（ここでは qemu）が代わりに実行する。libc の無い機械が
 * 結果を外へ伝える唯一の手段である。 */
#define SYS_WRITE0    0x04u
#define SYS_EXIT_EXT  0x20u
#define ADP_APP_EXIT  0x20026u

static void call(uint32_t op, const void *arg)
{
    register uint32_t r0 __asm__("r0") = op;
    register const void *r1 __asm__("r1") = arg;

    __asm__ volatile ("bkpt 0xAB" :: "r"(r0), "r"(r1) : "memory");
}

void fw_say(const char *s)
{
    call(SYS_WRITE0, s);
}

void fw_exit(uint32_t code)
{
    uint32_t args[2];

    args[0] = ADP_APP_EXIT;
    args[1] = code;
    call(SYS_EXIT_EXT, args);
    for (;;) {
    }
}

/* 32 ビットを16進で。libc が無いので printf は使えない。 */
void fw_say_hex(uint32_t v)
{
    static const char digits[] = "0123456789abcdef";
    char buf[9];
    int i;

    for (i = 7; i >= 0; i--) {
        buf[i] = digits[v & 0xFu];
        v >>= 4;
    }
    buf[8] = '\0';
    fw_say(buf);
}

/* 入口。.data の初期化も .bss のゼロ埋めも自分で行う——それをやるのが
 * 普段は libc の起動コードである。 */
extern uint32_t _data_start, _data_end, _data_load, _bss_start, _bss_end;

void _reset(void)
{
    uint32_t *dst, *src;

    for (dst = &_data_start, src = &_data_load; dst < &_data_end; dst++, src++) {
        *dst = *src;
    }
    for (dst = &_bss_start; dst < &_bss_end; dst++) {
        *dst = 0;
    }
    fw_exit((uint32_t)fw_main());
}
