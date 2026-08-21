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
# マニフェストの側は些末部として読み飛ばすようになったが、pin ファイルを
# 読む経路には届いていない。しかも拒否が促す `dowelup pin <sha>` の引数に
# BOM が入るため、貼り付けても同じ理由でまた拒まれる。
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

# 同じ sha を別の指定子で入れた場合。かつては最初の1つしか記録されず、
# install は成功するのに選べなかった（docs/10-findings.md F-013）。
up_ok "installing the same commit under another specifier succeeds" install branch:side
shim +branch:side --version
[ "$RC" -eq 0 ]; _verdict $? "a specifier that installed successfully can select"
shim +nightly --version
[ "$RC" -eq 0 ]; _verdict $? "the first specifier still selects after a second one is added"
up list
printf '%s' "$OUT" | grep -q 'branch:side'
fact $? "the list shows every specifier the revision was installed from"

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

# 取り除く側でも指定子で照合する（F-013）。入れるのに使った名前で取り除けない
# なら、利用者は sha を調べ直すことになる。
up_ok "uninstalling by the specifier it was installed from succeeds" uninstall branch:side

up list
! printf '%s' "$OUT" | grep -q "$TIP"
fact $? "an uninstalled revision leaves the list"
if [ -e "$HOME_DIR/versions/$TIP" ]; then
    fact 1 "uninstalling removes the directory under versions/"
else
    fact 0 "uninstalling removes the directory under versions/"
fi
up_fails "uninstalling the same revision twice is refused" uninstall "$TIP"
up_fails "selecting an uninstalled revision is refused" -C "$PROJ" which

rm -rf "$W"

# --------------------------------------------------------------- 9. release 資産からの取得
#
# release 指定子（`stable` / `X.Y.Z` / `tag:`）は、上流の release 資産に
# 置かれた**公開バイナリ**を取り、隣の `.sha256` と突き合わせる（ADR-0036）。
# それ以外（`nightly` / `branch:` / 裸の sha）は取るべき資産が無く、
# 従来どおり cargo で組む。`--from-source` はどの場合も組む側を選ぶ。
#
# 狙いは「Rust の道具立てが無い機械にも dowel が入る」ことである。
# C/C++ の利用者に、最初のビルドの前に cargo を要求しないための決定であり、
# 検査もそこを直接見る。cargo を**呼ばなかったこと**を、出力の文言では
# なく痕跡の不在で見る。
#
# 資産の置き場は上流の URL から導かれる。上流を手元の bare リポジトリに
# 差し替えてあるため、その隣に同じ形の木を置けば、ネットワークに触れずに
# 公開バイナリの経路をそのまま通せる。

ASSET_BASE=${UPSTREAM%.git}/releases/download/v0.9.0
TRIPLE=$(uname -m)-unknown-linux-gnu
ASSET=dowel-v0.9.0-$TRIPLE.tar.gz
mkdir -p "$ASSET_BASE"

# 資産を作る。中身は検査対象の dowel そのもの。入ったものが動くところまで
# 見たいので、動かない詰め物では代えられない。
mkdir -p "$PWD/stage"
cp "$DOWEL" "$PWD/stage/dowel"
tar czf "$ASSET_BASE/$ASSET" -C "$PWD/stage" dowel
publish_sum() { ( cd "$ASSET_BASE" && sha256sum "$ASSET" | awk '{print $1}' > "$ASSET.sha256" ); }
publish_sum

# cargo が無い機械。PATH から消すのではなく、呼ばれたら痕跡を残して落ちる
# ものを前に置く。PATH を削ると git などの巻き添えが起きるうえ、
# 「呼ばれなかった」ことを直接は見られない。
FAKE=$PWD/fakebin
WITNESS=$PWD/cargo-was-called
mkdir -p "$FAKE"
cat > "$FAKE/cargo" <<'EOF'
#!/bin/sh
: > "$CARGO_WITNESS"
echo "no Rust toolchain on this machine" >&2
exit 127
EOF
chmod +x "$FAKE/cargo"

# up_nc <args...> — cargo の無い機械で dowelup を走らせる。毎回まっさらな
# DOWELUP_HOME を使う。「すでに入っている」経路に落ちると、取得の側を
# 見たことにならない。
up_nc() {
    rm -rf "$PWD/nc-home" "$WITNESS"
    _last_cmd="dowelup $*"
    OUT=$(env PATH="$FAKE:$PATH" CARGO_WITNESS="$WITNESS" \
              DOWELUP_HOME="$PWD/nc-home" DOWELUP_UPSTREAM="$UPSTREAM" \
              "$DOWELUP" "$@" 2>&1)
    RC=$?
    return 0
}
built_from_source() { [ -e "$WITNESS" ]; }

# --- 資産がある場合

up_nc install 0.9.0
said=$OUT; rc=$RC
[ "$rc" -eq 0 ]; _verdict $? "installing a release succeeds"
! built_from_source
fact $? "installing a release needs no Rust toolchain"
printf '%s' "$said" | grep -q 'from a release asset'
fact $? "install says the binary came from a release asset"
printf '%s' "$said" | grep -q 'sha256'
fact $? "install says the asset was verified by its checksum"
printf '%s' "$said" | grep -qF "$ASSET"
fact $? "install names the asset it fetched"

# 入ったものが動く。取得の経路が違っても、置き場と起動の仕方は同じである。
rm -rf "$PWD/nc-home" "$WITNESS"
env PATH="$FAKE:$PATH" CARGO_WITNESS="$WITNESS" DOWELUP_HOME="$PWD/nc-home" \
    DOWELUP_UPSTREAM="$UPSTREAM" "$DOWELUP" install 0.9.0 >/dev/null 2>&1
_last_cmd="versions/$TIP/bin/dowel --version"
OUT=$("$PWD/nc-home/versions/$TIP/bin/dowel" --version 2>&1); RC=$?
printf '%s' "$OUT" | grep -q '^dowel '
fact $? "a binary taken from a release asset runs"
if [ -x "$PWD/nc-home/versions/$TIP/bin/dowel" ]; then
    fact 0 "a binary taken from a release asset is laid out under versions/<sha>/bin"
else
    fact 1 "a binary taken from a release asset is laid out under versions/<sha>/bin"
fi

# release を名指す指定子はどれも同じ経路を通る。
for spec in stable tag:v0.9.0; do
    up_nc install "$spec"
    printf '%s' "$OUT" | grep -q 'from a release asset'
    fact $? "\`$spec\` takes the release asset too"
done

# それ以外は資産を探しにも行かない。探しに行けば、上流が落ちている日に
# nightly の取得まで遅くなる。
up_nc install nightly
said=$OUT
! printf '%s' "$said" | grep -q 'fetching'
fact $? "a specifier that names no release does not look for an asset"
printf '%s' "$said" | grep -q 'does not name a release'
fact $? "install says why it is building instead of fetching"
built_from_source
fact $? "a specifier that names no release goes to the source build"

# --from-source は資産があっても組む側を選ぶ。ADR-0036 が「由来を示せるのは
# 組んだ側だけ」と書いており、それを要求する手段が要る。
up_nc install 0.9.0 --from-source
said=$OUT
! printf '%s' "$said" | grep -q 'fetching'
fact $? "--from-source does not fetch the asset"
built_from_source
fact $? "--from-source builds a release from source"

# --- 検証

# 突き合わせが本当に働いていること。働いていなければ、以下の全ての
# 「検証された」という文言が何も意味しない。
printf '%s\n' 0000000000000000000000000000000000000000000000000000000000000000 \
    > "$ASSET_BASE/$ASSET.sha256"
up_nc install 0.9.0
said=$OUT
printf '%s' "$said" | grep -q 'does not match its checksum'
fact $? "an asset that does not match its checksum is refused"
printf '%s' "$said" | grep -q 'expected' && printf '%s' "$said" | grep -q 'actual'
fact $? "the checksum mismatch shows both the expected and the actual digest"
built_from_source
fact $? "a refused asset falls back to the source build"
publish_sum

# 隣に `.sha256` が無い資産は取らない。検証できないものを取るなら、
# 検証は選択肢であって規則ではなくなる。
mv "$ASSET_BASE/$ASSET.sha256" "$PWD/sum.keep"
up_nc install 0.9.0
said=$OUT
printf '%s' "$said" | grep -q 'no checksum'
fact $? "an asset with no checksum beside it is refused"
built_from_source
fact $? "an asset with no checksum falls back to the source build"
mv "$PWD/sum.keep" "$ASSET_BASE/$ASSET.sha256"

# `.sha256` の書き方。`sha256sum foo.tar.gz > foo.tar.gz.sha256` が最も
# 自然な作り方であり、それが通らないと公開する側が黙って踏む。
( cd "$ASSET_BASE" && sha256sum "$ASSET" > "$ASSET.sha256" )
up_nc install 0.9.0
printf '%s' "$OUT" | grep -q 'from a release asset'
fact $? "a checksum file in sha256sum's own format is accepted"
( cd "$ASSET_BASE" && sha256sum "$ASSET" | awk '{print toupper($1)}' > "$ASSET.sha256" )
up_nc install 0.9.0
printf '%s' "$OUT" | grep -q 'from a release asset'
fact $? "an uppercase checksum is accepted"
publish_sum

# 資産の中身が違う場合。checksum は「配られたものが listed のものと同じ」
# しか言わず、それが dowel であるとは言わない。
mkdir -p "$PWD/stage-empty" && : > "$PWD/stage-empty/README"
tar czf "$ASSET_BASE/$ASSET" -C "$PWD/stage-empty" README
publish_sum
up_nc install 0.9.0
said=$OUT
printf '%s' "$said" | grep -q 'no `dowel` binary\|no dowel binary'
fact $? "an asset that holds no dowel binary is refused"
built_from_source
fact $? "an asset that holds no dowel binary falls back to the source build"
tar czf "$ASSET_BASE/$ASSET" -C "$PWD/stage" dowel
publish_sum

# --- 資産が無い場合
#
# 「資産が無いのは失敗ではなく退避である」（ADR-0036）。まだ資産の無い
# 三つ組でも動き続けるための決定。

mv "$ASSET_BASE/$ASSET" "$PWD/asset.keep"
up_nc install 0.9.0
said=$OUT
printf '%s' "$said" | grep -q 'building from source'
fact $? "a release with no asset falls back to the source build"
built_from_source
fact $? "the fallback really reaches cargo"

# 退避した理由が読めること。取得の失敗は proxy・TLS・404・DNS と原因が
# 幅広く、しかも利用者の機械の側にある（F-060）。
printf '%s' "$said" | grep -q 'failed: [^;)]'
fact $? "a failed fetch says why it failed"

# 試した道具を1つに絞らない。最後の1つだけを残すと、実際に失敗した側の
# 理由が捨てられ、入っていない道具の名前だけが出る。
printf '%s' "$said" | grep -q 'curl failed' && printf '%s' "$said" | grep -q 'wget failed'
fact $? "a failed fetch says what each tool it tried reported"

# 資産の経路を諦めた理由が、続く失敗まで持ち越されること。持ち越さないと
# 利用者が最後に読む言葉は「cargo が無い」になり、実際の問題を指さない。
printf '%s' "$said" | grep -q 'the release asset was not usable'
fact $? "the reason the asset path was abandoned survives into the failure"
mv "$PWD/asset.keep" "$ASSET_BASE/$ASSET"

# 検証に落ちた場合も同じ。こちらは「壊れた配り物を掴んだ」という、
# 取得できなかった場合とは別の事実である。
printf '%s\n' 0000000000000000000000000000000000000000000000000000000000000000 \
    > "$ASSET_BASE/$ASSET.sha256"
up_nc install 0.9.0
said=$OUT
printf '%s' "$said" | grep -q 'the release asset was not usable'
fact $? "a checksum mismatch also survives into the failure"
printf '%s' "$said" | grep -q 'does not match its checksum'
fact $? "the surviving reason is the mismatch itself, not a generic one"
publish_sum

# --- 何で入ったかは後から分かるか
#
# ADR-0036 は2つの経路の違いを「何を信用するか」に置いている。組んだ側は
# コミットに紐づき、取った側は公開者に紐づく。どちらであるかが残らなければ、
# 目の前のバイナリについて何を言ってよいかが後から決まらない（F-061）。

up_nc install 0.9.0
grep -q '^from=asset$' "$PWD/nc-home/versions/$TIP/origin"
fact $? "the record of a version taken from an asset says so"
grep -q "^asset_sha256=$(cat "$ASSET_BASE/$ASSET.sha256")$" "$PWD/nc-home/versions/$TIP/origin"
fact $? "the record keeps the digest that was verified"

_last_cmd="dowelup list"
OUT=$(env DOWELUP_HOME="$PWD/nc-home" DOWELUP_UPSTREAM="$UPSTREAM" "$DOWELUP" list 2>&1); RC=$?
printf '%s' "$OUT" | grep -q 'asset'
fact $? "the listing marks a version that arrived as a published binary"

env DOWELUP_HOME="$PWD/nc-home" DOWELUP_UPSTREAM="$UPSTREAM" "$DOWELUP" default 0.9.0 >/dev/null 2>&1
_last_cmd="dowelup which"
OUT=$(env DOWELUP_HOME="$PWD/nc-home" DOWELUP_UPSTREAM="$UPSTREAM" "$DOWELUP" which 2>&1); RC=$?
said=$OUT
printf '%s' "$said" | grep -q 'release asset'
fact $? "which says which way the binary that would run here arrived"
printf '%s' "$said" | grep -qF "$(cat "$ASSET_BASE/$ASSET.sha256")"
fact $? "which states the digest for a version taken from an asset"

# 組んだ側。対照が無ければ、上の文言が経路を見ているのか、
# 常に出ているだけなのかを区別できない。
rm -rf "$PWD/nc-home"
env DOWELUP_HOME="$PWD/nc-home" DOWELUP_UPSTREAM="$UPSTREAM" \
    "$DOWELUP" install 0.9.0 --from-source >/dev/null 2>&1
grep -q '^from=source$' "$PWD/nc-home/versions/$TIP/origin"
fact $? "the record of a version built from source says so"
! grep -q '^asset_sha256=' "$PWD/nc-home/versions/$TIP/origin"
fact $? "a version built from source carries no asset digest"
_last_cmd="dowelup list"
OUT=$(env DOWELUP_HOME="$PWD/nc-home" DOWELUP_UPSTREAM="$UPSTREAM" "$DOWELUP" list 2>&1); RC=$?
printf '%s' "$OUT" | grep -q 'source'
fact $? "the listing marks a version that was built from source"

# ディスクの1つの実体は1つの来かたで届いている。別の指定子で引き当てただけの
# ときに経路が積まれると、記録は「どちらでもある」という無意味な形になる。
env DOWELUP_HOME="$PWD/nc-home" DOWELUP_UPSTREAM="$UPSTREAM" \
    "$DOWELUP" install tag:v0.9.0 >/dev/null 2>&1
_last_cmd="cat versions/$TIP/origin"
OUT=$(cat "$PWD/nc-home/versions/$TIP/origin"); RC=0
[ "$(grep -c '^from=' "$PWD/nc-home/versions/$TIP/origin")" -eq 1 ]
fact $? "resolving an installed version again records one arrival, not two"
grep -q '^from=source$' "$PWD/nc-home/versions/$TIP/origin"
fact $? "resolving an installed version again keeps the way it first arrived"
grep -q '^spec=tag:v0.9.0$' "$PWD/nc-home/versions/$TIP/origin"
fact $? "resolving an installed version again still records the new specifier"

rm -rf "$PWD/nc-home" "$PWD/stage" "$PWD/stage-empty" "$WITNESS"

# --------------------------------------------------------------- 10. 版を名指して取り、中身を確かめる
#
# ここまでは「資産の経路を通るか」を見てきた。残っているのは利用者が実際に
# 問うことである——**名指した版が入ったか。入ったものは期待どおりか。**
#
# 固定の側（4節）は「同じ sha が選ばれる」ことしか言わない。sha が同じでも、
# 資産の中身が違えば別のものが動く。ADR-0036 が正直に書いているとおり、
# dowel は公開バイナリがその sha から組まれたことを確かめられない。
# だから「入ったものが期待どおりか」は、**入ったものに名乗らせる**しかない。

# 上流にもう1つ release を作る。別のコミットに別の版を置くと、
# 「名指した方が来たか」を答の側で見分けられる。
OLD=$(git --git-dir="$UPSTREAM" rev-parse 'HEAD~1' 2>/dev/null || printf '%s' "$TIP")
git --git-dir="$UPSTREAM" tag -f v0.8.0 "$OLD" >/dev/null 2>&1
OLD_BASE=${UPSTREAM%.git}/releases/download/v0.8.0
OLD_ASSET=dowel-v0.8.0-$TRIPLE.tar.gz
mkdir -p "$OLD_BASE"

# 古い方の資産には、自分が何者かを名乗るだけのものを詰める。dowel は
# 中身が本物の dowel かどうかを確かめない——その限界を使って、
# 「どちらが来たか」を答の側から読む。
mkdir -p "$PWD/stage-old"
cat > "$PWD/stage-old/dowel" <<'EOF'
#!/bin/sh
echo "dowel 0.8.0 (the payload published under v0.8.0)"
EOF
chmod +x "$PWD/stage-old/dowel"
tar czf "$OLD_BASE/$OLD_ASSET" -C "$PWD/stage-old" dowel
( cd "$OLD_BASE" && sha256sum "$OLD_ASSET" | awk '{print $1}' > "$OLD_ASSET.sha256" )

# 新しい方の資産は、検査対象の dowel そのものである（1節で作ってある）。
publish_sum

VER=$("$DOWEL" --version 2>&1)

# --- 名指した版が来る

HOME2=$PWD/two-home
rm -rf "$HOME2"
env DOWELUP_HOME="$HOME2" DOWELUP_UPSTREAM="$UPSTREAM" "$DOWELUP" install 0.9.0 >/dev/null 2>&1
env DOWELUP_HOME="$HOME2" DOWELUP_UPSTREAM="$UPSTREAM" "$DOWELUP" install 0.8.0 >/dev/null 2>&1

_last_cmd="dowelup list   # 2つの版を入れた"
OUT=$(env DOWELUP_HOME="$HOME2" DOWELUP_UPSTREAM="$UPSTREAM" "$DOWELUP" list 2>&1); RC=0
said=$OUT
printf '%s' "$said" | grep -q '0\.9\.0' && printf '%s' "$said" | grep -q '0\.8\.0'
fact $? "two named releases can be installed side by side"

n=$(printf '%s' "$said" | grep -c '\[asset\]')
_last_cmd="dowelup list | [asset]"; OUT="$n of them arrived as a published binary"; RC=0
[ "$n" -eq 2 ]
fact $? "and both arrived as published binaries"

# ここが要点である。名指した版の**中身**が来たかどうかは、入ったものに
# 名乗らせるほかない。
prints "$VER" "asking for the newer release gives the payload published under it" \
       env DOWELUP_HOME="$HOME2" DOWELUP_UPSTREAM="$UPSTREAM" \
           "$DOWELUP" run 0.9.0 -- --version

prints "dowel 0.8.0 (the payload published under v0.8.0)" \
       "and asking for the older one gives the payload published under that" \
       env DOWELUP_HOME="$HOME2" DOWELUP_UPSTREAM="$UPSTREAM" \
           "$DOWELUP" run 0.8.0 -- --version

# 配ったバイト列がそのまま届いていること。名乗りが合っていても、
# 途中で何かが差し替わっていないとは言えない。
NEW_SHA=$(git --git-dir="$UPSTREAM" rev-parse HEAD)
if cmp -s "$DOWEL" "$HOME2/versions/$NEW_SHA/bin/dowel"; then
    fact 0 "what was installed is byte for byte what the asset held"
else
    fact 1 "what was installed is byte for byte what the asset held"
fi

# 記録された digest が、公開した `.sha256` と一致すること。利用者が後から
# 突き合わせられる唯一の値である。
grep -q "^asset_sha256=$(cat "$ASSET_BASE/$ASSET.sha256")$" \
     "$HOME2/versions/$NEW_SHA/origin"
fact $? "and the digest it recorded is the one published beside the asset"

# --- 入ったものが実際に働く

# 名乗るだけでは足りない。取ってきた dowel で小さな木を組んでみる。
PROBE=$PWD/probe
rm -rf "$PROBE"; mkdir -p "$PROBE/src"
printf '[package]\nname = "probe"\nversion = "0.1.0"\nedition = "2026"\n' > "$PROBE/dowel.toml"
printf '[bin.probe]\nsources = [file("src/main.c")]\n' > "$PROBE/dowel.build"
printf '#include <stdio.h>\nint main(void){ printf("probe ok\\n"); return 0; }\n' > "$PROBE/src/main.c"

_last_cmd="the installed dowel builds a package"
OUT=$("$HOME2/versions/$NEW_SHA/bin/dowel" -C "$PROBE" build --no-compdb 2>&1); RC=$?
[ "$RC" -eq 0 ]
fact $? "the dowel that was fetched can build a package"

prints "probe ok" "and what it built runs" \
       "$(find "$PROBE/.dowel/build" -type f -name probe | head -1)"

# --- 固定した版が、その版として動く

# 固定は sha を書く。shim がそれを選び、選ばれたものが名乗る。
# 「固定が効いている」と「固定した中身が動いている」は別の主張である。
# 選択は「起動した場所から上へ辿る」ので、その場所で起こす。
pinned_says() {
    printf '%s\n' "$1" > "$PROBE/.dowel-version"
    ( cd "$PROBE" && env DOWELUP_HOME="$HOME2" DOWELUP_UPSTREAM="$UPSTREAM" \
        "$PROJ/bin/dowel" --version 2>&1 )
}

_last_cmd="dowel --version   # .dowel-version が 0.8.0 の sha"
OUT=$(pinned_says "$OLD"); RC=0
printf '%s' "$OUT" | grep -q '0\.8\.0'
fact $? "a pin file selects the payload that came with the version it names"

_last_cmd="dowel --version   # .dowel-version を新しい方へ"
OUT=$(pinned_says "$NEW_SHA"); RC=0
[ "$OUT" = "$VER" ]
fact $? "and changing the pin changes which payload runs"

# --- 確かめられないこと
#
# 上の全ては「公開された中身が届いたか」であって、「その中身が本当にその
# コミットから組まれたか」ではない。ADR-0036 はそれを確かめないと明言して
# いる。ここではその限界そのものを固定する——限界を検査に書いておかないと、
# 上の検査が言っている以上のことを言っていると読まれる。
if cmp -s "$PWD/stage-old/dowel" "$HOME2/versions/$OLD/bin/dowel"; then
    fact 0 "a payload that is not dowel at all installs, nothing checking what it is"
else
    fact 1 "a payload that is not dowel at all installs, nothing checking what it is"
fi

# 由来を要求する手立ては在る。組んだ側だけが「このコミットから出た」ことを
# 示せる（ADR-0036）。
up_nc install 0.9.0 --from-source
built_from_source
fact $? "and --from-source is the way to demand a binary whose origin is shown"

rm -rf "$HOME2" "$PROBE" "$PWD/stage-old" "$PWD/nc-home"
