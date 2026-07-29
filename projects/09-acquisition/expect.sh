# 09-acquisition — dowel 自体の取得と版の固定（dowelup）
#
# `dowelup` は dowel を取得し、プロジェクトごとに版を固定し、透過的に
# 切り替える（ADR-0013）。`dowel` という名前で起動されると shim として働き、
# 版を選んで exec する。
#
# 本スイートにとって、これは検査対象であると同時に前提でもある。「外側から
# 検査する」という立場は検査する対象が特定できて初めて成り立つのであり、
# その特定を担うのがこの層である。固定が効かないなら、他の全プロジェクトの
# 結果が何に対するものか分からなくなる。
#
# 上流は手元の bare リポジトリに差し替える（DOWELUP_UPSTREAM）。
# ネットワークに触れず、上流の状態にも左右されずに走る。実際の取得を
# 伴うのは1回だけで、以降は「すでに入っている」経路を通る。

# --------------------------------------------------------------- 下ごしらえ

HOME_DIR=$PWD/home
UPSTREAM=$PWD/upstream.git
PROJ=$PWD/proj
export DOWELUP_HOME=$HOME_DIR
export DOWELUP_UPSTREAM=$UPSTREAM

mkdir -p "$PROJ/sub" "$HOME_DIR"

# 上流の複製。dowelup は git と cargo の起動に委譲するため、
# 相手は本物の git リポジトリである必要がある。
git clone -q --bare "$DOWEL_SRC" "$UPSTREAM" 2>/dev/null || {
    fact 1 "the local mirror of dowel can be created"
    return 0
}
TIP=$(git --git-dir="$UPSTREAM" rev-parse HEAD)
git --git-dir="$UPSTREAM" update-ref refs/heads/main "$TIP"
git --git-dir="$UPSTREAM" symbolic-ref HEAD refs/heads/main
# 同じコミットを指す別の名前を用意する。取得は1回で済み、
# 「同じ sha を別の指定子で入れる」経路を組み立てられる。
git --git-dir="$UPSTREAM" update-ref refs/heads/side "$TIP"
git --git-dir="$UPSTREAM" tag -f v0.9.0 "$TIP" >/dev/null 2>&1
ABSENT=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef

# up <args...> — dowelup を走らせる。
up() {
    _last_cmd="dowelup $*"
    OUT=$("$DOWELUP" "$@" 2>&1)
    RC=$?
    return 0
}

# shim <args...> — shim（`dowel` という名前の dowelup）を走らせる。
# 版を選ぶ経路はこちらにしかない。
shim() {
    _last_cmd="dowel $*"
    OUT=$("$PROJ/bin/dowel" "$@" 2>&1)
    RC=$?
    return 0
}

# pin_file <本文> — .dowel-version を書く。printf の書式として渡す。
pin_file() { printf "$1" "$TIP" > "$PROJ/.dowel-version"; }

# up_ok / up_fails — dowelup の終了状態を見る。
up_ok()    { local d=$1; shift; up "$@"; [ "$RC" -eq 0 ]; _verdict $? "$d"; }
up_fails() { local d=$1; shift; up "$@"; [ "$RC" -ne 0 ]; _verdict $? "$d"; }

# selects <期待するパス断片> <desc> — shim which が指す実体。
selects() {
    up -C "$2" which
    if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -qF -- "$1"; then
        _verdict 0 "$3"
    else
        _verdict 1 "$3"
    fi
}

# --------------------------------------------------------------- 1. 取得
#
# ここだけが実際に組み立てる。以降は「すでに入っている」経路を通る。

up_ok "installing a revision from the upstream succeeds" install nightly

# 2度目。判定のたびに OUT は捨てられるため、複数のことを見るときは
# 先に控える。
up install nightly
said=$OUT
printf '%s' "$said" | grep -q "^$TIP$"
fact $? "the resolved commit is written to stdout"
printf '%s' "$said" | grep -q 'already installed'
fact $? "installing an already installed revision succeeds and says so"

up list
printf '%s' "$OUT" | grep -q "$TIP"
fact $? "an installed revision appears in the list"

if [ -x "$HOME_DIR/versions/$TIP/bin/dowel" ]; then
    fact 0 "the installed revision is laid out under versions/<sha>/bin"
else
    fact 1 "the installed revision is laid out under versions/<sha>/bin"
fi

up run "$TIP" -- --version
printf '%s' "$OUT" | grep -q '^dowel '
fact $? "run starts the requested revision without selecting it"

# --------------------------------------------------------------- 2. 選択の順序
#
# 「.dowel-version → 既定」の順で選ぶ。先頭引数の `+<指定子>` が最も強い。

up_ok "the shim can be created" shim "$PROJ/bin"
if [ -L "$PROJ/bin/dowel" ]; then
    fact 0 "the shim is a link named dowel"
else
    fact 1 "the shim is a link named dowel"
fi

rm -f "$PROJ/.dowel-version" "$PROJ/sub/.dowel-version" "$HOME_DIR/default"
up_fails "with no pin and no default, nothing is selected" -C "$PROJ" which
shim --version
[ "$RC" -ne 0 ]; _verdict $? "the shim refuses to run when nothing is selected"

up_ok "setting a default succeeds" default "$TIP"
selects "$TIP" "$PROJ" "the default is used where no pin file applies"

pin_file '%s\n'
selects "$TIP" "$PROJ" "a pin file is used in the directory that holds it"
selects "$TIP" "$PROJ/sub" "a pin file is found by walking up from a subdirectory"

# 近い方が勝つ。単に「見つかった順」でないことを見る。
mkdir -p "$HOME_DIR/versions/$ABSENT/bin"
printf '%s\n' "$ABSENT" > "$PROJ/sub/.dowel-version"
up -C "$PROJ/sub" which
printf '%s' "$OUT" | grep -q "$ABSENT"
fact $? "the nearest pin file wins over one further up"
rm -f "$PROJ/sub/.dowel-version"; rm -rf "$HOME_DIR/versions/$ABSENT"

# --------------------------------------------------------------- 3. 選択はネットワークに触れない
#
# 「選択はネットワークに触れない」（ADR-0013）。触れていれば、上流が
# 落ちている日に、何も変えていないプロジェクトがビルドできなくなる。

(
    export DOWELUP_UPSTREAM=/nonexistent/no.git
    pin_file '%s\n'
    up -C "$PROJ" which
    [ "$RC" -eq 0 ]; _verdict $? "selection works with the upstream unreachable"
    shim --version
    [ "$RC" -eq 0 ]; _verdict $? "the shim runs with the upstream unreachable"
    up -C "$PROJ" pin "$TIP"
    [ "$RC" -eq 0 ]; _verdict $? "pinning an installed revision needs no network"
)

# --------------------------------------------------------------- 4. pin ファイル
#
# 書くのは解決済みの sha だけである。チャネル名やブランチ名を書くと、
# 選択のたびに解決が要る。それは「触れない」と両立しない。

up -C "$PROJ" pin "$TIP"
grep -q "^$TIP$" "$PROJ/.dowel-version"
fact $? "pin writes the resolved commit to the pin file"
grep -q '^#' "$PROJ/.dowel-version"
fact $? "pin records which specifier it resolved from"

for spec in nightly stable main branch:side 19a4a40; do
    printf '%s\n' "$spec" > "$PROJ/.dowel-version"
    up -C "$PROJ" which
    [ "$RC" -ne 0 ]; _verdict $? "a pin file holding \`$spec\` is refused"
done
printf '%s\n' nightly > "$PROJ/.dowel-version"
up -C "$PROJ" which
printf '%s' "$OUT" | grep -q 'dowelup pin'
fact $? "refusing a hand written channel name points at dowelup pin"

printf '%s\n' "$ABSENT" > "$PROJ/.dowel-version"
up -C "$PROJ" which
said=$OUT; rc=$RC
[ "$rc" -ne 0 ]; _verdict $? "a pinned revision that is not installed is refused"
printf '%s' "$said" | grep -q 'dowelup install'
fact $? "refusing an uninstalled revision points at dowelup install"

# 書き方の揺れ。pin が書く形以外も、人が置く形として通る必要がある。
pin_file '%s'          ; selects "$TIP" "$PROJ" "a pin file without a trailing newline is read"
pin_file '%s\r\n'      ; selects "$TIP" "$PROJ" "a pin file with CRLF is read"
pin_file '  %s  \n'    ; selects "$TIP" "$PROJ" "surrounding spaces in a pin file are ignored"
printf '%s\n' "${TIP^^}" > "$PROJ/.dowel-version"
selects "$TIP" "$PROJ" "an uppercase commit hash in a pin file is read"
printf '# only a comment\n' > "$PROJ/.dowel-version"
up_fails "a pin file with no commit hash is refused" -C "$PROJ" which

# BOM。Windows の編集器が黙って付ける（docs/10-findings.md F-011）。
printf '\xef\xbb\xbf%s\n' "$TIP" > "$PROJ/.dowel-version"
known_issue F-011
selects "$TIP" "$PROJ" "a pin file with a UTF-8 BOM is read"
pin_file '%s\n'

# --------------------------------------------------------------- 5. 指定子の解決

up_ok   "a branch that exists resolves"        install branch:side
up_ok   "a tag that exists resolves"           install tag:v0.9.0
up_ok   "a release number resolves to its tag" install 0.9.0
up_ok   "stable resolves to the newest tag"    install stable
up_ok   "a dated nightly resolves"             install "nightly-$(date -u +%Y-%m-%d)"

up_fails "a branch that does not exist is refused"  install branch:nosuchbranch
up_fails "a tag that does not exist is refused"     install tag:nosuchtag
up_fails "a date before the first commit is refused" install nightly-1999-01-01
up_fails "a malformed date is refused"              install nightly-2026-13-99
up_fails "a commit hash prefix that is too short is refused" install 19a4a4
up_fails "a branch specifier with no name is refused" install 'branch:'
up_fails "an unresolvable commit is refused"        install "$ABSENT"

# 使い方の誤りと、解決できなかったことは別である。前者は書き直せば直り、
# 後者は上流の状態による。終了状態で見分けられる必要がある。
up install nightly-2026-13-99; malformed=$RC
up install branch:nosuchbranch; unresolved=$RC
[ "$malformed" -ne "$unresolved" ]
fact $? "a malformed specifier and an unresolvable one exit differently"

# --------------------------------------------------------------- 6. 指定子による選択
#
# `+<指定子>` は「インストール済みの中から選ぶ」（docs/61-acquisition.md）。

shim "+$TIP" --version
[ "$RC" -eq 0 ]; _verdict $? "a full commit hash selects an installed revision"
shim "+${TIP:0:7}" --version
[ "$RC" -eq 0 ]; _verdict $? "a commit hash prefix selects an installed revision"
shim +nightly --version
[ "$RC" -eq 0 ]; _verdict $? "the specifier it was installed from selects it"

# 同じ sha を別の指定子で入れても、記録されるのは最初の1つだけである
# （docs/10-findings.md F-013）。install は成功するのに選べない。
up_ok "installing the same commit under another specifier succeeds" install branch:side
known_issue F-013
shim +branch:side --version
[ "$RC" -eq 0 ]; _verdict $? "a specifier that installed successfully can select"

shim +nosuchspec --version
said=$OUT; rc=$RC
[ "$rc" -ne 0 ]; _verdict $? "an unknown specifier is refused by the shim"
printf '%s' "$said" | grep -q 'dowelup list'
fact $? "refusing an unknown specifier points at dowelup list"

# 先頭引数の指定子が pin ファイルより強い。
mkdir -p "$HOME_DIR/versions/$ABSENT/bin"
printf 'nightly\t%s\n' "$UPSTREAM" > "$HOME_DIR/versions/$ABSENT/origin" 2>/dev/null
printf '%s\n' "$ABSENT" > "$PROJ/.dowel-version"
shim "+$TIP" --version
[ "$RC" -eq 0 ]; _verdict $? "a leading specifier overrides the pin file"
rm -rf "$HOME_DIR/versions/$ABSENT"
pin_file '%s\n'

# --------------------------------------------------------------- 7. 失敗した取得
#
# 組み立てに失敗した版が versions/ に残ると、以後その版を選んだ全ての
# 実行が壊れたものを使う。しかも一度きりの失敗が恒久的な状態になる。

W=$PWD/broken-wt
git clone -q "$UPSTREAM" "$W" 2>/dev/null
printf 'this is not rust\n' >> "$W/crates/dowel-support/src/lib.rs"
git -C "$W" -c user.email=t@t -c user.name=t commit -qam broken
git -C "$W" push -q origin HEAD:refs/heads/broken 2>/dev/null
BROKEN=$(git -C "$W" rev-parse HEAD)

up_fails "installing a revision that does not build fails" install branch:broken
if [ -e "$HOME_DIR/versions/$BROKEN" ]; then
    fact 1 "a failed install leaves nothing under versions/"
else
    fact 0 "a failed install leaves nothing under versions/"
fi
up list
! printf '%s' "$OUT" | grep -q "$BROKEN"
fact $? "a failed install does not appear in the list"
if [ -d "$HOME_DIR/tmp/$BROKEN" ]; then
    fact 0 "a failed install keeps its checkout for inspection"
else
    fact 1 "a failed install keeps its checkout for inspection"
fi
printf '%s\n' "$BROKEN" > "$PROJ/.dowel-version"
up_fails "a revision whose install failed is not selectable" -C "$PROJ" which
pin_file '%s\n'

# --------------------------------------------------------------- 8. 取り除く

# 取り除く側にも F-013 が出る。入れるのに使った指定子で取り除けない。
known_issue F-013
up_ok "uninstalling by the specifier it was installed from succeeds" uninstall branch:side

up_ok "uninstalling an installed revision succeeds" uninstall "$TIP"
up list
! printf '%s' "$OUT" | grep -q "$TIP"
fact $? "an uninstalled revision leaves the list"
if [ -e "$HOME_DIR/versions/$TIP" ]; then
    fact 1 "uninstalling removes the directory under versions/"
else
    fact 0 "uninstalling removes the directory under versions/"
fi
up_fails "selecting an uninstalled revision is refused" -C "$PROJ" which

rm -rf "$W"
