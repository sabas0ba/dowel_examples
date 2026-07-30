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

# ホスト向けの宣言だけ。別のトリプルへは組めない。
host_toml() {
    printf '[package]\nname    = "subject"\nversion = "0.1.0"\nedition = "2026"\n' \
        > "$SUBJECT/dowel.toml"
}

# トリプルごとの宣言。`[toolchain]` は host 向けであり、他のトリプルには
# 決して適用されない（#42 の修正）。
cross_toml() {
    printf '[package]\nname    = "subject"\nversion = "0.1.0"\nedition = "2026"\n\n[toolchain.%s]\nc = "%s"\n' \
        "$TRIPLE" "$CROSS_CC" > "$SUBJECT/dowel.toml"
}

# ホストのコンパイラを、別のトリプルの宣言として書いた場合。
# 宣言はできるが、出てくる成果物はホスト向けである。
host_cc_for_triple_toml() {
    printf '[package]\nname    = "subject"\nversion = "0.1.0"\nedition = "2026"\n\n[toolchain.%s]\nc = "cc"\n' \
        "$TRIPLE" > "$SUBJECT/dowel.toml"
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

# ------------------------------------------------------- 宣言の無いトリプル
#
# `[toolchain]` は host 向けの宣言であり、他のトリプルには決して適用されない。
# 宣言の無いトリプルへ `--target` を渡すと、**組む前に**拒まれる
# （docs/10-findings.md F-015）。
#
# ホストのコンパイラで組んで別のトリプルの名前で置くと、誤りは起動して
# 初めて `Invalid ELF image` として現れる。06-runner が「起動の前に拒む」
# ことを約束として見ているのと同じ形が1段あとに戻ってくる。それを避ける。

host_toml
rm -rf "$SUBJECT/.dowel"
fails "building for a triple with no toolchain declared is refused" \
    -C subject build --target=$TRIPLE
diag missing-toolchain "the refusal carries the missing-toolchain code" \
    -C subject build --target=$TRIPLE
out_lacks "Invalid ELF image" \
    "the mismatch is caught before anything is built" -C subject test --target=$TRIPLE

# 拒むのは別のトリプルだけである。ホスト向けは宣言が無くても組める。
ok "the host build still needs no declaration" -C subject build

# 宣言はできるが中身がホストのコンパイラ、という書き方は止められない。
# 止まらないこと自体は正しい（利用者がそう書いたのだから）。ここで見るのは、
# その場合に成果物がホスト向けになることを利用者が観測できることである。
host_cc_for_triple_toml
rm -rf "$SUBJECT/.dowel"
ok "declaring the host compiler for another triple is allowed" \
    -C subject build --target=$TRIPLE
got=$(machine aarch64)
case $got in *X86-64*) v=0 ;; *) v=1 ;; esac
detail "machine = $got"
fact $v "and it produces a host artifact, which readelf shows plainly"

# 逆向き（クロスのツールチェーンでホスト向けの構成を組む）は検査にしない。
# 起動できるかどうかが機械の設定で決まるためである。qemu-user-static を
# 入れた環境では binfmt_misc に登録され、別アーキテクチャの実行ファイルが
# そのまま起動する。手元では `Exec format error` になり、CI では通る。
#
# 「起動の前に拒む」ことを見たいのに、拒まなかった結果が機械によって
# 変わるなら、その検査が記録するのは dowel ではなく実行した機械である。
# F-015 の観測としては docs/10-findings.md に残す。

host_toml
