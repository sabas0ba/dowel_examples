/* 記憶の配置。ベアメタルではこれを省略できない。
 *
 * 対象は MPS2-AN386（Cortex-M4）。qemu-system-arm がこの機械を持つため、
 * 組んだものを実際に走らせられる。
 *
 * ベクタ表は flash の先頭になければならない。リセット時、CPU は番地 0 から
 * 2語を読み、[0] を SP に、[1] を PC に載せる。配置を決めなければそこに
 * ベクタ表は無く、**起動した瞬間に落ちる**。
 *
 * 現在この木からは指せない（docs/10-findings.md F-025）。`link_flags` は
 * List<Str> であり file() を受けず、フラグの中の相対パスはビルド
 * ディレクトリ基準で解決されるためである。 */
MEMORY
{
    FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 4M
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 4M
}

SECTIONS
{
    .text : {
        KEEP(*(.vectors))       /* ベクタ表は先頭に、削らせない */
        *(.text*)
        *(.rodata*)
    } > FLASH

    .data : { *(.data*) } > RAM AT> FLASH
    .bss  : { *(.bss*) *(COMMON) } > RAM
}
