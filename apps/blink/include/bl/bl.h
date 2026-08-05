/* blink の公開見出し。libc を使わないため、必要な型は自分で持つ。 */
#ifndef BL_BL_H
#define BL_BL_H

typedef unsigned char      u8;
typedef unsigned int       u32;
typedef unsigned long long u64;

/* 周辺機器の番地。実機ではデータシートが決める。 */
#define BL_GPIO_BASE  0x40020000u

/* 出力の向きに設定する。 */
void bl_gpio_output(u32 pin);

/* 出力を反転する。 */
void bl_gpio_toggle(u32 pin);

/* 直近に書いた値。実機の代わりに、外から読めるようにしてある。 */
u32  bl_gpio_state(void);

/* おおよその待ち。時計を持たない層なので、回数で数える。 */
void bl_delay(u32 ticks);

/* 何回待ったか。実行を伴わない検査から読む。 */
u64  bl_delay_count(void);

#endif
