# apps/hashx — ライブラリ
#
# ここまでの実アプリは、いずれも**最後は実行ファイル**だった。ライブラリは
# そうではない。成果物そのものが製品であり、それを受け取るのは他人である。
# 見るべきことが変わる。
#
#   lib/      ライブラリ本体。公開する見出しは include/hashx/hashx.h の1枚
#   ctool/    C の利用者。別パッケージ
#   cxxtool/  C++ の利用者。別パッケージ。C のライブラリを配る以上、
#             これが繋がらなければ配る意味が無い
#
# ライブラリでしか問われないもの。
#
#   - **面（おもて）が宣言どおりか。** 成果物が外へ出す名前を数える。
#     「public に置いた見出しだけを渡した」は書き手の意図であって、
#     成果物の性質ではない
#   - **他人の言語から呼べるか。** C のライブラリは C++ から呼ばれる
#   - **出所を切り替えられるか。** 開発中は path、配ったあとは git や版
#   - **版が1か所で決まるか。** 見出しの版とマニフェストの版は一致すべき
#   - **配れるか。** dowel 以外の利用者へ渡す形があるか

# ------------------------------------------------------------ 道具立て

RE=readelf
AR_PATH="lib/.dowel/build/x86_64-unknown-linux-gnu-debug/lib/libhashx.a"

# exported — 成果物が外へ出す関数の名前。GLOBAL かつ DEFAULT のものだけが
# 利用者から見える。HIDDEN は同じ成果物の中でしか繋がらない。
exported() {
    $RE --syms --wide "$AR_PATH" 2>/dev/null |
        awk '$4 == "FUNC" && $5 == "GLOBAL" && $6 == "DEFAULT" { print $8 }' |
        sort -u
}

# hidden — 外へは出ないが翻訳単位は跨ぐ名前。
hidden() {
    $RE --syms --wide "$AR_PATH" 2>/dev/null |
        awk '$5 == "GLOBAL" && $6 == "HIDDEN" { print $8 }' | sort -u
}

# declared — 見出しが HASHX_API を付けている名前。
declared() {
    sed -n 's/^HASHX_API [a-z0-9_ *]*\**\(hashx_[a-z0-9_]*\)(.*/\1/p' \
        lib/include/hashx/hashx.h | sort -u
}

# hashes <実行ファイル> — "123456789" を食わせた答。
hashes() {
    printf '123456789' | "$1" 2>&1
}

# tool <パッケージ> <名前> — 利用者の実行ファイルの道。
tool() {
    find "$1/.dowel/build" -type f -path "*debug/bin/$2" 2>/dev/null | head -1
}

# with_dep_line <パッケージ> <足す行...> — dowel.toml の依存に行を足す。
# 空で呼ぶと元に戻す。
with_dep_line() {
    local pkg=$1; shift
    if [ -f "$pkg/dowel.toml.keep" ]; then
        mv "$pkg/dowel.toml.keep" "$pkg/dowel.toml"
    fi
    if [ "$#" -gt 0 ]; then
        cp "$pkg/dowel.toml" "$pkg/dowel.toml.keep"
        printf '%s\n' "$@" >>"$pkg/dowel.toml"
    fi
}

# ------------------------------------------------------------ 1. 組める

ok "the library package passes check" -C lib check
ok "and builds"                       -C lib build --no-compdb
ok "its own tests pass"               -C lib test

assert "the artifact is a static archive" test -f "$AR_PATH"

ok "the C consumer builds against it"   -C ctool   build --no-compdb
ok "the C++ consumer builds against it" -C cxxtool build --no-compdb

# ------------------------------------------------------------ 2. 面
#
# ライブラリの面は、書き手が「public に置いた」ことではなく、成果物が外へ
# 出す名前で決まる。数えれば分かる。
#
# 既定を隠す（`-fvisibility=hidden`）ことで、面は「印を付けたものだけ」に
# なる。印の付け忘れは面を狭めるだけであり、**面が勝手に広がることはない**。

want=$(declared)
got=$(exported)
[ "$want" = "$got" ]
v=$?
RC=0; _last_cmd="readelf --syms libhashx.a | GLOBAL DEFAULT   vs   HASHX_API in the header"
OUT="declared:"$'\n'"$want"$'\n'"exported:"$'\n'"$got"
fact $v "the archive exports exactly the names the header marks as the API"

n=$(exported | grep -cv '^hashx_')
[ "${n:-1}" = 0 ]
v=$?; RC=0; _last_cmd="readelf --syms libhashx.a | grep -v '^hashx_'"
OUT="$(exported)"
fact $v "and nothing outside the library's own prefix is exported"

# 翻訳単位を跨ぐ内部の名前は残るが、外へは出ない。static にできない
# ものを隠す手段があるかどうかは、ライブラリでは実務上の分かれ目である。
got=$(hidden)
printf '%s' "$got" | grep -q '^hx_'
v=$?; RC=0; _last_cmd="readelf --syms libhashx.a | GLOBAL HIDDEN"
OUT="hidden: ${got:-(none)}"
fact $v "an internal name that must cross translation units is hidden, not exported"

# 印を付け忘れた新しい名前が、勝手に面へ入らないこと。破って確かめる。
cp lib/src/fnv.c lib/src/fnv.c.bak
printf '\nuint32_t hx_added(void);\nuint32_t hx_added(void) { return 7; }\n' >>lib/src/fnv.c
"$DOWEL" -C lib build --no-compdb >/dev/null 2>&1
got=$(exported)
! printf '%s' "$got" | grep -q 'hx_added'
v=$?; RC=0; _last_cmd="add a global without HASHX_API, rebuild, read the symbols"
OUT="$got"
fact $v "a new global added without the API mark does not join the exported face"
mv lib/src/fnv.c.bak lib/src/fnv.c
"$DOWEL" -C lib build --no-compdb >/dev/null 2>&1

# 内部の見出しは利用者へ渡らない。分離が名目でないことを見る。
cp ctool/src/main.c ctool/src/main.c.bak
sed -i '1i #include "internal.h"' ctool/src/main.c
fails "a consumer cannot include the library's internal header" -C ctool build
mv ctool/src/main.c.bak ctool/src/main.c
ok "and removing it builds again" -C ctool build --no-compdb

# ------------------------------------------------------------ 3. 他人の言語から呼べる
#
# C のライブラリは C++ から呼ばれる。見出しの `extern "C"` が効いていなければ
# 名前が飾られ、リンクで見つからない。

c_said=$(hashes "$(tool ctool hashsum)")
x_said=$(hashes "$(tool cxxtool hashcxx)")
[ "$c_said" = "crc32=cbf43926" ]
v=$?; RC=0; _last_cmd="printf 123456789 | hashsum"
OUT="said: ${c_said:-(nothing)}"
fact $v "the C consumer gets the known answer for the standard check value"

[ "$x_said" = "$c_said" ]
v=$?; RC=0; _last_cmd="printf 123456789 | hashsum   vs   | hashcxx"
OUT="C:   ${c_said:-(nothing)}"$'\n'"C++: ${x_said:-(nothing)}"
fact $v "and the C++ consumer gets the same answer from the same archive"

# 閉包に C++ が1つでもあれば、リンクは C++ のドライバを通る。
# C のライブラリだけを見て C のドライバでリンクすると、C++ の実行時が付かない。
got=$("$DOWEL" -C cxxtool graph --kind=action --format=json 2>/dev/null |
      jq -r '.actions[] | select(.kind == "link" and (.target | test("hashcxx")))
             | .command[0]')
case $got in *++*|*clang++*) v=0 ;; *) v=1 ;; esac
RC=0; _last_cmd="graph --kind=action | select(.kind==\"link\") | .command[0]"
OUT="linker driver: ${got:-(none)}"
fact $v "the link of the C++ consumer runs through the C++ driver"

# ------------------------------------------------------------ 4. abi の札 (F-028)
#
# `abi` は must_equal である。C のライブラリと C++ の利用者は、言語が違う
# 以上、正しく書けば違う札になる。しかし違う札は abi-mismatch で落ちる。
#
# `extern "C"` の境界を跨ぐ呼び出しに ODR の問題は無い。にもかかわらず、
# 利用者は**ライブラリの札を書き写す**しかない。ライブラリを配るとき、
# 札は利用者ごとに違ってよいはずのものである。

cp cxxtool/dowel.build cxxtool/dowel.build.keep
sed -i 's/^abi       = "gnu11"$/abi       = "gnu++17"/' cxxtool/dowel.build

run -C cxxtool build --no-compdb
said=$OUT
[ "$RC" -eq 0 ]
verdict=$?
_last_cmd="dowel -C cxxtool build   # abi = \"gnu++17\"（本当の言語）"
OUT="$said"; RC=0
known_issue F-028
fact $verdict "a C++ consumer can declare its own abi label and still use a C library"

printf '%s' "$said" | grep -q 'abi-mismatch'
fact $? "instead the two labels are compared and the build is refused"

diag abi-mismatch "the refusal comes with a diagnostic code and both provenances" \
    -C cxxtool build --no-compdb

mv cxxtool/dowel.build.keep cxxtool/dowel.build
ok "writing the library's label into the consumer builds again" \
    -C cxxtool build --no-compdb

# ------------------------------------------------------------ 5. 出所の切り替え (F-029)
#
# ライブラリは出所が変わる。開発中は隣の木（`path`）、配ったあとは `git` か
# 版である。切り替えは片方を消してもう片方を書く操作であり、**消し忘れ**は
# 起こる。そのとき、どちらが使われたのかが分からなければ困る。

with_dep_line ctool \
    'git     = "https://example.invalid/hashx"' \
    'rev     = "0123456789012345678901234567890123456789"'

OUT=$(json_diags -C ctool check)
RC=0
printf '%s' "$OUT" | jq -e '.code' >/dev/null 2>&1
verdict=$?
_last_cmd="dowel -C ctool check   # 依存が path と git の両方を名乗る"
known_issue F-029
fact $verdict "a dependency entry that names two sources is refused"

run -C ctool build --no-compdb
said=$OUT
[ "$RC" -eq 0 ]
v=$?
_last_cmd="dowel -C ctool build   # git は存在しない宛先を指している"
OUT="$said"; RC=0
fact $v "instead the local path silently wins and the unreachable git source is never touched"

with_dep_line ctool 'version = "9.0"'

OUT=$(json_diags -C ctool check)
RC=0
printf '%s' "$OUT" | jq -e '.code' >/dev/null 2>&1
verdict=$?
_last_cmd="dowel -C ctool check   # 依存が path と version の両方を名乗る"
known_issue F-029
fact $verdict "the same holds when the two sources are a path and a version"

with_dep_line ctool
ok "removing the second source leaves the package as it was" -C ctool check

# 出所が1つも無い場合は拒まれる。規則は片側だけにある。
with_dep_line ctool
cp ctool/dowel.toml ctool/dowel.toml.keep
python3 -c '
p = "ctool/dowel.toml"
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(t.replace("path = \"../lib\"\n", ""))
'
diag incomplete-dependency "a dependency entry that names no source at all is refused" \
    -C ctool check
mv ctool/dowel.toml.keep ctool/dowel.toml

# ------------------------------------------------------------ 6. 版 (F-030)
#
# ライブラリの版は2か所にある。`dowel.toml` の `version` と、見出しの
# `HASHX_VERSION` である。利用者は後者を `#if` で見る。両者がずれると、
# 利用者は間違った前提で組み立てる。
#
# マニフェストの版を翻訳へ届ける手立ては無い。`cfg` の語彙にパッケージの
# 情報は入っていない。したがってライブラリの作者は手で写すしかなく、
# 写し間違いを見つけるものは誰もいない。

manifest=$(sed -n 's/^version *= *"\(.*\)"/\1/p' lib/dowel.toml | head -1)
header=$(sed -n 's/^#define HASHX_VERSION *"\(.*\)"/\1/p' lib/include/hashx/hashx.h)
[ -n "$manifest" ] && [ "$manifest" = "$header" ]
v=$?
RC=0; _last_cmd="dowel.toml の version   vs   hashx.h の HASHX_VERSION"
OUT="manifest: ${manifest:-?}"$'\n'"header:   ${header:-?}"
fact $v "the version in the manifest and the one in the header agree today"

# 片方だけを動かす。dowel は何も言わない。
cp lib/dowel.toml lib/dowel.toml.keep
sed -i 's/^version = "0.4.0"/version = "9.9.9"/' lib/dowel.toml
OUT=$(json_diags -C lib build --no-compdb)
RC=0
printf '%s' "$OUT" | jq -e '.code' >/dev/null 2>&1
verdict=$?
_last_cmd="dowel.toml の版だけを 9.9.9 にして build"
known_issue F-030
fact $verdict "moving the manifest version alone is noticed"

said=$("$(tool ctool hashsum)" --version 2>&1)
printf '%s' "$said" | grep -q '0.4.0'
v=$?; RC=0; _last_cmd="hashsum --version   # dowel.toml は 9.9.9 と言っている"
OUT="said: $said"
fact $v "and the artifact keeps reporting the version written in the header"

mv lib/dowel.toml.keep lib/dowel.toml

# ------------------------------------------------------------ 7. 配る先
#
# dowel はシステムのライブラリを **pkg-config 経由で使う**（17-deps）。
# その逆——dowel で組んだライブラリを、dowel を使わない相手へ渡す——は
# まだ無い。共有オブジェクトという種別も無い。
#
# ここは所見にしていない。`docs/90-roadmap.md` の第3段に「CMake の
# find_package 設定を出す」が、第6段に「書き出し対象（C ABI ほか）」が
# 既に載っており、報告しても重なるだけだからである。現状を記録して、
# 段が来たときに何が変わるかを読めるようにしておく。

cp lib/dowel.build lib/dowel.build.keep
printf '\n[dylib.hashx]\nsources = [file("src/fnv.c")]\n' >>lib/dowel.build

diag unknown-kind "a shared library cannot be declared" -C lib check

# 何が書けるのかは診断が並べてくれる。共有オブジェクトはそこに無い。
kinds=$("$DOWEL" -C lib check 2>&1 | sed -n 's/.*available kinds: *//p' | head -1)
case $kinds in
    *dylib*|*shared*|*cdylib*) v=1 ;;
    *lib*)                     v=0 ;;
    *)                         v=1 ;;
esac
RC=0; _last_cmd="dowel -C lib check   # [dylib.hashx] を書いた"
OUT="available kinds: ${kinds:-(the note was not printed)}"
fact $v "and the kinds it does offer, which the diagnostic lists, hold nothing for one"

mv lib/dowel.build.keep lib/dowel.build

# 出来上がるものを数える。今日の答は「静的な書庫が1つ」であり、
# 共有オブジェクトも pkg-config の .pc も CMake の設定も出ない。
# dowel を使わない相手に渡せるのは、書庫と見出しを手で運ぶ形だけである。
"$DOWEL" -C lib build --no-compdb >/dev/null 2>&1
n=$(find lib/.dowel/build \( -name '*.so' -o -name '*.so.*' -o -name '*.pc' \
                             -o -name '*Config.cmake' \) 2>/dev/null | wc -l)
[ "${n:-1}" = 0 ]
v=$?
RC=0; _last_cmd="find lib/.dowel/build -name '*.so' -o -name '*.pc' -o -name '*Config.cmake'"
OUT="what a foreign consumer could pick up: $n file(s)"$'\n'"$(find lib/.dowel/build -type f -name 'lib*' | sed 's|.*/build/||' | sort)"
fact $v "what a build produces today is one static archive and nothing a foreign consumer could read"

# ------------------------------------------------------------ 8. 構成が答を変えないこと
#
# ライブラリの機能フラグは、**実装を選ぶが答は選ばない**。表を持つ版と
# 都度計算する版で違う値が出たら、利用者から見ればそれは壊れている。

ok "the small-table configuration builds"  -C lib build --no-compdb --features=small
ok "and its tests give the same answers"   -C lib test --features=small

# 利用者側からも確かめる。ライブラリの構成は利用者の答を変えてはならない。
"$DOWEL" -C ctool build --no-compdb >/dev/null 2>&1
plain=$(hashes "$(tool ctool hashsum)")
[ "$plain" = "crc32=cbf43926" ]
v=$?; RC=0; _last_cmd="printf 123456789 | hashsum"
OUT="said: ${plain:-(nothing)}"
fact $v "the answer a consumer sees does not depend on how the library was configured"

# ------------------------------------------------------------ 9. 増分

"$DOWEL" -C ctool build --no-compdb >/dev/null 2>&1
runs_actions 0 "a second build of the consumer runs nothing" -C ctool --no-compdb

# ライブラリの一部を触る。利用者の側では、再翻訳と再リンクが要るが、
# 触っていない翻訳単位はそのままである。
printf '\n/* touched */\n' >>lib/src/fnv.c
build_direct -C ctool --no-compdb
rebuilt "fnv.c"     "editing a library source recompiles it for the consumer"
rebuilt "hashsum"   "and the consumer is linked again"
not_rebuilt "crc32.c" "while the library's other translation units are left alone"

# 公開する見出しを触ると、それを取り込んだものが組み直される。
printf '\n/* touched */\n' >>lib/include/hashx/hashx.h
build_direct -C cxxtool --no-compdb
rebuilt "main.cpp" "editing the public header recompiles the consumer that includes it"
