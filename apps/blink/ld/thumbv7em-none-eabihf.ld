/* 記憶の配置。ベアメタルではこれを省略できない。
 *
 * 対象は MPS2-AN386（Cortex-M4）。qemu-system-arm がこの機械を持つため、
 * 組んだものを実際に走らせられる。
 *
 * ベクタ表は flash の先頭になければならない。リセット時、CPU は番地 0 から
 * 2語を読み、[0] を SP に、[1] を PC に載せる。配置を決めなければそこに
 * ベクタ表は無く、**起動した瞬間に落ちる**。
 *
 * マニフェストからは `link_flags = [..., "-T", file("ld/<triple>.ld")]` で
 * 指す。`link_flags` は List<Str | Path> であり、Path の要素は絶対パスへ
 * 展開される（docs/10-findings.md F-025）。 */
MEMORY
{
    FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 4M
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 4M
}

SECTIONS
{
    /* ベクタ表は独立した節に置く。畳んでしまうと、成果物を読んだときに
       「残っているか」を節の一覧では確かめられなくなる。 */
    .vectors : {
        KEEP(*(.vectors))       /* 誰も呼ばない。削らせない */
    } > FLASH

    .text : {
        *(.text*)
        *(.rodata*)
    } > FLASH

    .data : { *(.data*) } > RAM AT> FLASH
    .bss  : { *(.bss*) *(COMMON) } > RAM
}
