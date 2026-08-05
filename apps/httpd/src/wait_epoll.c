/* Linux 固有の待ち方。接続数が増えたときに poll と費用の形が変わる。 */
#include "hd/hd.h"

#include <sys/epoll.h>
#include <unistd.h>

const char *hd_waiter_name(void)
{
    return "epoll";
}

int hd_wait_readable(int fd, int timeout_ms)
{
    struct epoll_event ev;
    struct epoll_event got;
    int ep;
    int n;

    ep = epoll_create1(0);
    if (ep < 0) {
        return -1;
    }
    ev.events = EPOLLIN;
    ev.data.fd = fd;
    if (epoll_ctl(ep, EPOLL_CTL_ADD, fd, &ev) < 0) {
        close(ep);
        return -1;
    }
    n = epoll_wait(ep, &got, 1, timeout_ms);
    close(ep);
    return n;
}
