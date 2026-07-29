/* どのアーキテクチャ向けに翻訳されたかを、C の側から見る。
   マニフェストの宣言でも構成識別子でもなく、生成された成果物が答える。 */
#ifndef ARCH_H
#define ARCH_H

#if defined(__aarch64__)
#  define ARCH_NAME "aarch64"
#elif defined(__x86_64__)
#  define ARCH_NAME "x86_64"
#else
#  define ARCH_NAME "other"
#endif

/* ポインタ幅とエンディアンも、翻訳先が本当に変わったかの手掛かりになる。
   名前だけならプリプロセッサの定義で偽装できるが、これらは実体に効く。 */
#define PTR_BITS (8 * (int) sizeof(void *))

#endif
