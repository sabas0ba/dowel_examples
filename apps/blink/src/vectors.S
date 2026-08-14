/* ベクタ表と起動コード。
 *
 * リセット時、CPU は flash の先頭から2語を読む。[0] がスタックポインタの
 * 初期値、[1] が最初に実行する番地である。したがってこの表は flash の
 * 先頭になければならず、それを決めるのがリンカスクリプトである。
 *
 * ここはアセンブリでしか書けない層である。SP を載せる前に C の関数へ
 * 入ることはできず（引数も戻り番地も置く先が無い）、`.bss` を 0 で埋める
 * 前に C の大域変数を読むこともできない。libc も起動コードも無い triple
 * では、この段を誰かが書く必要があり、それが `.S` である。
 *
 * 前処理を通る綴り（`.S`）を使う。スタックの頂きを C と共有する見出しから
 * 取り込むためであり、`.s` では `#include` が届かない（ADR-0048）。 */
#include "bl/mem.h"

	.syntax unified
	.thumb

/* ---- ベクタ表 ------------------------------------------------------
 *
 * 誰もこの表を参照しない。リンカスクリプトの KEEP() が残す。 */

	.section .vectors, "a"
	.align 2
	.global vectors
	.type vectors, %object
vectors:
	.word	BL_STACK_TOP		/* [0] 初期スタックポインタ */
	.word	_reset			/* [1] リセット */
	.word	_hang			/* [2] NMI */
	.word	_hang			/* [3] ハードフォールト */
	.word	_hang			/* [4] メモリ管理 */
	.word	_hang			/* [5] バスフォールト */
	.word	_hang			/* [6] 使用法フォールト */
	.size	vectors, . - vectors

/* ---- 起動 ----------------------------------------------------------- */

	.section .text
	.align 2
	.global _reset
	.thumb_func
	.type _reset, %function
_reset:
	/* SP を載せる。ベクタ表の [0] も同じ値だが、qemu が -kernel で
	   直接飛び込む場合など、表が読まれない経路もある。 */
	ldr	r0, =BL_STACK_TOP
	mov	sp, r0

	/* .bss を 0 で埋める。C は「初期化していない大域変数は 0」を
	   前提にしており、それを成り立たせる者がここにしかいない。 */
	ldr	r0, =__bss_start__
	ldr	r1, =__bss_end__
	movs	r2, #0
1:	cmp	r0, r1
	bhs	2f
	str	r2, [r0], #4
	b	1b
2:
	/* 初期値のある大域変数を flash から RAM へ写す。 */
	ldr	r0, =__data_start__
	ldr	r1, =__data_end__
	ldr	r2, =__data_load__
3:	cmp	r0, r1
	bhs	4f
	ldr	r3, [r2], #4
	str	r3, [r0], #4
	b	3b
4:
	bl	bl_main
	/* 戻ってきたら止まる。返る先は無い。 */
	.size	_reset, . - _reset

	.global _hang
	.thumb_func
	.type _hang, %function
_hang:
	b	_hang
	.size	_hang, . - _hang
