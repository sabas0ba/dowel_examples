/* 前処理を通る側。見出しを取り込むため、依存の記録が要る。 */
#include "value.h"
	.text
	.globl	pre_value
	.type	pre_value, @function
pre_value:
	movl	$VALUE, %eax
	ret
	.size	pre_value, .-pre_value
