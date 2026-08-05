/* STM32F4 系のメモリマップ。Cortex-M4F、flash 256K、SRAM 64K。
 *
 * ベアメタルではこれを省略できない。ベクタ表は flash の先頭になければ
 * ならず、リセット時に [0] が SP へ、[1] が PC へ載る。
 *
 * 現在この木からは指せない（docs/10-findings.md F-025）。`link_flags` は
 * List<Str> であり file() を受けず、フラグの中の相対パスはビルド
 * ディレクトリ基準で解決されるためである。 */
MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 256K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 64K
}

_stack_top = ORIGIN(RAM) + LENGTH(RAM);

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
