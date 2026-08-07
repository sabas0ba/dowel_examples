// C のライブラリを C++ から呼ぶ。見出しの `extern "C"` が効いていなければ
// 名前が飾られ、リンクで見つからない。
#include "hashx/hashx.h"

#include <cstdio>
#include <string>
#include <string_view>

int main(int argc, char **argv)
{
    if (argc > 1 && std::string_view(argv[1]) == "--version") {
        std::printf("hashcxx (hashx %s)\n", hashx_version());
        return 0;
    }

    std::string all;
    char buf[4096];
    std::size_t n;
    while ((n = std::fread(buf, 1, sizeof buf, stdin)) > 0) {
        all.append(buf, n);
    }
    std::printf("crc32=%08x\n", hashx_crc32(all.data(), all.size()));
    return 0;
}
