/* ベアメタル側の窓口。libc が無いので、出すのも終わるのも自分で書く。 */
#ifndef DSP_FW_H
#define DSP_FW_H

#include <stdint.h>

void fw_say(const char *s);
void fw_say_hex(uint32_t v);
void fw_exit(uint32_t code);

#endif
