#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    const char *what = argc > 1 ? argv[1] : "(none)";
    if (strcmp(what, "sad") == 0) {
        char b[4096];
        printf("WHY=%s\n", getenv("WHY") ? getenv("WHY") : "(unset)");
        if (getcwd(b, sizeof b) != NULL) { printf("cwd=%s\n", b); }
        return 1;
    }
    return 0;
}
