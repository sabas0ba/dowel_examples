#ifdef QUIET
#include <quiet.h>
#endif

int main(void)
{
#ifdef QUIET
    return QUIET_ANSWER == 7 ? 0 : 1;
#else
    return 0;
#endif
}
