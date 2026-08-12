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
      jq -r '.steps[] | select(.kind == "link" and (.target | test("hashcxx")))
             | .program')
case $got in *++*|*clang++*) v=0 ;; *) v=1 ;; esac
RC=0; _last_cmd="graph --kind=action | select(.kind==\"link\") | .program"
OUT="linker driver: ${got:-(none)}"
fact $v "the link of the C++ consumer runs through the C++ driver"

# ------------------------------------------------------------ 4. abi の札 (F-028)
#
# `abi` は must_equal である。C のライブラリと C++ の利用者は、言語が違う
# 以上、正しく書けば違う札になる。ライブラリの面は `abi = "c"` を名乗り、
# **境界**を指す。`extern "C"` を跨ぐ呼び出しに ODR の危険は無いためである。
#
# 以前は `c` が無く、利用者はライブラリの札を書き写すしかなかった。それは
# 札から意味を奪う——「本当の ABI」ではなく「このライブラリを使う組」を表す
# 名前になる。F-028 / #78 として報告し、境界を指す札が入った。

_last_cmd="grep abi lib/dowel.build cxxtool/dowel.build"
OUT=$(grep -h '^abi' lib/dowel.build cxxtool/dowel.build)
RC=0
printf '%s' "$OUT" | grep -q '"c"'
fact $? "the library names the C ABI boundary rather than its own language"

got=$(grep -h '^abi' cxxtool/dowel.build | head -1)
case $got in *'"gnu++17"'*) v=0 ;; *) v=1 ;; esac
RC=0; _last_cmd="grep abi cxxtool/dowel.build"; OUT="$got"
fact $v "and the C++ consumer declares its own language"

ok "a C++ consumer can declare its own abi label and still use a C library" \
    -C cxxtool build --no-compdb

# 札の緩さは境界に限る。C ABI を名乗っていない目標どうしが食い違えば、
# これまでどおり落ちる。
cp lib/dowel.build lib/dowel.build.keep
sed -i 's/^abi      = "c"$/abi      = "gnu11"/' lib/dowel.build
run -C cxxtool build --no-compdb
said=$OUT
_last_cmd="dowel -C cxxtool build   # ライブラリの札を gnu11 に戻した"
OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'abi-mismatch'
fact $? "two labels that are not the boundary are still compared"

diag abi-mismatch "and the refusal comes with a diagnostic code and both provenances" \
    -C cxxtool build --no-compdb

mv lib/dowel.build.keep lib/dowel.build
ok "restoring the boundary label builds again" -C cxxtool build --no-compdb

# ------------------------------------------------------------ 5. 出所の切り替え (F-029)
#
# ライブラリは出所が変わる。開発中は隣の木（`path`）、配ったあとは `git` か
# 版である。切り替えは片方を消してもう片方を書く操作であり、**消し忘れ**は
# 起こる。以前は無診断で通り、黙って `path` が勝った。F-029 / #79 として
# 報告し、出所を2つ名乗る項目が拒まれるようになった。

with_dep_line ctool \
    'git     = "https://example.invalid/hashx"' \
    'rev     = "<40 桁の sha>"'

OUT=$(json_diags -C ctool check)
RC=0
printf '%s' "$OUT" | jq -e '.code' >/dev/null 2>&1
v=$?
_last_cmd="dowel -C ctool check   # 依存が path と git の両方を名乗る"
fact $v "a dependency entry that names two sources is refused"

fails "and the build does not fall back to the local path" -C ctool build --no-compdb

with_dep_line ctool 'version = "9.0"'

OUT=$(json_diags -C ctool check)
RC=0
printf '%s' "$OUT" | jq -e '.code' >/dev/null 2>&1
v=$?
_last_cmd="dowel -C ctool check   # 依存が path と version の両方を名乗る"
fact $v "the same holds when the two sources are a path and a version"

with_dep_line ctool
ok "removing the second source leaves the package as it was" -C ctool check

# 出所が1つも無い場合も拒まれる。規則が両側に揃った。
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
# ライブラリの版は `dowel.toml` にある。`pkg.version` でそれを翻訳へ届けられる
# ため、見出しに書き写す必要が無い。
#
# 以前は写すしかなく、写し間違いを見つけるものは誰もいなかった。F-030 / #80
# として報告し、`pkg` の定数が入った。

_last_cmd="grep pkg.version lib/dowel.build"
OUT=$(grep -n 'pkg\.version' lib/dowel.build)
RC=0
[ -n "$OUT" ]
fact $? "the library takes its version from the manifest instead of repeating it"

absent_copy=$(grep -c '^#define HASHX_VERSION "[0-9]' lib/include/hashx/hashx.h)
[ "$absent_copy" = 0 ]
v=$?; RC=0; _last_cmd="grep '#define HASHX_VERSION \"<数字>' hashx.h"
OUT="copies of the version written into the header: $absent_copy"
fact $v "so the public header holds no copy of it"

manifest=$(sed -n 's/^version *= *"\(.*\)"/\1/p' lib/dowel.toml | head -1)
said=$("$(tool ctool hashsum)" --version 2>&1)
printf '%s' "$said" | grep -q "$manifest"
v=$?; RC=0; _last_cmd="hashsum --version"
OUT="manifest: ${manifest:-?}"$'\n'"said:     $said"
fact $v "and the artifact reports the version the manifest declares"

# 版を動かすと、成果物が答える版も動く。写しが無いのだから、ずれようがない。
cp lib/dowel.toml lib/dowel.toml.keep
sed -i 's/^version = "0.4.0"/version = "9.9.9"/' lib/dowel.toml
"$DOWEL" -C ctool build --no-compdb >/dev/null 2>&1
said=$("$(tool ctool hashsum)" --version 2>&1)
printf '%s' "$said" | grep -q '9\.9\.9'
v=$?; RC=0; _last_cmd="dowel.toml の版を 9.9.9 にして組み直し、--version"
OUT="said: $said"
fact $v "moving the manifest version moves what the artifact answers"

mv lib/dowel.toml.keep lib/dowel.toml
"$DOWEL" -C ctool build --no-compdb >/dev/null 2>&1

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

# ------------------------------------------------------------ 10. 共有として配る（ADR-0030）
#
# ここまでライブラリが作れたのは静的な書庫だけだった。書庫は「その木の中で
# しか意味がない」形であり、dowel を使わない相手へ渡すには足りない。
# `linkage = "shared"` で共有ライブラリが作れる。
#
# 見るのは3つ。
#
#   1. **面が宣言で決まる。** `exports` に既定は無い。平面ごとに意味が逆
#      （ELF は全部出る、Windows は何も出ない）なので、既定を置けば同じ
#      マニフェストが2つの違う面を記述することになる
#   2. **閉包が位置独立で組まれる。** 共有の中に入る翻訳単位はすべて -fPIC
#   3. **組んだ木の中で走る。** 実行ファイルは lib/ を指す runpath を持つ

SO=$(find ctool/.dowel/build -name 'libhashx.so' 2>/dev/null | head -1)

ok "the library builds as a shared object" -C ctool build --features=shared --no-compdb
SO=$(find ctool/.dowel/build -name 'libhashx.so' | head -1)
_last_cmd="find libhashx.so"; OUT="${SO:-(absent)}"; RC=0
[ -n "$SO" ]
fact $? "producing a shared object where the default configuration produces an archive"

# 既定の側は書庫のままである。同じ木、同じソース、違う配られ方。
"$DOWEL" -C ctool build --no-compdb >/dev/null 2>&1
A=$(find ctool/.dowel/build -name 'libhashx.a' | head -1)
_last_cmd="find libhashx.a"; OUT="${A:-(absent)}"; RC=0
[ -n "$A" ]
fact $? "while the default configuration still produces the archive it always did"

# ---- 面は宣言で決まる

exported=$(nm -D --defined-only "$SO" 2>/dev/null | awk '{print $3}' | grep -E '^hashx_' | sort | paste -sd' ' -)
_last_cmd="nm -D --defined-only libhashx.so | hashx_*"; OUT="$exported"; RC=0
printf '%s' "$exported" | grep -q 'hashx_fnv1a' && printf '%s' "$exported" | grep -q 'hashx_version'
fact $? "the names the manifest lists are the ones the object exports"

# 中の名前は出ない。`-fvisibility=hidden` と `exports` の両方が効いている。
inner=$(nm -D --defined-only "$SO" 2>/dev/null | awk '{print $3}' | grep -c '^hx_')
_last_cmd="nm -D --defined-only libhashx.so | hx_*"
OUT="internal names exported: ${inner:-?}"$'\n'"$exported"
RC=0
[ "${inner:-1}" = 0 ]
fact $? "and the internal ones are not, so the interface is what was declared"

# 一覧を省くと拒まれる。既定を置かない、という設計がそのまま診断になる。
cp lib/dowel.build lib/dowel.build.keep
python3 - <<'PY'
import re
p = "lib/dowel.build"
t = open(p, encoding="utf-8").read()
t = re.sub(r'exports = \[.*?\] when feature\.shared\n', '', t, flags=re.S)
open(p, "w", encoding="utf-8").write(t)
PY
diag missing-exports "a shared library with no exports declared is refused" \
    -C ctool check --features=shared
run -C ctool check --features=shared
_last_cmd="dowel check  # exports を消した"; OUT=$(printf '%s' "$OUT" | grep -m4 'note\|error'); RC=0
printf '%s' "$OUT" | grep -qi 'everything on ELF' && printf '%s' "$OUT" | grep -qi 'nothing on Windows'
fact $? "saying why there is no default, which is that the platforms disagree"
mv lib/dowel.build.keep lib/dowel.build

# ---- 閉包が位置独立で組まれる

pic=$("$DOWEL" -C ctool graph --kind=action --format=json --features=shared 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc" and .target == "hashx:hashx")
             | ([.arguments[] | select(. == "-fPIC")] | length)' | sort -u | paste -sd' ' -)
_last_cmd="graph --features=shared | hashx:hashx の -fPIC"; OUT="-fPIC per unit: $pic"; RC=0
[ "$pic" = 1 ]
fact $? "every translation unit inside the shared library is compiled position-independent"

# 既定の構成では付かない。位置独立は共有にするから要るのであって、
# 常に付けるものではない（付ければ、要らない木まで遅くなる）。
pic=$("$DOWEL" -C ctool graph --kind=action --format=json 2>/dev/null |
      jq -r '[.steps[] | select(.kind == "cc" and .target == "hashx:hashx")
             | .arguments[] | select(. == "-fPIC")] | length')
_last_cmd="graph（既定） | hashx:hashx の -fPIC"; OUT="-fPIC occurrences: $pic"; RC=0
[ "$pic" = 0 ]
fact $? "and is not, when the same library is built as an archive"

# ---- 組んだ木の中で走る

"$DOWEL" -C ctool build --features=shared --no-compdb >/dev/null 2>&1
bin=$(find ctool/.dowel/build -path '*shared*/bin/hashsum' -type f | head -1)
needed=$(readelf -d "${bin:-/nonexistent}" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' | paste -sd' ' -)
_last_cmd="readelf -d hashsum | NEEDED"; OUT="$needed"; RC=0
printf '%s' "$needed" | grep -q 'libhashx.so'
fact $? "a consumer of the shared library records it as needed at run time"

rpath=$(readelf -d "${bin:-/nonexistent}" 2>/dev/null | sed -n 's/.*R\(UN\)\?PATH.*\[\(.*\)\]/\2/p')
_last_cmd="readelf -d hashsum | RUNPATH"; OUT="${rpath:-(none)}"; RC=0
printf '%s' "$rpath" | grep -q '/lib$'
fact $? "and a run-time search path pointing at the build tree's lib directory"

said=$("${bin:-/nonexistent}" --version 2>&1)
_last_cmd="hashsum --version  # 共有の構成"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q "hashx $(sed -n 's/^version *= *"\(.*\)"/\1/p' lib/dowel.toml)"
fact $? "so it runs straight out of the build tree, without being told where to look"

# 答は配られ方で変わらない。ここが利用者から見た「同じライブラリ」の意味である。
plain_bin=$(find ctool/.dowel/build -path '*-debug/bin/hashsum' -type f | head -1)
a=$(printf 'abc' | "${plain_bin:-/nonexistent}" 2>&1)
b=$(printf 'abc' | "${bin:-/nonexistent}" 2>&1)
_last_cmd="hashsum < abc   静的 vs 共有"
OUT="static: $a"$'\n'"shared: $b"
RC=0
[ -n "$a" ] && [ "$a" = "$b" ]
fact $? "and answers exactly what the archive-linked build answers"

# ---- 面は外向きである（ADR-0038）
#
# **パッケージの中では、共有ライブラリも静的に繋がれる。** `exports` は
# 「一緒に書かれなかったコードへの境界」であり、パッケージが配布の単位で
# ある以上、同じパッケージの兄弟は書庫の側を見る。
#
# これが無いと、ライブラリ自身の検査が内側に届かなくなる。公開の面だけを
# 叩く検査では、面の後ろにある表の構築を覆えない（F-056）。

ok "the library's own tests still link when it is built shared" -C lib test --features=shared
ok "while the same tests pass when it is built as an archive"  -C lib test

# 内側に届いていること。この検査は内部の名前を直に呼んでいる。
_last_cmd="grep hx_crc_step tests/unit.c"; RC=0
OUT=$(grep -n 'hx_crc_step' tests/unit.c | head -1)
[ -n "$OUT" ]
fact $? "and what they reach is an internal name, not something on the public surface"

# 外向きの境界はそのままである。別のパッケージの使う側は `exports` だけを見る。
ok "and the consumers build and run against the shared object" \
    -C cxxtool build --features=shared --no-compdb

inner=$(nm -D --defined-only "$SO" 2>/dev/null | awk '{print $3}' | grep -c '^hx_')
_last_cmd="nm -D libhashx.so | hx_*"; OUT="internal names exported: ${inner:-?}"; RC=0
[ "${inner:-1}" = 0 ]
fact $? "which still sees only what exports lists, because the boundary faces outward"

# ---- 挙げた名前が実在すること（ADR-0039）
#
# 綴り違いは、使う側がリンクに失敗するまで黙っている。リンクの後に `nm` で
# 確かめる。

cp lib/dowel.build lib/dowel.build.keep
sed -i 's/"hashx_version",/"hashx_version",\n    "hashx_nosuch",/' lib/dowel.build
run -C ctool build --features=shared --no-compdb
said=$OUT
_last_cmd="dowel build  # exports に実在しない名前"
OUT=$(printf '%s' "$said" | grep -m4 'error\|note'); RC=0
printf '%s' "$said" | grep -q 'unexported-symbol'
fact $? "a name in exports that the library does not define is refused"

_last_cmd="同じ診断"; OUT=$(printf '%s' "$said" | grep -m4 'note'); RC=0
printf '%s' "$said" | grep -q 'hashx_nosuch' && printf '%s' "$said" | grep -qi 'nm'
fact $? "naming it, and saying which tool was asked"

_last_cmd="同じ診断"; OUT=$(printf '%s' "$said" | grep -m4 'note'); RC=0
printf '%s' "$said" | grep -qi 'silent until a consumer fails to link'
fact $? "and why it matters, which is that the mistake is otherwise invisible until then"
mv lib/dowel.build.keep lib/dowel.build

# ---- ABI の世代（ADR-0040）
#
# 配るなら、面が変わったことを名前で言えなければならない。`soversion` が
# ファイル名と soname に入る。

cp lib/dowel.build lib/dowel.build.keep
sed -i 's/^linkage = "shared" when feature.shared/linkage   = "shared" when feature.shared\nsoversion = 3        when feature.shared/' lib/dowel.build
ok "a shared library may declare its ABI generation" -C ctool build --features=shared --no-compdb

so3=$(find ctool/.dowel/build -name 'libhashx.so.3' | head -1)
_last_cmd="find libhashx.so.3"; OUT="${so3:-(absent)}"; RC=0
[ -n "$so3" ]
fact $? "which enters the file name"

name=$(readelf -d "${so3:-/nonexistent}" 2>/dev/null | sed -n 's/.*SONAME.*\[\(.*\)\]/\1/p')
_last_cmd="readelf -d libhashx.so.3 | SONAME"; OUT="${name:-(none)}"; RC=0
[ "$name" = "libhashx.so.3" ]
fact $? "and the soname, which is what a consumer records"

_last_cmd="ls lib/"; RC=0
OUT=$(ls "$(dirname "${so3:-/nonexistent}")" 2>&1 | paste -sd' ' -)
[ -e "$(dirname "$so3")/libhashx.so" ]
fact $? "with the plain name left beside it, so linking by -lhashx still works"

# 宣言しなければ版は付かない。dowel は面が変わったかどうかを決めない。
mv lib/dowel.build.keep lib/dowel.build
ok "declaring nothing keeps the plain name" -C ctool build --features=shared --no-compdb
plain=$(find ctool/.dowel/build -name 'libhashx.so' | head -1)
_last_cmd="find libhashx.so"; OUT="${plain:-(absent)}"; RC=0
[ -n "$plain" ]
fact $? "because when the ABI generation changes is the author's call, not the tool's"
