/* POSIX の側。手元の機械で組んで走らせるのはこちらである。 */
#include "wt/wt.h"
#include "internal.h"

#include <unistd.h>

const char *wt_eol(void) { return "\n"; }

char wt_sep(void) { return '/'; }

int wt_is_sep(char c) { return c == '/'; }

unsigned long wt_page_size(void) { return (unsigned long)sysconf(_SC_PAGESIZE); }
