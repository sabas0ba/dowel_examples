/* 記憶の配置のうち、起動コードと C の両方が見るもの。
 *
 * ベクタ表の [0] は初期スタックポインタであり、起動コードもそこへ SP を
 * 載せる。2か所に同じ数を書けば、片方だけ直したときに静かに壊れる。
 * `.S` は前処理を通るので、この見出しを両方から取り込める（ADR-0048）。 */
#ifndef BL_MEM_H
#define BL_MEM_H

/* SRAM の末尾。ld/thumbv7em-none-eabihf.ld の RAM の ORIGIN + LENGTH と
 * 揃えてある。 */
#define BL_STACK_TOP 0x20400000

#endif
