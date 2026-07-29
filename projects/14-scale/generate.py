"""規模のための木を生成する。

リポジトリに 100 を超えるファイルを置くと、差分も一覧も読めなくなる。
中身に意味は無く、数だけが意味を持つため、走らせるたびに作る
（07-robustness が大きな入力を生成するのと同じ理由）。

    generate.py <出力先> <ソース数> <ターゲット数> <連鎖の深さ>
"""

import os
import sys


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def wide(root, sources, targets):
    """1つのライブラリに多数のソース、そのうえに多数の実行ファイル。"""
    parts = ["[lib.wide]", 'sources = glob("src/*.c")', "",
             "[lib.wide.public]", 'includes = [dir("include")]', ""]
    write(os.path.join(root, "include", "wide.h"),
          "#pragma once\n#define WIDE_SCALE 1\nint wide_sum(void);\n")
    body = []
    for i in range(sources):
        write(os.path.join(root, "src", "u%04d.c" % i),
              '#include "wide.h"\nint u%04d(void) { return WIDE_SCALE; }\n' % i)
        body.append("    n += u%04d();" % i)
    decls = "\n".join("int u%04d(void);" % i for i in range(sources))
    write(os.path.join(root, "src", "sum.c"),
          '#include "wide.h"\n%s\n\nint wide_sum(void)\n{\n    int n = 0;\n%s\n    return n;\n}\n'
          % (decls, "\n".join(body)))

    for t in range(targets):
        write(os.path.join(root, "bins", "b%03d.c" % t),
              '#include "wide.h"\nint main(void) { return wide_sum() == %d ? 0 : 1; }\n'
              % (sources,))
        parts += ["[bin.b%03d]" % t, 'sources = [file("bins/b%03d.c")]' % t, "",
                  "[bin.b%03d.private]" % t, 'deps = [target("wide")]', ""]

    write(os.path.join(root, "dowel.toml"),
          '[package]\nname    = "wide"\nversion = "0.1.0"\nedition = "2026"\n')
    write(os.path.join(root, "dowel.build"), "\n".join(parts))


def chain(root, depth):
    """深い依存の連鎖。level0 が最も深く、leveln-1 が根から使われる。"""
    for i in range(depth):
        pkg = os.path.join(root, "level%d" % i)
        write(os.path.join(pkg, "include", "level%d.h" % i),
              "#pragma once\n#define LEVEL%d 1\nint level%d_value(void);\n" % (i, i))
        if i == 0:
            src = ('#include "level0.h"\nint level0_value(void) { return LEVEL0; }\n')
            deps = ""
            toml_deps = ""
        else:
            src = ('#include "level%d.h"\n#include "level%d.h"\n'
                   'int level%d_value(void) { return level%d_value() + LEVEL%d; }\n'
                   % (i, i - 1, i, i - 1, i))
            deps = '\ndeps = [dep("level%d")]' % (i - 1)
            toml_deps = ('\n[[dependencies]]\nname = "level%d"\npath = "../level%d"\n'
                         % (i - 1, i - 1))
        write(os.path.join(pkg, "src", "level%d.c" % i), src)
        write(os.path.join(pkg, "dowel.toml"),
              '[package]\nname    = "level%d"\nversion = "0.1.0"\nedition = "2026"\n%s'
              % (i, toml_deps))
        write(os.path.join(pkg, "dowel.build"),
              '[lib.level%d]\nsources = glob("src/*.c")\n\n'
              '[lib.level%d.public]\nincludes = [dir("include")]%s\n'
              % (i, i, deps))

    top = os.path.join(root, "top")
    write(os.path.join(top, "src", "main.c"),
          '#include "level%d.h"\nint main(void) { return level%d_value() == %d ? 0 : 1; }\n'
          % (depth - 1, depth - 1, depth))
    write(os.path.join(top, "dowel.toml"),
          '[package]\nname    = "top"\nversion = "0.1.0"\nedition = "2026"\n\n'
          '[[dependencies]]\nname = "level%d"\npath = "../level%d"\n' % (depth - 1, depth - 1))
    write(os.path.join(top, "dowel.build"),
          '[bin.top]\nsources = glob("src/*.c")\n\n'
          '[bin.top.private]\ndeps = [dep("level%d")]\n' % (depth - 1,))


if __name__ == "__main__":
    out, sources, targets, depth = (sys.argv[1], int(sys.argv[2]),
                                    int(sys.argv[3]), int(sys.argv[4]))
    wide(os.path.join(out, "wide"), sources, targets)
    chain(os.path.join(out, "chain"), depth)
