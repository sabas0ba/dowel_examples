#pragma once
#ifdef __cplusplus
extern "C" {
#endif
int c_part(void);     /* C として翻訳される */
int cxx_part(void);   /* C++ として翻訳される */
#ifdef __cplusplus
}
#endif
