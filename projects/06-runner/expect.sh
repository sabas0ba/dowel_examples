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
