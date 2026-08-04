# 19-artifacts — 成果物から別の成果物を作る
#
# 組み込みでは、リンクの後に必ず1段ある。ELF を書き込み用の生イメージや
# Intel HEX に変え、あるいは剥いだ複製を作る。`[<kind>.<name>.artifacts]`
# はその1段をビルドグラフの**内側**に置く（dowel#60）。
#
# 内側に置くことで得られるものは3つ。18-tools が見る「道具の宣言」の上に
# 積み上がる性質である。
#
#   1. `dowel build` が作る。作り忘れが起きない
#   2. 元が変わらなければ走らない。増分に乗る
#   3. 道具は目標トリプルごとに選ばれる。ホストの objcopy が走らない
#
# 3 がこの機能の要である。外で objcopy を叩く限り、その道具は記録の外に
# あり、クロスの宣言も効かない。

TRIPLE=aarch64-unknown-linux-gnu
BUILD_BAK=$PWD/library-dowel.build.bak
cp library/dowel.build "$BUILD_BAK"

# ------------------------------------------------------------ 道具立て

# derived <パッケージ> <名前> — ビルドディレクトリの中のその派生ファイル。
derived() {
    find "$1/.dowel/build" -type f -name "$2" 2>/dev/null | head -1
}

# exists <パッケージ> <名前> <desc> — その派生が作られたこと。
exists() {
    local p; p=$(derived "$1" "$2")
    _last_cmd="find $1/.dowel/build -name $2"
    OUT="found: ${p:-(nothing)}"
    RC=0
    [ -n "$p" ]; _verdict $? "$3"
}

# transform_command <パッケージ> [dowel args...] — transform アクションの引数。
transform_command() {
    local dir=$1; shift
    "$DOWEL" -C "$dir" graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r '.actions[] | select(.kind == "transform") | .command | join(" ")'
}

# ------------------------------------------------------------ 1. 作られること

ok "a package with an artifacts block passes check" -C firmware check
ok "and builds"                                     -C firmware build --no-compdb

exists firmware 'image.bin' "an artifacts entry produces its derived file"
exists firmware 'image.hex' "a second entry produces a second file"

# 鍵は拡張子である。元の成果物の拡張子を置き換えたものが出る。
exists firmware 'image' "the artifact it derives from is still there"

# 元の ELF と生イメージは別物である。`objcopy -O binary` は節の中身だけを
# 出すため、ELF の魔法数が落ちる。走らせずに中身で確かめる。
elf=$(derived firmware 'image'); raw=$(derived firmware 'image.bin')
_last_cmd="head -c 4 <image> and <image.bin>"
OUT="elf: $(head -c 4 "$elf" 2>/dev/null | od -An -c | tr -s ' ')"$'\n'"raw: $(head -c 4 "$raw" 2>/dev/null | od -An -c | tr -s ' ')"
RC=0
head -c 4 "$elf" 2>/dev/null | grep -q 'ELF' && ! head -c 4 "$raw" 2>/dev/null | grep -q 'ELF'
fact $? "the raw image is not an ELF, so the transform really ran"

# 中身が元から来ていること。印はソースに埋めてある。
_last_cmd="grep -F DOWEL-ARTIFACT-MARKER <image.bin>"
OUT=""
RC=0
grep -qa 'DOWEL-ARTIFACT-MARKER' "$raw" 2>/dev/null
fact $? "the raw image carries what the source put in the artifact"

# Intel HEX は行指向の書式であり、各行が `:` で始まる。
hex=$(derived firmware 'image.hex')
_last_cmd="head -1 <image.hex>"
OUT="first line: $(head -1 "$hex" 2>/dev/null | cut -c1-32)"
RC=0
head -1 "$hex" 2>/dev/null | grep -q '^:'
fact $? "the hex image is in the format the second entry asked for"

# ------------------------------------------------------------ 2. 命令の形
#
# 入力と出力はマニフェストに書かない。実装が末尾に付ける（ADR-0008 の
# runner の転送と同じ規約）。書けてしまうと、書いた道と実装が付ける道の
# どちらが効くのかが利用者に分からなくなる。

cmd=$(transform_command firmware | grep -F -- '-O binary')
_last_cmd="graph --kind=action | select(.kind==\"transform\")"
OUT="$cmd"
RC=0
printf '%s' "$cmd" | grep -qE '^objcopy -O binary [^ ]+/image [^ ]+/image\.bin$'
fact $? "the command is the tool, then the args, then the input and the output"

# ------------------------------------------------------------ 3. 要るときだけ
#
# 派生を宣言していない木に objcopy を要求しない。`ar` が書庫を作るときだけ
# 要るのと同じ理屈である。

declare_objcopy() {
    { printf '[package]\nname    = "firmware"\nversion = "0.0.0"\n'
      [ -n "${1:-}" ] && printf '\n[toolchain]\nobjcopy = "%s"\n' "$1"
    } >firmware/dowel.toml
    return 0
}

declare_objcopy no-such-objcopy-19
fails "a declared objcopy that is not on PATH is refused" -C firmware check
diag missing-toolchain "the refusal carries the missing-toolchain code" -C firmware check
diag_where missing-toolchain '.message | test("objcopy")' \
    "the refusal names the object copier" -C firmware check

# 同じ宣言でも、派生を要求しない目標だけを組むなら探されない。
cp firmware/dowel.build firmware/dowel.build.bak
python3 - <<'PY'
p = "firmware/dowel.build"
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(t.split("[bin.image.artifacts]")[0]
    + '[bin.plain]\nsources = [file("src/plain.c")]\n')
PY
ok "a package with no artifacts block ignores a broken objcopy" -C firmware check
mv firmware/dowel.build.bak firmware/dowel.build
declare_objcopy

# ------------------------------------------------------------ 4. 誤った宣言

artifacts_is() {
    python3 - "$1" <<'PY'
import sys
p = "firmware/dowel.build"
t = open(p, encoding="utf-8").read()
head = t.split("[bin.image.artifacts]")[0]
open(p, "w", encoding="utf-8").write(head + "[bin.image.artifacts]\n" + sys.argv[1] + "\n")
PY
}
export ARTIFACTS_BAK
ARTIFACTS_BAK=$(sed -n '/\[bin\.image\.artifacts\]/,$p' firmware/dowel.build)

artifacts_is 'raw = { tool = "nosuchtool", args = [] }'
diag unknown-tool "a tool outside the toolchain table is refused" -C firmware check
diag_where unknown-tool '.notes | join(" ") | test("objcopy")' \
    "the refusal lists the tools that can be named" -C firmware check
diag_where unknown-tool '.notes | join(" ") | test("\\[toolchain\\]")' \
    "the refusal says the concrete command comes from the toolchain" -C firmware check

artifacts_is 'raw = { args = ["-O", "binary"] }'
diag missing-field "an entry with no tool is refused" -C firmware check

artifacts_is 'raw = "objcopy"'
diag type-mismatch "an entry that is not a table is refused" -C firmware check

python3 - <<'PY'
import os
p = "firmware/dowel.build"
t = open(p, encoding="utf-8").read()
head = t.split("[bin.image.artifacts]")[0]
open(p, "w", encoding="utf-8").write(head + os.environ["ARTIFACTS_BAK"] + "\n")
PY
ok "restoring the block makes it pass again" -C firmware check

# ------------------------------------------------------------ 5. 増分
#
# グラフに乗っているなら、元が変わらなければ走らない。外で叩く限り
# 得られない性質であり、この機能の眼目のひとつである。

rm -rf firmware/.dowel
"$DOWEL" -C firmware build --no-compdb >/dev/null 2>&1
runs_actions 0 "a second build re-runs no transform" -C firmware --no-compdb

# 元が変われば走る。しかも走るのは変換とその上流だけである。
printf '\nint touched(void) { return 1; }\n' >>firmware/src/image.c
build_direct -C firmware --no-compdb
rebuilt "OBJCOPY" "editing the source re-makes the derived file"

# 宣言そのものが記録された入力であること。引数を変えたら作り直す。
artifacts_is 'bin = { tool = "objcopy", args = ["-O", "srec"] }
hex = { tool = "objcopy", args = ["-O", "ihex"] }'
build_direct -C firmware --no-compdb
rebuilt "OBJCOPY" "changing the args re-makes the derived file"
not_rebuilt "CC" "and does not recompile anything"

python3 - <<'PY'
import os
p = "firmware/dowel.build"
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(t.split("[bin.image.artifacts]")[0]
    + os.environ["ARTIFACTS_BAK"] + "\n")
PY

# ------------------------------------------------------------ 6. トリプルごと
#
# ここが外で叩くのとの決定的な差である。別アーキテクチャの ELF を
# ホストの objcopy が扱うと、黙って誤ったイメージが出うる。

cross_cmd=$(transform_command cross --target=$TRIPLE)
_last_cmd="dowel -C cross graph --kind=action --target=$TRIPLE"
OUT="$cross_cmd"
RC=0
printf '%s' "$cross_cmd" | grep -q '^aarch64-linux-gnu-objcopy '
fact $? "a cross build transforms with the objcopy declared for that triple"

# マニフェストは道具の名前しか書いていない。コマンドは宣言から来る。
_last_cmd="grep -F aarch64 cross/dowel.build"
OUT=$(grep -nF 'aarch64' cross/dowel.build 2>&1)
RC=0
[ -z "$OUT" ]
fact $? "the artifacts block never names the cross tool itself"

ok "the cross build produces its image" -C cross build --no-compdb --target=$TRIPLE
exists cross 'image.bin' "the derived file of a cross build is produced too"

# ホスト向けに組めば、同じマニフェストがホストの道具を使う。
host_cmd=$(transform_command cross)
_last_cmd="dowel -C cross graph --kind=action"
OUT="$host_cmd"
RC=0
printf '%s' "$host_cmd" | grep -q '^objcopy '
fact $? "and the same manifest uses the host objcopy for a host build"

# ------------------------------------------------------------ 7. ライブラリの派生 (F-022)
#
# 派生が作られるかどうかは、そのターゲット自身の宣言で決まるはずである。
# ところが現状は、別のターゲットが自分に依存しているかどうかで変わる。

rm -rf library/.dowel
ok "a library with an artifacts block builds on its own" -C library build --no-compdb
exists library 'libpart.stripped' "a standalone library produces its derived file"

# そのライブラリを使う実行ファイルを足す。artifacts の宣言は動かさない。
cat >>library/dowel.build <<'EOF'

[bin.user]
sources = [file("src/user.c")]

[bin.user.private]
deps = [target("part")]
EOF
rm -rf library/.dowel
ok "adding a binary that uses it still builds" -C library build --no-compdb
exists library 'libpart.a' "the library archive is still produced as a dependency"

p=$(derived library 'libpart.stripped')
_last_cmd="find library/.dowel/build -name libpart.stripped"
OUT="found: ${p:-(nothing)}"
RC=0
[ -n "$p" ]
verdict=$?
known_issue F-022
fact $verdict "a library keeps producing its derived file when a binary depends on it"

# 名指しすれば作られる。宣言ではなく到達の仕方が答を決めている。
rm -rf library/.dowel
ok "naming the library explicitly builds it" -C library build --no-compdb part
exists library 'libpart.stripped' "and then the derived file appears"

cp "$BUILD_BAK" library/dowel.build
