# 移行元。素朴な2目標の木である——静的ライブラリと、それを使う実行ファイル。
#
# この形にしてあるのは、`ar` の引数とリンクの引数が Meson の introspection
# の `parameters` 配列に現れるのが、目標が2つあってリンクで繋がっている
# ときだからである（docs/10-findings.md F-057）。
project('shapes', 'c', default_options: ['c_std=c11'])

inc = include_directories('include')

libshapes = static_library('shapes', 'src/area.c', 'src/perim.c',
                           include_directories: inc,
                           c_args: ['-DSHAPES_BUILD=1', '-Wall'])

executable('shapetool', 'src/main.c',
           include_directories: inc,
           c_args: ['-DTOOL=1'],
           link_with: libshapes)
