#include "hd/hd.h"

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int hd_uses_threads(void)
{
#ifdef HD_HAVE_THREADS
    return 1;
#else
    return 0;
#endif
}

static void write_all(int fd, const char *buf, size_t len)
{
    while (len > 0) {
        ssize_t n = write(fd, buf, len);
        if (n <= 0) {
            return;
        }
        buf += n;
        len -= (size_t) n;
    }
}

static void respond_error(int fd, int code, const char *text)
{
    char head[256];
    int n = snprintf(head, sizeof head,
                     "HTTP/1.1 %d %s\r\nContent-Length: %zu\r\n"
                     "Content-Type: text/plain\r\nConnection: close\r\n\r\n%s",
                     code, text, strlen(text), text);
    if (n > 0) {
        write_all(fd, head, (size_t) n);
    }
}

int hd_serve_connection(int fd, const char *root)
{
    char       buf[8192];
    size_t     have = 0;
    hd_request req;
    long       used;
    char       file[1024];
    struct stat st;
    int        in;

    for (;;) {
        ssize_t n;
        if (hd_wait_readable(fd, 5000) <= 0) {
            return -1;
        }
        n = read(fd, buf + have, sizeof buf - have - 1);
        if (n <= 0) {
            return -1;
        }
        have += (size_t) n;
        buf[have] = '\0';
        used = hd_parse_request(buf, have, &req);
        if (used < 0) {
            respond_error(fd, 400, "bad request");
            return -1;
        }
        if (used > 0) {
            break;
        }
        if (have + 1 >= sizeof buf) {
            respond_error(fd, 431, "request too large");
            return -1;
        }
    }

    if (strcmp(req.method, "GET") != 0 && strcmp(req.method, "HEAD") != 0) {
        respond_error(fd, 405, "method not allowed");
        return -1;
    }
    if (hd_resolve(root, req.path, file, sizeof file) != 0) {
        respond_error(fd, 403, "forbidden");
        return -1;
    }
    in = open(file, O_RDONLY);
    if (in < 0 || fstat(in, &st) != 0 || !S_ISREG(st.st_mode)) {
        if (in >= 0) {
            close(in);
        }
        respond_error(fd, 404, "not found");
        return -1;
    }

    {
        char head[512];
        int  n = snprintf(head, sizeof head,
                          "HTTP/1.1 200 OK\r\nContent-Length: %lld\r\n"
                          "Content-Type: %s\r\nConnection: %s\r\n\r\n",
                          (long long) st.st_size, hd_mime_for(file),
                          req.keep_alive ? "keep-alive" : "close");
        if (n > 0) {
            write_all(fd, head, (size_t) n);
        }
    }
    if (strcmp(req.method, "GET") == 0) {
        for (;;) {
            ssize_t n = read(in, buf, sizeof buf);
            if (n <= 0) {
                break;
            }
            write_all(fd, buf, (size_t) n);
        }
    }
    close(in);
    return 0;
}
