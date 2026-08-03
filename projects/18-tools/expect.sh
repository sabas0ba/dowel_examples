# 18-tools — ツールチェーンを構成する道具
#
# `[toolchain]` が名指しできる道具は表（`dowel_eval::config::TOOLS`）で
# 決まっている。現在は C コンパイラ・C++ コンパイラ・archiver の3つ。
#
# 表に載ることで得られる性質は4つあり、`ar` はその全部を備えているはず
# である（dowel#50）。ここで固定するのはその4つと、**表に無い名前の扱い**。
#
#   1. 宣言すればそれが起動される。宣言しなければ既定値
#   2. 構成の語彙（`tc.<名前>`）から引ける
#   3. 実在が確かめられる。ただし要るときだけ
#   4. 記録された入力である。差し替えたら作り直す
#   5. 目標トリプルごとに選べる
#
# 5 が組み込みで効く。ベンダが配る toolchain はコンパイラ・リンカ・書庫の
# 道具を一組で配り、混ぜることを想定していない。混成が起きても黙って
# 通ってしまうなら、宣言できることの意味が薄れる。

TRIPLE=aarch64-unknown-linux-gnu
BUILD_BAK=$PWD/host-dowel.build.bak
cp host/dowel.build "$BUILD_BAK"

# ------------------------------------------------------------ 道具立て

# tool_of <パッケージ> <アクションの種類> [dowel args...] — そのアクションを
# 起こすコマンド。「宣言が起動に届いたか」は引数の先頭にしか現れない。
tool_of() {
    local dir=$1 kind=$2; shift 2
    "$DOWEL" -C "$dir" graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r --arg k "$kind" '.actions[] | select(.kind == $k) | .command[0]' | head -1
}

# tool_is <期待> <パッケージ> <種類> <desc> [dowel args...]
tool_is() {
    local want=$1 dir=$2 kind=$3 desc=$4; shift 4
    local got; got=$(tool_of "$dir" "$kind" "$@")
    [ "$want" = "$got" ]
    local v=$?
    RC=0; _last_cmd="dowel -C $dir graph --kind=action | select(.kind==\"$kind\")"
    OUT="want: $want"$'\n'"got:  ${got:-(no such action)}"
    fact $v "$desc"
}

# declare_toolchain <パッケージ> <行...> — [toolchain] を書き換える。
declare_toolchain() {
    local dir=$1; shift
    { printf '[package]\nname    = "%s"\nversion = "0.0.0"\n' "$dir"
      if [ $# -gt 0 ]; then printf '\n[toolchain]\n'; printf '%s\n' "$@"; fi
    } >"$dir/dowel.toml"
    return 0
}

# ran <パッケージ> [dowel args...] — direct 実行器で走ったアクション数。
# 記録された入力かどうかは、走った数でしか観測できない。
ran() {
    local dir=$1; shift
    "$DOWEL" -C "$dir" build --executor=direct --log-level=debug "$@" 2>&1 |
        sed -n 's/.*ran \([0-9]*\) actions.*/\1/p' | tail -1
}

# ------------------------------------------------------------ 1. 宣言と既定

tool_is ar host ar "the archiver defaults to ar when nothing is declared"
tool_is cc host cc "the C compiler defaults to cc, as it always has"

declare_toolchain host 'ar = "llvm-ar"'
tool_is llvm-ar host ar "a declared archiver is the one that runs"

# 道具ごとに独立していること。archiver を宣言してもコンパイラは動かない。
tool_is cc host cc "declaring the archiver leaves the compiler alone"

ok "the package builds with the declared archiver" -C host build --no-compdb

# ------------------------------------------------------------ 2. 構成の語彙
#
# 宣言によって具体化を変えられなければ、複数のツールチェーンに対応する
# マニフェストは書けない。`tc.ar` は `tc.c` / `tc.cxx` と同じ扱いである。

ar_define() {
    "$DOWEL" -C vocab graph --kind=action --format=json 2>/dev/null |
        jq -r '.actions[] | select(.kind == "cc") | .command | join(" ")' |
        tr ' ' '\n' | grep -E '^-DAR_IS' | head -1
}

declare_toolchain vocab 'ar = "llvm-ar"'
got=$(ar_define)
[ "$got" = "-DAR_IS=2" ]
v=$?; RC=0; _last_cmd="graph --kind=action | grep -DAR_IS"; OUT="got: ${got:-(none)}"
fact $v "match on tc.ar follows the declaration"

declare_toolchain vocab
got=$(ar_define)
[ "$got" = "-DAR_IS=1" ]
v=$?; RC=0; _last_cmd="graph --kind=action | grep -DAR_IS"; OUT="got: ${got:-(none)}"
fact $v "and falls to the default arm when nothing is declared"

# 語彙は閉じている。表に無い道具の名前は構成キーとしても引けない。
printf '\n[bin.lone.private]\nflags = ["-DX" when tc.nosuchtool]\n' >>host/dowel.build
diag unknown-cfg-key "a tc.* key that is not a declared tool is refused" -C host check
diag_where unknown-cfg-key '.message | test("tc.nosuchtool")' \
    "the refusal names the key that was written" -C host check
cp "$BUILD_BAK" host/dowel.build

# ------------------------------------------------------------ 3. 実在の確認
#
# 固定した対象が実在するかどうかは「記録されない入力を排除する」前提である。
# 確かめなければ `/bin/sh: not found` がビルドの失敗として出るだけで、
# `[toolchain]` のどの行が原因かを示さない。

declare_toolchain host 'ar = "no-such-archiver-18"'
fails "an archiver that is not on PATH is refused" -C host check
diag missing-toolchain "the refusal carries the missing-toolchain code" -C host check
diag_where missing-toolchain '.message | test("archiver")' \
    "the refusal says it is the archiver, not the compiler" -C host check
out_lacks "not found" "the missing archiver never reaches the shell" -C host build

# 要るときだけ確かめる。書庫を作らない目標だけを求めるなら、archiver が
# 壊れていても組めなければならない。C 専用の構成に C++ コンパイラを強いない
# のと同じ理屈である。
ok "a target that produces no archive ignores a broken archiver" \
    -C host build --no-compdb lone

declare_toolchain host

# ------------------------------------------------------------ 4. 記録された入力
#
# `ar` にはこれが無かった（F-016）。記録されていなければ、書庫の中身が
# 黙って変わりうる。

rm -rf host/.dowel
"$DOWEL" -C host build --no-compdb >/dev/null 2>&1
n=$(ran host --no-compdb)
[ "${n:-1}" = 0 ]
v=$?; RC=0; _last_cmd="dowel -C host build --executor=direct"; OUT="ran ${n:-?} actions"
fact $v "a rebuild with the same archiver runs nothing"

declare_toolchain host 'ar = "llvm-ar"'
build_direct -C host --no-compdb
n=$(_ran_actions)
[ "${n:-0}" -gt 0 ]
v=$?; RC=0; _last_cmd="dowel -C host build --executor=direct"; OUT="ran ${n:-?} actions"
fact $v "changing the declared archiver rebuilds"

# 何が走ったか。翻訳まで走るなら、道具の変更が必要以上に波及している。
rebuilt "AR" "the archive is what gets rebuilt"
not_rebuilt "CC" "the objects are not recompiled for a different archiver"

declare_toolchain host

# 記録されているのは**名前**であり、その名前が指す実体ではない。同じ名前の
# 裏で別の実体に差し替えても組み直されない。これは `c` も同じであり、
# 道具ごとの差ではなく記録の粒度である（docs/10-findings.md F-016）。
SHIM=$PWD/shim
rm -rf "$SHIM"; mkdir -p "$SHIM"
ln -sf "$(command -v llvm-ar)" "$SHIM/ar"
ln -sf "$(command -v clang)" "$SHIM/cc"
rm -rf host/.dowel
"$DOWEL" -C host build --no-compdb >/dev/null 2>&1
n=$(PATH="$SHIM:$PATH" ran host --no-compdb)
[ "${n:-1}" = 0 ]
v=$?; RC=0; _last_cmd="PATH=<other ar and cc> dowel -C host build --executor=direct"
OUT="ran ${n:-?} actions"
fact $v "the record is the tool's name, so swapping what the name resolves to does not rebuild"

# ------------------------------------------------------------ 5. トリプルごと
#
# ここが `ar` を宣言できるようにした理由である。クロスの構成で書庫の作成
# だけがホストの道具に落ちると、ホストと目標で書庫の形式が違う場合に
# 壊れる。llvm-ar と GNU ar、macOS をホストに ELF へクロスする場合、
# ベンダ配布の toolchain。いずれも手元では通り、別の環境で壊れる。

tool_is aarch64-linux-gnu-ar cross ar \
    "a cross build uses the archiver declared for that triple" --target=$TRIPLE
tool_is aarch64-linux-gnu-gcc cross cc \
    "and the compiler declared for the same triple" --target=$TRIPLE

# ホスト側は別の宣言である。同じマニフェストで両方が組める。
tool_is ar cross ar "the host build still uses the host archiver"

ok "the cross build passes check" -C cross check --target=$TRIPLE
ok "the cross build produces an archive" -C cross build --no-compdb --target=$TRIPLE

# 書庫の中身が本当に目標のアーキテクチャのものであること。宣言が届いた
# ことは引数で分かるが、出来上がったものが正しいかは別である。
archive=$(find cross/.dowel/build -name 'libpart.a' | head -1)
got=""
if [ -n "$archive" ]; then
    mkdir -p unpack && (cd unpack && ar x "$PWD/../$archive" 2>/dev/null)
    obj=$(find unpack -maxdepth 1 -name '*.o' | head -1)
    [ -n "$obj" ] && got=$(readelf -h "$obj" 2>/dev/null | sed -n 's/.*Machine: *//p')
fi
[ "$got" = "AArch64" ]
v=$?; RC=0; _last_cmd="readelf -h <member of libpart.a>"; OUT="machine = ${got:-(unreadable)}"
fact $v "the objects inside the cross archive are for the target architecture"

assert "the cross binary links against that archive and runs under the emulator" \
    qemu-aarch64-static -L /usr/aarch64-linux-gnu \
    "$PWD/$(find cross/.dowel/build -type f -path "*$TRIPLE*/bin/image" | head -1)"

# ------------------------------------------------------------ 6. 綴り間違い (F-019)
#
# 表に無いキーは黙って受理され、その道具は既定値へ後退する。クロスの宣言で
# archiver のキーを打ち間違えると、aarch64 の書庫がホストの `ar` で作られる。
# #50 が防ごうとした状態が、綴り間違いで戻る。
#
# `c` が同じ経路で消えれば翻訳が動かないのですぐ分かる。archiver は既定の
# `ar` が ELF に対して総称的に動いてしまうため、**壊れるのはホストと目標で
# 書庫形式が違うときだけ**である。

known_issue F-019
fails "a misspelled toolchain key is refused" -C typo check --target=$TRIPLE

said=$(json_diags -C typo check --target=$TRIPLE)
_last_cmd="dowel -C typo check --message-format=json --target=$TRIPLE"
OUT=$said; RC=0
printf '%s' "$said" | jq -e 'select(.code == "unknown-property")
    | .suggestions | length > 0' >/dev/null 2>&1
v=$?
known_issue F-019
fact $v "the refusal suggests the tool that was meant"

got=$(tool_of typo ar --target=$TRIPLE)
[ "$got" = "aarch64-linux-gnu-ar" ]
v=$?; RC=0; _last_cmd="dowel -C typo graph --kind=action --target=$TRIPLE"
OUT="archiver = ${got:-(none)}"
known_issue F-019
fact $v "a misspelled cross archiver does not silently fall back to the host tool"

# 綴りを直せば効く。上の3件は「宣言が効かないこと」ではなく
# 「効かないことが知らされないこと」を見ている。
sed -i 's/^ar_ =/ar  =/' typo/dowel.toml
tool_is aarch64-linux-gnu-ar typo ar \
    "spelling the key correctly does select the cross archiver" --target=$TRIPLE

# ------------------------------------------------------------ 7. 後処理の道具 (F-020)
#
# 組み込みでは、リンクの後に必ず1段ある。書き込み用のイメージを作り
# （objcopy）、予算に収まったかを見る（size）。現在はどちらも表に無く、
# 生成物に対して何かを走らせる場所も無い。
#
# `[runner.<triple>]` は実行の側の抽象であり、`dowel test` が組み上がった
# 実行ファイルを起動するときに通る。生成物から別の形を作る側には対応する
# ものが無い。dowel の外で叩く限り、その道具は記録の外にある。
#
# 表に載れば `tc.<名前>` から引けるようになる。取り込みの形が何であれ
# 通る観測であるため、提案した構文に依存しない。

probe_vocabulary() {
    cp "$BUILD_BAK" host/dowel.build
    printf '\n[bin.lone.private]\nflags = ["-DX" when tc.%s]\n' "$1" >>host/dowel.build
    OUT=$(json_diags -C host check)
    RC=0
    _last_cmd="dowel -C host check --message-format=json  # tc.$1"
    ! printf '%s' "$OUT" | jq -e 'select(.code == "unknown-cfg-key")' >/dev/null 2>&1
    local v=$?
    cp "$BUILD_BAK" host/dowel.build
    return $v
}

probe_vocabulary objcopy; v=$?
known_issue F-020
fact $v "a transform tool can be declared alongside the archiver"

probe_vocabulary size; v=$?
known_issue F-020
fact $v "an inspection tool can be declared alongside the archiver"

# 変換の出力がビルドの成果物であること。提案した形の1つを書いてみる。
# 実装が別の形を採ればここは書き換わるが、**変換がグラフに乗る**という
# 期待そのものは変わらない。
cp "$BUILD_BAK" host/dowel.build
declare_toolchain host 'objcopy = "objcopy"'
cat >>host/dowel.build <<'EOF'

[bin.user.artifacts]
bin = { tool = "objcopy", args = ["-O", "binary"] }
EOF
"$DOWEL" -C host build --no-compdb >/dev/null 2>&1
img=$(find host/.dowel/build -type f -name 'user.bin' 2>/dev/null | head -1)
[ -n "$img" ]
v=$?; RC=0; _last_cmd="dowel -C host build  # with an artifacts block"
OUT="raw image: ${img:-(not produced)}"
known_issue F-020
fact $v "a bin target can produce a raw binary image"

cp "$BUILD_BAK" host/dowel.build
declare_toolchain host
