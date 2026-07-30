# 対象の種類ごとの写り方だけを見るための移行元。組み上げて走らせることは
# 目的でないため、中身は最小にしてある。
#
# CMake の対象の種類は dowel の語彙より多い。写せないものが黙って消えると、
# 利用者は「移行できた」と読んだまま欠けた木を組むことになる。
cmake_minimum_required(VERSION 3.16)
project(shapes C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(objs OBJECT src/o.c)          # OBJECT     -> lib
add_library(shr SHARED src/s.c)           # SHARED     -> lib（注記つき）
add_library(iface INTERFACE)              # INTERFACE  -> 対象にならない
target_include_directories(iface INTERFACE include)

add_executable(app src/main.c)
target_link_libraries(app PRIVATE objs shr iface m)   # m は系のライブラリ
