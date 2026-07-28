#pragma once

/* 依存元へ伝播した公開の定義が届いているか。届かなければここで止まる。 */
#ifndef PROBE_API
#error "PROBE_API is missing: public defines did not reach this translation unit"
#endif

/* probe 自身のコンパイルにのみ効く定義が、依存元へ漏れていないか。
   漏れは値の有無でしか観測できないため、翻訳単位の側で見る。 */

/* ライブラリを組んだときの最適化構成。0 = debug, 1 = release。 */
int probe_opt(void);

/* ライブラリを組んだホストの OS。1 = linux, 2 = macos, 3 = windows。 */
int probe_os(void);

/* feature.trace が立っていれば 1。 */
int probe_trace(void);
