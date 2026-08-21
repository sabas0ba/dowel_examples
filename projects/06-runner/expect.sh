# 06-runner — 実行ラッパ
#
# ホストと異なるトリプル向けに組んだ成果物は、そのままでは起動できない。
# `[runner.<triple>]` は起動の仕方を宣言する場所である。
#
# 実体として想定されるのは qemu-user や実機への ssh だが、機構そのものは
# 「成果物のパスを末尾に付けて起動する」だけであり、そこに何を置くかは
# 利用者が決める。ここでは記録を残すシェルスクリプトを置いて、
# 何がどう渡ったかを外から確かめる。qemu も実機も要らない。

TRIPLE=aarch64-unknown-linux-gnu

# --------------------------------------------------- 宣言が無いとき

cd plain || exit 1

ok "the host triple needs no runner" test

# 起動してから Exec format error になるのでは、構成の誤りがテストの失敗として
# 報告される。起動の前に拒むのが約束である（docs/91-implementation-status.md）。
fails    "running for another triple without a runner is refused" test --target=$TRIPLE
diag     missing-runner "the refusal carries the missing-runner code" test --target=$TRIPLE
out_lacks "Exec format error" "the refusal happens before the artifact is started" \
    test --target=$TRIPLE

# 拒むのは起動だけである。組むことはできる。
ok "building for another triple still works" build --target=$TRIPLE

# --------------------------------------------------- 起動だけのランナー

cd ../crossed || exit 1

ok "a declared runner lets the tests run for another triple" test --target=$TRIPLE

# 渡る引数の形。宣言した args がそのまま並び、末尾に成果物が付く。
argv=$(cat runner-argv.txt 2>/dev/null)
case $argv in
    *"argv=--emulate "*"/bin/status_test") fact 0 "the runner receives its declared args then the artifact" ;;
    *) fact 1 "the runner receives its declared args then the artifact (got: $argv)" ;;
esac

# パスを相対で書けること。作業ディレクトリはパッケージルートである。
case $argv in
    "cwd=$PWD"*) fact 0 "the runner starts in the package root" ;;
    *)           fact 1 "the runner starts in the package root (got: ${argv%%$'\n'*})" ;;
esac

# 構成はトリプルごとに分かれる。混ざると、別の機械向けの成果物を起動する。
if [ -d ".dowel/build/$TRIPLE-debug" ]; then
    fact 0 "the build directory is per target triple"
else
    fact 1 "the build directory is per target triple ($(build_dir_ids | tr '\n' ' '))"
fi

# 合否はラッパの終了状態がそのまま返る。握り潰されると、落ちたテストが
# 通ったことになる。
sed -i 's|return 0;|return 3;|' tests/status_test.c
fails "a failing test still fails when it runs through a runner" test --target=$TRIPLE
out_has "exited with status 3" "the exit status passes through the runner unchanged" \
    test --target=$TRIPLE
sed -i 's|return 3;|return 0;|' tests/status_test.c

# --------------------------------------------------- 転送を伴うランナー

cd ../transferred || exit 1

ok "a runner that transfers the artifact works" test --target=$TRIPLE

# ADR-0008: パスはマニフェストに書かず、実装が末尾に付け足す。
#   transfer: <args...> <ローカルパス> <host>:<remote_dir>/<名前>
#   command : <args...> <remote_dir>/<名前>
tr_argv=$(cat transfer-argv.txt 2>/dev/null)
case $tr_argv in
    *"/bin/remote_test board.local:remote/remote_test")
        fact 0 "transfer gets the local path and the destination appended" ;;
    *)  fact 1 "transfer gets the local path and the destination appended (got: $tr_argv)" ;;
esac

case $tr_argv in
    *"board.local:"*) fact 0 "host prefixes the destination as ADR-0008 specifies" ;;
    *)                fact 1 "host prefixes the destination as ADR-0008 specifies (got: $tr_argv)" ;;
esac

lc_argv=$(cat launch-argv.txt 2>/dev/null)
case $lc_argv in
    "argv=remote/remote_test") fact 0 "the launch command gets the remote path, not the local one" ;;
    *) fact 1 "the launch command gets the remote path, not the local one (got: $lc_argv)" ;;
esac

# 転送が実際に行われたこと。行われなければ、対象機に古い成果物が残る。
if [ -f remote/remote_test ]; then
    fact 0 "the artifact really arrives at the destination"
else
    fact 1 "the artifact really arrives at the destination"
fi

# マニフェストにプレースホルダは現れない。文字列補間を導入しないという
# 決定（ADR-0008）が守られていることを、記述の側からも見る。
if ! grep -qE '\{[a-z_]+\}' dowel.build; then
    fact 0 "the manifest carries no placeholder for the transferred path"
else
    fact 1 "the manifest carries no placeholder for the transferred path"
fi

# --------------------------------------------------- 二度送らない（ADR-0046）
#
# `transfer` は起動のたびに写していた。変わっていない木の2度目の `test` でも、
# 20 の case を持つ目標の case ごとにも、`--failed` の再実行でも。机の上の板へ
# の ssh や直列の線では、その写しがテストより長いことが珍しくない。dowel は
# 変わっていないものを組み直さないよう気を配り、その組み直していない結果を
# 毎回送り直していた。
#
# 難しいのは、宛先が dowel の見えない機械であることである。手元なら出力
# ファイルを見れば済むが、向こう側を見るには往復が要る——避けたいものが
# それである。決定は「送ったものと宛先を記録し、両方変わらなければ飛ばす」。
#
# 数えるのは対象機の側に立ってである。dowel の言い分ではなく、
# **実際に何回届いたか**を見る。

count() { grep -c . transfer-count.txt 2>/dev/null || printf 0; }

rm -rf .dowel remote transfer-count.txt
ok "the first test run transfers the artifact" test --target=$TRIPLE
n1=$(count)
_last_cmd="wc -l transfer-count.txt"; OUT="$n1 transfers"; RC=0
[ "$n1" -eq 1 ]
fact $? "which really is one transfer"

ok "an unchanged tree runs the tests again" test --target=$TRIPLE
n2=$(count)
_last_cmd="wc -l transfer-count.txt"; OUT="$n2 transfers after two runs"; RC=0
[ "$n2" -eq 1 ]
fact $? "and sends nothing the second time"

# 送るものが変われば送る。指紋は成果物のものであり、木のものではない。
sed -i 's|return 0;|return 0; /* touched */|' tests/remote_test.c
ok "changing the source and testing again works" test --target=$TRIPLE
n3=$(count)
_last_cmd="wc -l transfer-count.txt"; OUT="$n3 transfers after the artifact changed"; RC=0
[ "$n3" -eq 2 ]
fact $? "a changed artifact is sent again"
sed -i 's| /\* touched \*/||' tests/remote_test.c

# 記録はビルドディレクトリに在る。構成ごとに分かれ、構成と共に死ぬ。
if [ -f ".dowel/build/$TRIPLE-debug/transfers" ]; then
    fact 0 "what was sent is recorded in the build directory"
else
    fact 1 "what was sent is recorded in the build directory"
fi

# 記録を消せば送り直す。古くなった記録は、古くなったビルド状態を捨てる
# のと同じ手立てで捨てられる——そのための別の切り替えは要らない。
run test --target=$TRIPLE
before=$(count)
rm -f ".dowel/build/$TRIPLE-debug/transfers"
ok "testing after the record is gone works" test --target=$TRIPLE
after=$(count)
_last_cmd="wc -l transfer-count.txt"; OUT="$before -> $after"; RC=0
[ "$after" -eq $((before + 1)) ]
fact $? "removing the record makes the next run send again"


# ここが決定の正直な半分である。dowel は対象機を見られないので、誰かが
# 消したことは分からない。分かるのは**起動に失敗したこと**だけであり、
# それを使えば、気づいた次の実行で直る。
#
# 仕組みそのものは働く。起動そのものが成り立たなかった場合——`command` に
# 書いた道具が無い——次の実行は送り直す。

launcher() {
    python3 - "$1" "$2" <<'EOF'
import sys
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t.replace('command    = "%s"' % sys.argv[1],
                             'command    = "%s"' % sys.argv[2]))
EOF
}

run test --target=$TRIPLE
before=$(count)
launcher sh no-such-launcher-xyz
run test --target=$TRIPLE
said=$OUT; rc=$RC
[ "$rc" -ne 0 ]; _verdict $? "a run whose launcher does not exist fails"
printf '%s' "$said" | grep -q 'could not start'
fact $? "and is reported as a launch that never happened"
launcher no-such-launcher-xyz sh
ok "and the run after it works" test --target=$TRIPLE
after=$(count)
_last_cmd="wc -l transfer-count.txt"; OUT="$before -> $after"; RC=0
[ "$after" -eq $((before + 1)) ]
fact $? "a run that could not start drops the record, so the next one sends again"

# そして、この決定が動機として挙げている場面——対象機から成果物が消えた
# ——でも直る（ADR-0052、[F-066](../../docs/10-findings.md#f-066)）。
#
# そこでは起動は成り立つ。dowel が起こすのは手元の運び手（ssh や sh）で
# あり、それは問題なく始まる。消えていることが分かるのは向こう側で、
# 返ってくるのは終了状態である。**通らなかった実行が記録を落とす**なら、
# 一番強い証拠を使ったことになる。
run test --target=$TRIPLE
before=$(count)
rm -f remote/remote_test
fails "a run whose artifact vanished from the target fails" test --target=$TRIPLE
mid=$(count)
_last_cmd="wc -l transfer-count.txt"; OUT="$before -> $mid (the run that noticed)"; RC=0
[ "$mid" -eq "$before" ]
fact $? "the run that noticed does not itself re-send"

ok "and the run after it passes" test --target=$TRIPLE
recovered=$(count)
_last_cmd="wc -l transfer-count.txt"; OUT="$mid -> $recovered (the run after)"; RC=0
[ "$recovered" -eq $((mid + 1)) ]
fact $? "a machine that lost the artifact recovers on the run after the one that noticed"

if [ -f remote/remote_test ]; then
    fact 0 "so the artifact is back on the target machine, with nothing touched by hand"
else
    fact 1 "so the artifact is back on the target machine, with nothing touched by hand"
fi

# 代償は言葉にできる形をしている。落ち続けるテストは実行ごとに1回送る。
# 記録の鍵は転送の命令であって case ではないので、20 の case のうち1つが
# 落ちても、払うのは実行あたり1回である。
sed -i 's|return 0;|return 4;|' tests/remote_test.c
run test --target=$TRIPLE
before=$(count)
fails "a test that keeps failing still fails" test --target=$TRIPLE
after=$(count)
_last_cmd="wc -l transfer-count.txt"; OUT="$before -> $after"; RC=0
[ "$after" -eq $((before + 1)) ]
fact $? "and a failing run pays exactly one transfer, that being the price"
sed -i 's|return 4;|return 0;|' tests/remote_test.c
ok "a passing run writes the record back" test --target=$TRIPLE
before=$(count)
ok "so the run after it skips again" test --target=$TRIPLE
after=$(count)
_last_cmd="wc -l transfer-count.txt"; OUT="$before -> $after"; RC=0
[ "$after" -eq "$before" ]
fact $? "which is the skip returning once the tree is healthy"

rm -f transfer-count.txt
