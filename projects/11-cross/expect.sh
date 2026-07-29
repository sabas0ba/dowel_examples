# 11-cross — 本物のクロスコンパイル
#
# 06-runner は `[runner.<triple>]` の機構を見た。ただし成果物はホスト向けで
# あり、ランナーは記録を残すシェルスクリプトだった。qemu も実機も要らない
# 代わりに、**翻訳先が本当に変わったか**は見ていない。
#
# ここでは本物のクロスコンパイラ（`aarch64-linux-gnu-gcc`）で組み、
# 本物の qemu-user で走らせる。実機は要らないが、翻訳と実行は本物である。
#
# 答はマニフェストでも構成識別子でもなく成果物が持っている。C の側で
# `__aarch64__` とポインタ幅を見て、成果物自身に名乗らせる。

SUBJECT=$PWD/subject
TRIPLE=aarch64-unknown-linux-gnu
CROSS_CC=aarch64-linux-gnu-gcc

host_toml() {
    printf '[package]\nname    = "subject"\nversion = "0.1.0"\nedition = "2026"\n' \
        > "$SUBJECT/dowel.toml"
}
cross_toml() {
    printf '[package]\nname    = "subject"\nversion = "0.1.0"\nedition = "2026"\n\n[toolchain]\nc = "%s"\n' \
        "$CROSS_CC" > "$SUBJECT/dowel.toml"
}

# machine <ビルドディレクトリの接頭辞> — 成果物の ELF machine。
machine() {
    local p
    p=$(find "$SUBJECT/.dowel/build/$1"*/bin/subject 2>/dev/null | head -1)
    [ -n "$p" ] || { printf '(no artifact)'; return 0; }
    readelf -h "$p" 2>/dev/null | sed -n 's/ *Machine: *//p'
}

# says <ビルドディレクトリの接頭辞> — 成果物を起動して名乗らせる。
# ホスト向けのものだけに使う（クロスの成果物は直接起動できない）。
says() {
    local p
    p=$(find "$SUBJECT/.dowel/build/$1"*/bin/subject 2>/dev/null | head -1)
    [ -n "$p" ] || { printf '(no artifact)'; return 0; }
    "$p"
}

# ------------------------------------------------------- ホスト向け

host_toml
rm -rf "$SUBJECT/.dowel"
ok "the host build passes" -C subject build
detail() { RC=0; _last_cmd="readelf -h <artifact>"; OUT=$1; }
got=$(machine x86_64); detail "machine = $got"
case $got in *X86-64*) fact 0 "the host build produces a host artifact" ;;
    *) fact 1 "the host build produces a host artifact" ;; esac
prints "x86_64 64" "the host artifact names its own architecture" "$SUBJECT/.dowel/build/x86_64-unknown-linux-gnu-debug/bin/subject"
ok "the host tests pass" -C subject test

# ------------------------------------------------------- 宣言したクロス
#
# 機構は揃っている。`[toolchain] c` にクロスコンパイラを書き、
# `[runner.<triple>]` に qemu を書けば、組んで走らせるところまで通る。

cross_toml
ok "the cross build passes" -C subject build --target=$TRIPLE
got=$(machine aarch64); detail "machine = $got"
case $got in *AArch64*) fact 0 "the cross build produces an artifact for the target" ;;
    *) fact 1 "the cross build produces an artifact for the target" ;; esac

# 名前だけならプリプロセッサで偽装できる。実体に効くものも見る。
ok "the cross tests run under the emulator and pass" -C subject test --target=$TRIPLE

# 構成はトリプルごとに分かれ、双方が残る。混ざると別の機械向けの成果物を掴む。
if [ -d "$SUBJECT/.dowel/build/$TRIPLE-debug" ] &&
   [ -d "$SUBJECT/.dowel/build/x86_64-unknown-linux-gnu-debug" ]; then
    fact 0 "the host and cross build directories both survive"
else
    detail "$(ls "$SUBJECT/.dowel/build")"
    fact 1 "the host and cross build directories both survive"
fi

# 片方を組み直しても、もう片方は組み直さない。
ran_for() {
    OUT=$("$DOWEL" -C subject build --executor=direct --log-level=debug "$@" 2>&1)
    printf '%s' "$OUT" | sed -n 's/.*ran \([0-9]*\) actions.*/\1/p' | tail -1
}
rm -rf "$SUBJECT/.dowel"
ran_for --target=$TRIPLE >/dev/null
n=$(ran_for --target=$TRIPLE); [ "$n" = 0 ]; v=$?; detail "ran $n actions"
fact $v "a second cross build runs nothing"
m=$(ran_for); [ "${m:-0}" -gt 0 ]; v=$?; detail "ran $m actions"
fact $v "the host build is not confused by the cross build"
n=$(ran_for --target=$TRIPLE); [ "$n" = 0 ]; v=$?; detail "ran $n actions"
fact $v "and the cross build is still up to date afterwards"

# ------------------------------------------------------- 宣言とトリプルの食い違い
#
# `--target` は構成識別子を変えるが、ツールチェーンは選ばない
# （docs/10-findings.md F-015）。`[toolchain]` はトリプルごとに分かれていない。

host_toml
rm -rf "$SUBJECT/.dowel"
ok "building for another triple with the host toolchain still reports success" \
    -C subject build --target=$TRIPLE
got=$(machine aarch64)
case $got in *AArch64*) v=0 ;; *) v=1 ;; esac
detail "machine = $got"
known_issue F-015
fact $v "an artifact filed under a triple is built for that triple"

# 起動して初めて分かる、という形になっている。06-runner が「起動の前に拒む」
# ことを約束として見ているのと同じ誤りが、1段あとに戻ってきている。
known_issue F-015
out_lacks "Invalid ELF image" \
    "the mismatch is caught before the artifact is started" -C subject test --target=$TRIPLE

# 逆向き。クロスのツールチェーンでホスト向けの構成を組むと、
# ランナーを通らずに直接起動され、Exec format error になる。
cross_toml
rm -rf "$SUBJECT/.dowel"
known_issue F-015
out_lacks "Exec format error" \
    "an artifact that cannot run on the host is refused before it is started" -C subject test

host_toml
