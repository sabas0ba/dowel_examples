/* どのコンパイラが実際に翻訳したかを、C の側から見る。
   マニフェストの宣言ではなく、生成された成果物が答える。 */
#ifndef WHICH_H
#define WHICH_H

#if defined(__clang__)
#  define COMPILED_BY "clang"
#elif defined(__GNUC__)
#  define COMPILED_BY "gcc"
#else
#  define COMPILED_BY "other"
#endif

#endif
