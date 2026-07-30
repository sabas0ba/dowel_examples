# 移行元。File API から下書きを起こし、compile_commands.json と突き合わせる。
#
# 構成のフラグを dowel の暗黙の構成フラグに揃えてある。debug が -g -O0、
# release が -O2 -DNDEBUG である。揃えないと全ソースに差が出て、
# `migrate verify` が「移行の誤り」と「構成の食い違い」のどちらを報せて
# いるのか読めなくなる。ここでの関心は前者だけである。
cmake_minimum_required(VERSION 3.16)
project(demo C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_C_FLAGS_DEBUG   "-g -O0")
set(CMAKE_C_FLAGS_RELEASE "-O2 -DNDEBUG")

add_library(greet STATIC src/greet.c src/extra.c)
target_include_directories(greet PUBLIC include)
target_compile_definitions(greet PRIVATE GREET_SCALE=3)

add_executable(demo src/main.c)
target_link_libraries(demo PRIVATE greet)
target_compile_definitions(demo PRIVATE DEMO_MODE=1)

# 翻訳がどの構成で行われたかを、成果物自身に名乗らせる。
# 最適化の有無と NDEBUG の有無は、下書きに写された flags に左右される。
add_executable(report src/report.c)
