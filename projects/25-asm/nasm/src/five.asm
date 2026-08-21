; NASM の綴り。gas とは方言が違うので、C の駆動器には渡せない。
; 実際の相手は OpenSSL や BoringSSL の生成器が吐く x86 のもので、
; Windows 側は NASM、Unix 側は gas という分かれ方をしている。
	bits 64
	default rel

	section .text
	global  masm_five
masm_five:
	mov	eax, 5
	ret

; 実行可能スタックを要求しない印。dowel は宣言された assembler の綴りを
; 知らないので `-Wa,--noexecstack` を渡せず、代わりに結合の側で
; `-z noexecstack` を渡す。書庫に入って配られたときに残るのはこちらだけ
; である（ADR-0050）。
	section .note.GNU-stack noalloc noexec nowrite progbits
