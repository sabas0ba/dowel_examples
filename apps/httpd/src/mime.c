#include "hd/hd.h"

#include <string.h>

static const struct { const char *ext; const char *type; } TABLE[] = {
    { ".html", "text/html; charset=utf-8" },
    { ".css",  "text/css" },
    { ".js",   "text/javascript" },
    { ".json", "application/json" },
    { ".png",  "image/png" },
    { ".svg",  "image/svg+xml" },
    { ".txt",  "text/plain; charset=utf-8" },
};

const char *hd_mime_for(const char *path)
{
    size_t i;
    const char *dot = strrchr(path, '.');

    if (dot != NULL) {
        for (i = 0; i < sizeof TABLE / sizeof TABLE[0]; i++) {
            if (strcmp(dot, TABLE[i].ext) == 0) {
                return TABLE[i].type;
            }
        }
    }
    return "application/octet-stream";
}
