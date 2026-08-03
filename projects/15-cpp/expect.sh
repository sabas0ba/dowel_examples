# 15-cpp — C++
#
# かつて C++ のソースは黙って `cc` に渡され、リンクで
# `undefined reference to std::...` になっていた（docs/10-findings.md F-008）。
# 報告時に挙げた2案のうち、短期には「診断で拒む」が妥当と書いたところ、
# 一度は `unsupported-language` として拒む形で決着し、その後
# **C++ を組めるようにする**側が採られた。
#
# ここで見るのは、その C++ 対応が「拡張子で選ぶ」だけで終わっていないか
# である。難しいのは翻訳ではなくリンクの側にある。
#
#   - コンパイラはソースごとに拡張子で選ばれる
#   - **リンクは依存の閉包に C++ の翻訳単位が居るかどうかで決まる**
#   - C++ のツールチェーンは C++ のソースがあるときだけ要求される
#
# 2番目が F-008 の失敗様式そのものである。純 C の実行ファイルでも、
# C++ のライブラリに依存していれば C++ の driver でリンクしなければ、
# 標準ライブラリが繋がらない。

# 追加で渡す dowel の引数。`--target` を伴う場合に使う。
EXTRA=""

# cc_of <パッケージ> <ソース名の一部> — その翻訳単位を組む driver。
cc_of() {
    # shellcheck disable=SC2086
    "$DOWEL" -C "$1" graph --kind=action --format=json $EXTRA 2>/dev/null |
        jq -r --arg s "$2" '.actions[] | select(.kind == "cc")
            | select(.command | map(select(test($s))) | length > 0)
            | .command[0]' | head -1
}

# link_of <パッケージ> — リンクを行う driver。
link_of() {
    # shellcheck disable=SC2086
    "$DOWEL" -C "$1" graph --kind=action --format=json $EXTRA 2>/dev/null |
        jq -r '.actions[] | select(.kind == "link") | .command[0]' | head -1
}

# driver_is <期待> <パッケージ> <ソース名の一部> <desc>
driver_is() {
    local got; got=$(cc_of "$2" "$3")
    [ "$got" = "$1" ]; local v=$?
    RC=0; _last_cmd="graph --kind=action | .command[0]"; OUT="driver = ${got:-(none)}"
    _verdict $v "$4"
}

# ------------------------------------------------------- 拡張子で選ぶ
#
# 表は本体の文書にある。C++ は `.cc` `.cp` `.cpp` `.cxx` `.c++` `.CPP` `.C`。
# `.C` だけが大文字1文字であり、`.c` と1文字違いで意味が反転する。

ok "a package of mixed extensions passes check" -C exts check

for pair in one:cc two:cp three:cpp four:cxx five:c++ six:CPP seven:C; do
    name=${pair%%:*}; ext=${pair##*:}
    driver_is c++ exts "/$name\\.$(printf '%s' "$ext" | sed 's/[+]/\\+/g')$" \
        "a .$ext source is compiled by the C++ driver"
done
driver_is cc exts '/plain\.c$' "a .c source is still compiled by the C driver"

# ------------------------------------------------------- C++ だけのライブラリ

ok "a C++ library passes check" -C cpplib check
ok "a C++ library builds"       -C cpplib build
driver_is c++ cpplib '/lib\.cpp$' "the C++ source of the library uses the C++ driver"

# ------------------------------------------------------- 純 C の実行ファイル + C++ の依存
#
# F-008 の失敗様式である。ソースは C だけなので、拡張子だけを見ていると
# C の driver でリンクしてしまい、標準ライブラリが繋がらない。

ok "a C binary that depends on a C++ library passes check" -C capp check
driver_is cc capp '/main\.c$' "its own source is compiled by the C driver"

got=$(link_of capp)
[ "$got" = c++ ]; v=$?
RC=0; _last_cmd="graph --kind=action | select(.kind==\"link\")"; OUT="link driver = ${got:-(none)}"
_verdict $v "but the link uses the C++ driver because a dependency is C++"

# 引数の形ではなく、実際に繋がっていることを見る。記号が解決するだけでは
# 足りない。例外の巻き戻しと大域構築子は、リンクの driver を取り違えると
# 記号が揃っていても働かない。
#
#   cpplib_len       標準ライブラリ
#   cpplib_throws    送出と捕捉（巻き戻しの機構）
#   cpplib_ctor_ran  書庫の中の大域オブジェクトの構築子（.init_array）
#
# 判定は C の中で行い、終了状態でどれが欠けたかまで分かるようにしてある。
ok "the binary links and runs" -C capp build
ok "a C main gets the whole C++ runtime, not just the symbols" -C capp build
prints "" "running it exercises the standard library, exceptions and constructors" \
    "$PWD/capp/$(cd capp 2>/dev/null && find .dowel/build -type f -path '*/bin/capp' | head -1)"
ok "a C test can call into the C++ library and pass" -C capp test
out_lacks "undefined reference" "the link never fails the way F-008 did" -C capp build

# ------------------------------------------------------- 1つのターゲットに混在

ok "a target holding both C and C++ sources passes check" -C mixed check
driver_is cc  mixed '/c_part\.c$'    "the C source of a mixed target uses the C driver"
driver_is c++ mixed '/cxx_part\.cpp$' "the C++ source of a mixed target uses the C++ driver"
got=$(link_of mixed)
[ "$got" = c++ ]; v=$?
RC=0; OUT="link driver = ${got:-(none)}"
_verdict $v "a mixed target links with the C++ driver"

# C の側で確かめる。C の翻訳単位で __cplusplus が定義されていたら、
# 拡張子による選択が効いていない。成果物自身に答えさせる。
# 終了状態に両方の値を載せてある（C 側 × 10 + C++ 側）。片方だけが
# 古いまま残っても、片方が誤った driver で組まれても、値が変わる。
ok "the mixed binary agrees about which unit was compiled as what" -C mixed build
mixed_exit() {
    local p; p=$(find "$PWD/mixed/.dowel/build" -type f -path '*/bin/mixed' 2>/dev/null | head -1)
    [ -n "$p" ] || return 99
    "$p"; return $?
}
mixed_exit; got=$?
[ "$got" = 13 ]; v=$?
RC=0; _last_cmd="<mixed>"; OUT="the binary exits with $got (wanted 13 = C 1, C++ 3)"
_verdict $v "the mixed binary runs and its C and C++ halves both behave"

# ------------------------------------------------------- ツールチェーンの宣言

driver_is c++ cpplib '/lib\.cpp$' "cxx defaults to c++ when nothing is declared"

printf '[package]\nname    = "cpplib"\nversion = "0.1.0"\nedition = "2026"\n\n[toolchain]\ncxx = "clang++"\n' \
    > cpplib/dowel.toml
driver_is clang++ cpplib '/lib\.cpp$' "a declared cxx is what gets invoked"
ok "the library builds with the declared cxx" -C cpplib build

# `tc.cxx` は構成の語彙に入っている。宣言によって具体化を変えられなければ、
# 双方のコンパイラに対応するマニフェストは書けない。
cp cpplib/dowel.build cpplib/dowel.build.bak
printf '\n[lib.cpplib.private]\nflags = [match tc.cxx { "clang++" => "-DVIA_CLANGXX", _ => "-DVIA_OTHER" }]\n' \
    >> cpplib/dowel.build
args_have_cxx() {
    OUT=$("$DOWEL" -C cpplib graph --kind=action --format=json 2>/dev/null |
        jq -r '.actions[] | select(.kind == "cc") | .command | join(" ")')
    RC=0; _last_cmd="graph --kind=action | grep -F -- $1"
    printf '%s' "$OUT" | grep -qF -- "$1"; _verdict $? "$2"
}
args_have_cxx "-DVIA_CLANGXX" "match on tc.cxx follows the declaration"
printf '[package]\nname    = "cpplib"\nversion = "0.1.0"\nedition = "2026"\n' > cpplib/dowel.toml
args_have_cxx "-DVIA_OTHER" "and follows the default when nothing is declared"
mv cpplib/dowel.build.bak cpplib/dowel.build

# ------------------------------------------------------- 要求されるのは要るときだけ
#
# 「C++ のツールチェーンは C++ のソースがあるときだけ要求され、
# そのときだけ探される」。C しか書いていない利用者に C++ コンパイラの
# 用意を強いるなら、それは C 専用の構成が組めないということである。

printf '[package]\nname    = "cpplib"\nversion = "0.1.0"\nedition = "2026"\n\n[toolchain]\ncxx = "no-such-cxx-19"\n' \
    > cpplib/dowel.toml
fails "a C++ package with a missing cxx is refused" -C cpplib check
diag missing-toolchain "the refusal carries the missing-toolchain code" -C cpplib check
diag_where missing-toolchain '.labels | length > 0' \
    "the refusal points at the declaration" -C cpplib check
out_lacks "not found" "the missing C++ compiler never reaches the shell" -C cpplib build

# 同じ宣言でも、C++ のソースが1つも無ければ探されない。
printf '[package]\nname    = "mixed"\nversion = "0.1.0"\nedition = "2026"\n\n[toolchain]\ncxx = "no-such-cxx-19"\n' \
    > mixed/dowel.toml
mv mixed/src/cxx_part.cpp mixed/cxx_part.cpp.hidden
printf '#include "parts.h"\nint cxx_part(void) { return 3; }\n' > mixed/src/cxx_part.c
ok "a package with no C++ sources ignores a broken cxx declaration" -C mixed check
ok "and still builds" -C mixed build

rm -f mixed/src/cxx_part.c
mv mixed/cxx_part.cpp.hidden mixed/src/cxx_part.cpp
printf '[package]\nname    = "mixed"\nversion = "0.1.0"\nedition = "2026"\n' > mixed/dowel.toml
printf '[package]\nname    = "cpplib"\nversion = "0.1.0"\nedition = "2026"\n' > cpplib/dowel.toml

# ------------------------------------------------------- 推移的な閉包
#
# 「依存の閉包に C++ の翻訳単位があれば」であって「直接の依存が C++ なら」
# ではない。間に純 C の層を挟むと、直接の依存だけを見る実装は取りこぼす。
#
#   topc[C] -> mid[C] -> deep[C++]
#
# topc は C++ のライブラリを直接には知らない。

ok "a chain of C packages over a C++ leaf passes check" -C chain/topc check
driver_is c++ chain/topc '/deep\.cpp$' "the C++ leaf of the chain uses the C++ driver"
driver_is cc  chain/topc '/mid\.c$'    "the C layer between them uses the C driver"
driver_is cc  chain/topc '/main\.c$'   "and so does the root"

got=$(link_of chain/topc)
[ "$got" = c++ ]; v=$?
RC=0; OUT="link driver = ${got:-(none)}"
_verdict $v "the root links with the C++ driver although its dependency is C"

ok "the chain builds and its test passes" -C chain/topc build
prints "" "the root binary runs through two C layers into C++" \
    "$PWD/chain/topc/$(cd chain/topc 2>/dev/null && find .dowel/build -type f -path '*/bin/topc' | head -1)"

# ------------------------------------------------------- 逆向き
#
# C++ の実行ファイルが C のライブラリを使う。こちらは自明に見えるが、
# 「C++ のソースがあるかどうか」だけで決めていると、依存の側が C である
# ことに引きずられる実装がありうる。

ok "a C++ binary that depends on a C library passes check" -C reverse/cxxapp check
driver_is cc  reverse/cxxapp '/c\.c$'      "the C dependency uses the C driver"
driver_is c++ reverse/cxxapp '/main\.cpp$' "the C++ binary uses the C++ driver"
got=$(link_of reverse/cxxapp)
[ "$got" = c++ ]; v=$?
RC=0; OUT="link driver = ${got:-(none)}"
_verdict $v "the link uses the C++ driver in this direction too"
ok "the C++ binary builds and runs" -C reverse/cxxapp build

# テストターゲット自体が C++ である場合。
ok "a test target written in C++ builds and passes" -C reverse/cxxapp test

# ------------------------------------------------------- 増分
#
# depfile は driver が出す。C++ の側でも同じように出て、同じように読まれ
# なければ、C++ のヘッダを編集しても波及しない。05-incremental は C だけを
# 見ているため、この経路は通っていない。
#
# 実行器は direct で通す。数えるために要るうえ、ninja と跨ぐと依存の記録が
# 引き継がれない（docs/10-findings.md F-014）。

MIXED=$PWD/mixed
mixed_ran() {
    OUT=$("$DOWEL" -C mixed build --executor=direct --log-level=debug 2>&1)
    RC=$?
    _last_cmd="dowel -C mixed build --executor=direct"
    printf '%s' "$OUT" | sed -n 's/.*ran \([0-9]*\) actions.*/\1/p' | tail -1
}
mixed_says() {
    local p; p=$(find "$MIXED/.dowel/build" -type f -path '*/bin/mixed' 2>/dev/null | head -1)
    [ -n "$p" ] || { printf 'none'; return 0; }
    "$p"; printf '%s' "$?"
}

rm -rf "$MIXED/.dowel"
n=$(mixed_ran); [ "${n:-0}" -gt 0 ]; _verdict $? "the mixed target builds from scratch"
n=$(mixed_ran); [ "$n" = 0 ]; _verdict $? "and settles"

# depfile が C++ の翻訳単位にも出ていること。
if find "$MIXED/.dowel" -name '*cxx_part.cpp.o.d' | grep -q .; then
    fact 0 "a depfile is written for the C++ translation unit too"
else
    fact 1 "a depfile is written for the C++ translation unit too"
fi

# C++ だけが読むヘッダを編集する。C 側は組み直す必要が無い。
sed -i 's/#define CXX_VALUE .*/#define CXX_VALUE 4/' "$MIXED/include/cxx_only.h"
n=$(mixed_ran); [ "${n:-0}" -gt 0 ]
_verdict $? "editing a header that only C++ reads rebuilds through the C++ depfile"
got=$(mixed_says); [ "$got" = 14 ]; v=$?
RC=0; OUT="the binary says $got (wanted 14)"
_verdict $v "and the artifact reflects the new value"

# C だけが読むヘッダ。
sed -i 's/#define C_VALUE .*/#define C_VALUE 2/' "$MIXED/include/c_only.h"
n=$(mixed_ran); [ "${n:-0}" -gt 0 ]
_verdict $? "editing a header that only C reads rebuilds through the C depfile"
got=$(mixed_says); [ "$got" = 24 ]; v=$?
RC=0; OUT="the binary says $got (wanted 24)"
_verdict $v "and the artifact reflects that too"

sed -i 's/#define CXX_VALUE .*/#define CXX_VALUE 3/' "$MIXED/include/cxx_only.h"
sed -i 's/#define C_VALUE .*/#define C_VALUE 1/' "$MIXED/include/c_only.h"
run -C mixed build --executor=direct

# ------------------------------------------------------- ほかのツールチェーン
#
# 10-toolchain は C について gcc と clang の双方を見る。C++ の側にも
# 同じことが要る。C と C++ で別のコンパイラを選ぶ構成も通る必要がある。

CPPLIB_TOML=$PWD/cpplib/dowel.toml
with_tc() {
    printf '[package]\nname    = "cpplib"\nversion = "0.1.0"\nedition = "2026"\n\n[toolchain]\nc   = "%s"\ncxx = "%s"\n' \
        "$1" "$2" > "$CPPLIB_TOML"
}

with_tc gcc g++
driver_is g++ cpplib '/lib\.cpp$' "g++ is used when it is declared"
ok "the library builds with g++" -C cpplib build

with_tc clang clang++
driver_is clang++ cpplib '/lib\.cpp$' "clang++ is used when it is declared"
ok "the library builds with clang++" -C cpplib build

# C は gcc、C++ は clang++。混ぜても通ること。
with_tc gcc clang++
driver_is clang++ cpplib '/lib\.cpp$' "the C and C++ compilers can come from different families"
ok "the library builds with a mixed pair" -C cpplib build

printf '[package]\nname    = "cpplib"\nversion = "0.1.0"\nedition = "2026"\n' > "$CPPLIB_TOML"

# ------------------------------------------------------- クロス + C++
#
# 11-cross は C だけを見る。クロスで C++ を組むと、driver の選択と
# トリプルの選択が同時に効く。純 C のテストが別アーキテクチャ向けの
# C++ ライブラリを使い、qemu 経由で走るところまで通す。

TRIPLE=aarch64-unknown-linux-gnu
ok "a cross C++ package passes check" -C cross/xapp check --target=$TRIPLE
EXTRA="--target=$TRIPLE"
driver_is aarch64-linux-gnu-g++ cross/xapp '/x\.cpp$' \
    "the cross C++ compiler is used for the C++ source"
driver_is aarch64-linux-gnu-gcc cross/xapp '/x\.c$' \
    "the cross C compiler is used for the C source"

got=$(link_of cross/xapp)
[ "$got" = aarch64-linux-gnu-g++ ]; v=$?
RC=0; OUT="link driver = ${got:-(none)}"
_verdict $v "the cross link uses the cross C++ driver"

ok "the cross C++ build produces an artifact" -C cross/xapp build --target=$TRIPLE
art=$(find "$PWD/cross/xapp/.dowel/build/$TRIPLE"*/bin -type f 2>/dev/null | head -1)
got=$(readelf -h "$art" 2>/dev/null | sed -n 's/ *Machine: *//p')
case $got in *AArch64*) v=0 ;; *) v=1 ;; esac
RC=0; OUT="machine = ${got:-(no artifact)}"
_verdict $v "the cross C++ artifact is built for the target architecture"

ok "the cross C++ test runs under the emulator and passes" -C cross/xapp test --target=$TRIPLE
EXTRA=""

# 書庫の道具（`[toolchain] ar`）は 18-tools が見る。C++ に固有の性質では
# なく、ツールチェーンの道具一般の話であるため、そちらへ集めてある。
