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

# cc_of <パッケージ> <ソース名の一部> — その翻訳単位を組む driver。
cc_of() {
    "$DOWEL" -C "$1" graph --kind=action --format=json 2>/dev/null |
        jq -r --arg s "$2" '.actions[] | select(.kind == "cc")
            | select(.command | map(select(test($s))) | length > 0)
            | .command[0]' | head -1
}

# link_of <パッケージ> — リンクを行う driver。
link_of() {
    "$DOWEL" -C "$1" graph --kind=action --format=json 2>/dev/null |
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

# 引数の形ではなく、実際に繋がっていることを見る。C++ 実行時が欠けていれば
# リンクで落ち、通っても std::string を使う関数が動かない。
ok "the binary links and runs" -C capp build
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
ok "the mixed binary agrees about which unit was compiled as what" -C mixed build
prints "" "the mixed binary runs and its C and C++ halves both behave" \
    "$PWD/mixed/$(cd mixed && find .dowel/build -type f -path '*/bin/mixed' | head -1)"

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
