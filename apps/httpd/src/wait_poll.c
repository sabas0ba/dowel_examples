/* どこでも動く待ち方。既定はこちら。 */
#include "hd/hd.h"

#include <poll.h>

const char *hd_waiter_name(void)
{
    return "poll";
}

int hd_wait_readable(int fd, int timeout_ms)
{
    struct pollfd p;

    p.fd = fd;
    p.events = POLLIN;
    p.revents = 0;
    return poll(&p, 1, timeout_ms);
}
