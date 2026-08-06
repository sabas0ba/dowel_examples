/* blink の公開見出し。libc を使わないため、必要な型は自分で持つ。 */
#ifndef BL_BL_H
#define BL_BL_H

typedef unsigned char      u8;
typedef unsigned int       u32;
typedef unsigned long long u64;

/* 周辺機器の番地。MPS2-AN386 の GPIO。実機ではデータシートが決める。 */
#define BL_GPIO_BASE  0x40010000u

void bl_gpio_output(u32 pin);
void bl_gpio_toggle(u32 pin);
u32  bl_gpio_state(void);

/* おおよその待ち。時計を持たない層なので、回数で数える。 */
void bl_delay(u32 ticks);
u64  bl_delay_count(void);

/* ---- ホストとの窓口（semihosting）
 *
 * デバッガ（あるいは qemu）が居るときだけ働く。`bkpt 0xAB` で止まり、
 * r0 の操作番号を見た側が代わりに実行する。実機でもデバッガを繋いでいれば
 * 同じものが動く。
 *
 * これが無いと、ベアメタルのテストは結果を伝える手段を持たない。 */

/* ホストの端末へ書く。 */
void bl_say(const char *s);

/* 終了状態を返して止まる。走らせた側がこれを受け取る。 */
void bl_exit(u32 code);

#endif
