# 10-toolchain — gcc と clang の双方
#
# 本体のフィクスチャと CI は `cc` だけを使う。`cc` が何を指すかは機械による
# ため、実際に検査されているのは「その機械の既定のコンパイラ」1つだけである。
#
# ここで見るのは、**宣言したツールチェーンが実際に使われるか**である。
# 答はマニフェストではなく成果物が持っている。C の側で `__clang__` /
# `__GNUC__` を見て、翻訳したのがどちらかを成果物自身に言わせる。
#
# 併せて、ツールチェーンが記録された入力であること（切り替えたら組み直す）と、
# `tc.c` による具体化がその宣言に追随することを見る。

SUBJECT=$PWD/subject
TOML_HEAD='[package]
name    = "subject"
version = "0.1.0"
edition = "2026"

[toolchain]
c = '

# use <コンパイラ> — [toolchain] c を書き換える。
use() { printf '%s"%s"\n' "$TOML_HEAD" "$1" > "$SUBJECT/dowel.toml"; }

# in_subject <dowel args...> — subject/ に対して走らせる。
in_subject() { run -C subject "$@"; }

# built_by — 組み上がった成果物を起動し、自分を名乗らせる。
# `which.h` が `__clang__` / `__GNUC__` を見るため、答えるのは
# マニフェストの宣言ではなく実際に翻訳したコンパイラである。
built_by() {
    local p
    p=$(find "$SUBJECT/.dowel/build" -type f -path '*/bin/subject' 2>/dev/null | head -1)
    [ -n "$p" ] || { printf '(no artifact)'; return 0; }
    "$p"
}

# cc0 <dowel args...> — コンパイル行の argv[0]。宣言が実際の起動に届いたか。
cc0() {
    "$DOWEL" -C subject graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r '.steps[] | select(.kind == "cc") | .program' | sort -u
}

# ---------------------------------------------------------- 双方で通ること
#
# まず両方が同じように使えること。片方でしか組めないなら、
# 以降の比較には意味が無い。

for tc in gcc clang; do
    use "$tc"
    rm -rf "$SUBJECT/.dowel"

    ok    "$tc: check passes"  -C subject check
    ok    "$tc: build passes"  -C subject build

    # 宣言が起動に届くこと。ここが `cc` のままなら、宣言は飾りである。
    got=$(cc0); [ "$got" = "$tc" ]; v=$?
    RC=0; _last_cmd="graph --kind=action | .program"; OUT="argv[0] = $got"
    fact $v "$tc: the declared toolchain is what gets invoked"

    # 成果物が自分を名乗る。マニフェストではなく生成物に答えさせる。
    got=$(built_by); [ "$got" = "$tc" ]; v=$?
    RC=0; _last_cmd="<artifact>"; OUT="the artifact says $got"
    fact $v "$tc: the artifact was translated by the declared compiler"

    # テストの側でも同じことを見る。EXPECTED はマニフェストが `tc.c` から
    # 与え、COMPILED_BY は実物が与える。突き合わせは C の中で起きるため、
    # 期待値をハーネスと二重に持たない。
    ok "$tc: the artifact agrees with the declaration, checked in C" -C subject test
done

# ---------------------------------------------------------- 宣言に追随する具体化
#
# `tc.c` は開いた語彙である（`schema dump`）。宣言したツールチェーンによって
# フラグを変えられなければ、双方に対応するマニフェストは書けない。
# clang にしか無い警告名と gcc にしか無い警告名を置いてある。

use clang
args_have_cc() {
    OUT=$("$DOWEL" -C subject graph --kind=action --format=json 2>/dev/null |
        jq -r '.steps[] | select(.kind == "cc") | ([.program] + .arguments) | join(" ")')
    RC=0
    _last_cmd="graph --kind=action | grep -F -- $1"
    printf '%s' "$OUT" | grep -qF -- "$1"; _verdict $? "$2"
}
args_have_cc "-Wno-unknown-warning-option" "match on tc.c picks the clang arm"
use gcc
args_have_cc "-Wno-unused-but-set-variable" "match on tc.c picks the gcc arm"

# 相手のコンパイラには通らない語を選んでいる。取り違えていれば組めない。
use clang
ok "the clang arm actually compiles under clang" -C subject build
use gcc
ok "the gcc arm actually compiles under gcc" -C subject build

# ---------------------------------------------------------- 記録された入力
#
# ツールチェーンは結果を決める入力である。切り替えたのに組み直さなければ、
# 前のコンパイラが作った成果物が次のコンパイラの結果として残る。

use gcc
rm -rf "$SUBJECT/.dowel"
run -C subject build
use clang
runs_actions_in_subject() {
    local want=$1 desc=$2; shift 2
    OUT=$("$DOWEL" -C subject build --backend=direct --log-level=debug "$@" 2>&1)
    RC=$?
    local got; got=$(printf '%s' "$OUT" | sed -n 's/.*ran \([0-9]*\) steps.*/\1/p' | tail -1)
    if [ "$RC" -ne 0 ]; then
        _verdict 1 "$desc (the build failed)"
    elif [ "$want" = "+" ]; then
        [ "${got:-0}" -gt 0 ]; _verdict $? "$desc"
    else
        [ "$got" = "$want" ]; _verdict $? "$desc"
    fi
}
runs_actions_in_subject + "switching the toolchain rebuilds"

# 切り替えた先でも、成果物は新しいコンパイラのものになっている。
got=$(built_by); [ "$got" = clang ]; v=$?
RC=0; _last_cmd="<artifact>"; OUT="the artifact says $got"
fact $v "the rebuilt artifact is the one the new toolchain produced"

# 同じ宣言のまま組み直せば何も走らない。切り替えを検出する仕組みが
# 「毎回全部組み直す」で実現されていないことを見る。
runs_actions_in_subject 0 "building again with the same toolchain runs nothing"

# 戻したときも組み直す。古い成果物を再利用すると、宣言と中身が食い違う。
use gcc
runs_actions_in_subject + "switching back rebuilds as well"
got=$(built_by); [ "$got" = gcc ]; v=$?
RC=0; _last_cmd="<artifact>"; OUT="the artifact says $got"
fact $v "switching back gives the earlier compiler's artifact again"

# ---------------------------------------------------------- 双方で増分が効く
#
# depfile の書式は両者で異なりうる。片方でしか波及を追えないなら、
# もう片方の利用者は編集のたびに全部組み直すか、古い成果物を掴む。
#
# 実行器は direct で通す。数えるために direct が要るうえ、ninja と direct を
# 跨ぐと依存の記録が引き継がれない（docs/10-findings.md F-014）。
# ここで見たいのはコンパイラの違いであって、実行器の違いではない。

for tc in gcc clang; do
    use "$tc"
    rm -rf "$SUBJECT/.dowel"
    runs_actions_in_subject + "$tc: a first build runs every action"
    runs_actions_in_subject 0 "$tc: a second build runs nothing"
    printf '\n/* touched */\n' >> "$SUBJECT/include/which.h"
    runs_actions_in_subject + "$tc: editing a header rebuilds through the depfile"
    runs_actions_in_subject 0 "$tc: and settles again"
done

# ---------------------------------------------------------- 実在しないもの

use no-such-compiler-19
fails "a toolchain that does not exist is refused" -C subject check
diag missing-toolchain "the refusal carries the missing-toolchain code" -C subject check
diag_where missing-toolchain '.labels | length > 0' \
    "the refusal points at the declaration" -C subject check
out_lacks "not found" "the missing toolchain never reaches the shell" -C subject build

use gcc

# ---------------------------------------------------------- 取ってくる（ADR-0044 / ADR-0047）
#
# `[toolchain.<triple>]` は機械に既に在る命令を名指すものだった。マニフェスト
# は固定され、ソースも固定され、依存は `rev` や `sha256` で固定される——そして
# **目的コードを決める唯一の入力だけが、その名前で機械に在ったもの**だった。
# 同じ README に従った2人が違うバイナリを得ても、木は何も言わない。
#
# 決定は「toolchain は依存と同じやり方で取ってきて固定する」。書庫と digest
# であり、新しい機構は要らない。
#
# 本物の cross の書庫は数百 MB あるので、kit/ に偽物を組み立てる。確かめたい
# のは中身ではなく、**取得・検証・展開・その中からの解決**である。

TCDIR=$PWD/tcfetch
KIT=$PWD/kit.tar.gz
mkdir -p "$TCDIR/src"
cp kitsrc.c "$TCDIR/src/main.c"
tar czf "$KIT" kit
KITSUM=$(sha256sum "$KIT" | cut -d' ' -f1)

# 取ってきたものは利用者のキャッシュへ入る。木ごとに持つと、系の中で最も
# 安定したものを最も揺れる場所へ何度も落とすことになる。
export XDG_CACHE_HOME=$PWD/tccache

cat > "$TCDIR/dowel.build" <<'EOF'
[bin.app]
sources = [file("src/main.c")]

[bin.app.private]
flags = ["-I", sysroot("usr/include")]
EOF

# tc_toml <鍵=値...> — 取ってくる toolchain の宣言を書く。省いた鍵は出ない。
tc_toml() {
    {
        printf '[package]\nname = "tcfetch"\nversion = "0.1.0"\nedition = "2026"\n\n'
        printf '[toolchain.x86_64-unknown-linux-gnu]\n'
        local kv
        for kv in "$@"; do printf '%s = "%s"\n' "${kv%%=*}" "${kv#*=}"; done
    } > "$TCDIR/dowel.toml"
}
tc_full() { tc_toml "url=file://$KIT" "sha256=$KITSUM" c=bin/kitcc "sysroot=sysroot"; }

# --- 取ってきて、その中から解決する

tc_full
rm -rf "$TCDIR/.dowel" "$PWD/tccache"
ok "a toolchain declared with a url and a sha256 builds" -C tcfetch build --no-compdb
prints "42" "and the program it produced runs" \
       "$(find "$TCDIR/.dowel/build" -type f -name app | head -1)"

# 命令は書庫の中から選ばれている。機械の `cc` が使われたのでは、
# 取ってきた意味が無い。
_last_cmd="graph --kind=action | the compiler"
OUT=$("$DOWEL" -C tcfetch graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc") | .program'); RC=0
said=$OUT
printf '%s' "$said" | grep -q 'toolchains/'
fact $? "the compiler is resolved inside what was unpacked"
printf '%s' "$said" | grep -q 'bin/kitcc$'
fact $? "and it is the one the declaration named"

# 置き場は利用者のキャッシュであり、木の中ではない。同じ書庫は
# どの木でも同じバイト列である。
n=$(find "$PWD/tccache/dowel/toolchains" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
_last_cmd="find \$XDG_CACHE_HOME/dowel/toolchains"; OUT="$n directories"; RC=0
[ "$n" -eq 1 ]
fact $? "what was unpacked lives in the user's cache, one directory per archive"
if [ -e "$TCDIR/.dowel/toolchains" ]; then
    fact 1 "and not inside the tree"
else
    fact 0 "and not inside the tree"
fi

# 2度目は取りに行かない。書庫を消しても組める。
mv "$KIT" "$KIT.moved"
ok "a later build never reaches for the archive again" -C tcfetch build --no-compdb
mv "$KIT.moved" "$KIT"

# --- sysroot（ADR-0047）
#
# cross では sysroot は飾りではない。対象の見出しとライブラリがそこに在り、
# 翻訳の行がそれを言わなければ、機械側の見出しを拾って後から失敗する。
# dowel には文字列の連結が無いので、`["-I", sysroot("...")]` の2語で書く。

_last_cmd="graph --kind=action | the compile line"
OUT=$("$DOWEL" -C tcfetch graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc") | (.arguments | join(" "))'); RC=0
said=$OUT
printf '%s' "$said" | grep -q 'toolchains/.*/sysroot/usr/include'
fact $? "sysroot() expands to a path under the fetched toolchain"

# 宣言が無ければ既定は無い。既定を置くと、何も宣言していない path が
# 命令行へ入り、失敗は翻訳器の言葉で返ってくる。
tc_toml "url=file://$KIT" "sha256=$KITSUM" c=bin/kitcc
diag missing-sysroot "writing sysroot() with none declared is refused" \
     -C tcfetch check
out_has "declare \`sysroot" "and says where to declare it" -C tcfetch check

# --- 固定されていないもの

tc_toml "url=file://$KIT" c=bin/kitcc "sysroot=sysroot"
diag unpinned-toolchain "a url without a sha256 is refused" -C tcfetch check
out_has "the bytes behind a name can change" \
        "and says why a url alone is not a pin" -C tcfetch check

# digest が合わなければ止まる。機械に在るものへ黙って退避すると、
# 宣言と違う翻訳器が宣言の裏で使われる——この決定が消そうとしたものである。
tc_toml "url=file://$KIT" "sha256=0000000000000000000000000000000000000000000000000000000000000000" \
        c=bin/kitcc "sysroot=sysroot"
rm -rf "$PWD/tccache"
diag unfetchable-toolchain "an archive whose digest does not match is refused" \
     -C tcfetch check
out_has "expected" "and shows what was expected and what arrived" -C tcfetch check

tc_toml "url=file:///nonexistent/none.tar.gz" "sha256=$KITSUM" c=bin/kitcc
diag unfetchable-toolchain "an archive that cannot be fetched is refused" \
     -C tcfetch check

# --- offline（ADR-0045）
#
# toolchain も「取ってきて印を置く」ものである以上、offline の対象である。

tc_full
rm -rf "$PWD/tccache"
diag needs-fetch "a toolchain that is not fetched is refused under --offline" \
     -C tcfetch check --offline

ok "fetch acquires the toolchain" -C tcfetch fetch
if [ -d "$PWD/tccache/dowel/toolchains" ]; then
    fact 0 "and it really is unpacked into the cache"
else
    fact 1 "and it really is unpacked into the cache"
fi
ok "after which the build runs offline" -C tcfetch build --offline --no-compdb

# `fetch` は「offline へ行ける」ことを見せるための入口である。取ってきた
# ものを数えず一覧もしないなら、利用者が読むのは「何も要らなかった」に
# なる（[F-065](../../docs/10-findings.md#f-065)）。
rm -rf "$PWD/tccache"
run -C tcfetch fetch
said=$OUT
known_issue F-065
! printf '%s' "$said" | grep -q 'fetched 0'
fact $? "fetch counts the toolchain it acquired"
run -C tcfetch fetch
known_issue F-065
printf '%s' "$OUT" | grep -q 'ready:.*toolchain\|toolchain.*ready'
fact $? "and lists it among what is now present"

rm -rf "$TCDIR" "$KIT" "$PWD/tccache"
