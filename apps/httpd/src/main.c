/* httpd — 静的ファイルを返す。
 *
 *   httpd [-p PORT] [-r ROOT] [-1] [--waiter]
 *
 * -1 は1接続だけ受けて終わる（検査から使う）。--waiter は選ばれた待ち方を
 * 名乗って終わる。 */
#include "hd/hd.h"

#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#ifdef HD_HAVE_THREADS
#include <pthread.h>

struct job {
    int   fd;
    char  root[512];
};

static void *worker(void *arg)
{
    struct job *j = arg;
    hd_serve_connection(j->fd, j->root);
    close(j->fd);
    free(j);
    return NULL;
}
#endif

static volatile sig_atomic_t stopping;

static void on_signal(int sig)
{
    (void) sig;
    stopping = 1;
}

int main(int argc, char **argv)
{
    int port = 0;                       /* 0 なら任意の空き番号 */
    const char *root = ".";
    int once = 0;
    int listener;
    struct sockaddr_in addr;
    socklen_t addr_len = sizeof addr;
    int i;
    int on = 1;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-p") == 0 && i + 1 < argc) {
            port = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-r") == 0 && i + 1 < argc) {
            root = argv[++i];
        } else if (strcmp(argv[i], "-1") == 0) {
            once = 1;
        } else if (strcmp(argv[i], "--waiter") == 0) {
            printf("%s %s\n", hd_waiter_name(),
                   hd_uses_threads() ? "threaded" : "sequential");
            return 0;
        } else {
            fputs("usage: httpd [-p PORT] [-r ROOT] [-1] [--waiter]\n", stderr);
            return 2;
        }
    }

    /* 相手が先に切ると write が SIGPIPE を上げる。落ちてはいけない。 */
    signal(SIGPIPE, SIG_IGN);
    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);

    listener = socket(AF_INET, SOCK_STREAM, 0);
    if (listener < 0) {
        perror("socket");
        return 1;
    }
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);

    memset(&addr, 0, sizeof addr);
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons((unsigned short) port);
    if (bind(listener, (struct sockaddr *) &addr, sizeof addr) != 0) {
        perror("bind");
        return 1;
    }
    if (listen(listener, 16) != 0) {
        perror("listen");
        return 1;
    }
    if (getsockname(listener, (struct sockaddr *) &addr, &addr_len) == 0) {
        /* 実際に取れた番号を出す。0 を渡した呼び出し側がこれを読む。 */
        printf("listening %d\n", ntohs(addr.sin_port));
        fflush(stdout);
    }

    while (!stopping) {
        int fd = accept(listener, NULL, NULL);
        if (fd < 0) {
            if (stopping) {
                break;
            }
            continue;
        }
#ifdef HD_HAVE_THREADS
        {
            pthread_t  t;
            struct job *j = malloc(sizeof *j);
            if (j != NULL) {
                j->fd = fd;
                snprintf(j->root, sizeof j->root, "%s", root);
                if (pthread_create(&t, NULL, worker, j) == 0) {
                    pthread_detach(t);
                } else {
                    free(j);
                    close(fd);
                }
            } else {
                close(fd);
            }
        }
#else
        hd_serve_connection(fd, root);
        close(fd);
#endif
        if (once) {
            break;
        }
    }
    close(listener);
    return 0;
}
