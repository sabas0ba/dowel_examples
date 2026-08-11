/* 記憶の配置。ベアメタルではこれを省略できない。
 *
 * 対象は MPS2-AN386（Cortex-M4）。qemu-system-arm がこの機械を持つため、
 * 組んだものを実際に走らせられる。
 *
 * `apps/blink` の同名のものとほぼ同じだが、こちらは **.data と .bss の
 * 番地を記号として出している**。普段それを使って初期化するのは libc の
 * 起動コードであり、libc が無い以上、番地を知る手立てを自分で用意して
 * 起動コードも自分で書く必要がある（src/boot.c の `_reset`）。
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
    /* ベクタ表は flash の先頭でなければならない。リセット時、CPU は
       番地 0 から2語を読み、[0] を SP に、[1] を PC に載せる。 */
    .vectors : {
        KEEP(*(.vectors))       /* 誰も呼ばない。削らせない */
    } > FLASH

    .text : {
        *(.text*)
        *(.rodata*)
    } > FLASH

    /* 初期値を持つ変数。実体は FLASH に置き、RAM へ写して使う。
       写す元と先の番地が要るので、記号にして出す。 */
    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > RAM AT> FLASH
    _data_load = LOADADDR(.data);

    /* ゼロで始まる変数。像には入れず、起動時に埋める。 */
    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > RAM
}
