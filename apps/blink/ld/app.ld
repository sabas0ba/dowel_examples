/* 記憶の配置。バレメタルではこれを省略できない。
 *
 * 現在この木からは指せない（docs/10-findings.md F-025）。`link_flags` は
 * List<Str> であり file() を受けず、フラグの中の相対パスはビルド
 * ディレクトリ基準で解決されるためである。 */
MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 256K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 64K
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
