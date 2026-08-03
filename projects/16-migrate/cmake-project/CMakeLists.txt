# 移行元。File API から下書きを起こし、compile_commands.json と突き合わせる。
#
# 構成のフラグ（CMAKE_C_FLAGS_DEBUG など）はあえて CMake の既定のままに
# してある。dowel の debug（-g -O0）とも release（-O2 -DNDEBUG）とも一致
# しないため、「構成が決めるフラグを取り込みにも突き合わせにも持ち込まない」
# ことが働いていなければ、全ソースに差が出る（docs/10-findings.md F-017）。
cmake_minimum_required(VERSION 3.16)
project(demo C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(greet STATIC src/greet.c src/extra.c)
target_include_directories(greet PUBLIC include)
target_compile_definitions(greet PRIVATE GREET_SCALE=3)

add_executable(demo src/main.c)
target_link_libraries(demo PRIVATE greet)
target_compile_definitions(demo PRIVATE DEMO_MODE=1)

# 翻訳がどの構成で行われたかを、成果物自身に名乗らせる。
# 最適化の有無と NDEBUG の有無は、下書きに写された flags に左右される。
add_executable(report src/report.c)
