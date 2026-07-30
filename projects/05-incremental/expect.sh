# 05-incremental — 編集してからの再ビルド
#
# ビルドシステムの主要な機能は2回目以降の実行にある。1回の実行を並べても、
# 編集と再実行を繰り返す経路は検査できない（dowel 本体の docs/51-testing.md）。
#
# 検査は計数で行う。値が正しいことは、再計算しなかったことを意味しない。
# 件数だけでは「どれが走ったか」が分からないため、走ったアクションの記述も見る。
# 波及しないことは、走らなかったことでしか観測できない。

cd app || exit 1

# 中身を変える。更新時刻だけを動かすのとは別の操作である。
edit() { printf '\n/* edit %s */\n' "$$-$RANDOM" >>"$1"; }

CORE_SCALE=obj/core/core/src_scale.c.o
CORE_OFFSET=obj/core/core/src_offset.c.o
APP_MAIN=obj/app/app/src_main.c.o
SCALE_TEST=obj/core/scale_test/tests_scale_test.c.o

# --------------------------------------------------- 基準

ok "app: check passes" check
runs_actions 9 "a first build runs every action (5 compiles, 1 archive, 3 links)"
prints "scale=6 offset=10" "the binary runs" "$(artifact app)"
runs_actions 0 "a second build runs nothing"

# --------------------------------------------------- ソースの編集

edit ../core/src/scale.c
runs_actions 5 "editing one source rebuilds it and everything downstream"
rebuilt     "$CORE_SCALE"  "the edited unit is recompiled"
not_rebuilt "$CORE_OFFSET" "the other unit of the same target is not"
not_rebuilt "$APP_MAIN"    "a dependent's own sources are not recompiled"
rebuilt     "AR lib/libcore.a" "the archive is rebuilt"
rebuilt     "LINK bin/app"     "the dependent is relinked"

edit src/main.c
runs_actions 2 "editing a dependent's source touches nothing in the dependency"
not_rebuilt "AR lib/libcore.a" "the dependency's archive is left alone"

# --------------------------------------------------- ヘッダの編集
#
# ここが本プロジェクトの主題である。ヘッダの依存はマニフェストに書かれておらず、
# コンパイラの depfile からしか分からない。読めていなければ何も起きず、
# 古い成果物が成功として報告される。

edit ../core/src/internal.h
runs_actions 5 "editing a private header rebuilds through the depfile"
rebuilt     "$CORE_OFFSET" "the unit that includes the private header is recompiled"
not_rebuilt "$CORE_SCALE"  "a unit of the same target that does not include it is not"
not_rebuilt "$APP_MAIN"    "a private header never reaches a dependent"
not_rebuilt "$SCALE_TEST"  "nor a test that only uses the public header"

edit ../core/include/core.h
runs_actions 9 "editing a public header rebuilds every dependent unit"
rebuilt "$CORE_SCALE"  "the dependency's own units are recompiled"
rebuilt "$CORE_OFFSET" "both of them"
rebuilt "$APP_MAIN"    "and the dependent's unit as well"
rebuilt "$SCALE_TEST"  "and the tests"

# 内容を変えず更新時刻だけ動かす。実行器の最新性判定は mtime による
# （docs/91-implementation-status.md のビルドの節）。したがって走る。
# 内容で判定する形に変えるなら、本体の文書も一緒に変わる。
touch ../core/src/scale.c
runs_actions 5 "touching a source without changing it still rebuilds (mtime judgement)"

# --------------------------------------------------- マニフェストの編集
#
# 対して、マニフェスト側は内容で判定される。評価をやり直しても、
# 生成されるコマンド列が同じなら実行はしない。

touch dowel.build
runs_actions 0 "touching the manifest without changing it rebuilds nothing"

printf '\n# a comment, nothing else\n' >>dowel.build
runs_actions 0 "adding only a comment to the manifest rebuilds nothing"

python3 - <<'PY'
import pathlib
p = pathlib.Path("dowel.build")
p.write_text(p.read_text(encoding="utf-8").replace(
    'deps = [dep("core")]',
    'deps  = [dep("core")]\nflags = ["-DAPP_EXTRA=1"]'), encoding="utf-8")
PY
runs_actions 2 "adding a flag recompiles the target it applies to"
rebuilt     "$APP_MAIN"   "the flag reaches the compile action"
not_rebuilt "$CORE_SCALE" "and no further than the target that declares it"

# --------------------------------------------------- ソースの増減

printf '#include "core.h"\nint core_extra(void) { return 1; }\n' >../core/src/extra.c
runs_actions 5 "adding a source compiles only the new one"
rebuilt     "src_extra.c.o" "the new unit is compiled"
not_rebuilt "$CORE_SCALE"   "the existing units are not"

rm ../core/src/extra.c
runs_actions 4 "removing a source rebuilds the archive without compiling anything"
not_rebuilt "CC " "no compile action runs when only a source disappeared"

# --------------------------------------------------- 構成の切り替え

runs_actions 9 "the first release build runs every action" --config=release
runs_actions 0 "switching back to debug rebuilds nothing"
runs_actions 0 "switching to release again rebuilds nothing" --config=release

# --------------------------------------------------- テストの再実行

cd ../core || exit 1

ok "core: both tests pass" test

sed -i 's|return core_scale(3) == 3 \* CORE_SCALE ? 0 : 1;|return 1;|' tests/scale_test.c
fails "test exits non-zero when a test fails" test
out_has "1 passed; 1 failed" "the summary counts both outcomes" test

# --failed は前回落ちた分だけを走らせる。走らせなかったことは件数でしか見えない。
out_has "0 passed; 1 failed" "--failed reruns only what failed last time" test --failed
out_lacks "offset_test" "--failed leaves the passing test alone" test --failed

sed -i 's|return 1;|return core_scale(3) == 3 * CORE_SCALE ? 0 : 1;|' tests/scale_test.c
ok "the repaired test passes under --failed" test --failed
out_has "nothing to rerun" "--failed says so when nothing failed last time" test --failed

# 判定が消えないこと。走らせなかったターゲットの記録は残る（docs/60-cli.md）。
ok "a full run passes again" test

# --------------------------------------------------- 実行器を跨ぐ
#
# 実行器は差し替え可能なものとして提示されている（`--executor=ninja|direct`、
# ninja が無ければ direct へ落ちる）。利用者から見れば「同じものを別の方法で
# 実行するだけ」であり、片方で組んでから他方に渡すのは自然な操作である。
#
# かつて依存の記録は共有されていなかった。ninja は depfile を読むと `.d` を
# 消して `.ninja_deps` に畳むため、そのあと direct へ渡るとヘッダの依存情報が
# 1件も無い状態で最新性を判定し、黙って古い成果物を残していた
# （docs/10-findings.md F-014）。
#
# コマンドの記録は共有されていたため目的物は再利用され、**部分的に
# 共有されていること**が原因になっていた。4通りすべてを見る。
#
# 別のパッケージを使う。core の検査は「両側が同じ定数を使う」形であり、
# 双方が古いままなら food違いが打ち消し合ってテストが通ってしまう。
# ここでは成果物の終了状態にヘッダの値をそのまま載せ、
# **古いまま残ったこと自体**を観測できるようにする。

cd ../crossing || exit 1

# built_value — 成果物を起動し、組まれた時点のヘッダの値を返させる。
built_value() {
    local p
    p=$(find .dowel/build -type f -path '*/bin/show' 2>/dev/null | head -1)
    [ -n "$p" ] || { printf '(no artifact)'; return 0; }
    "$p"
    printf '%s' "$?"
}

for pair in "ninja direct" "direct ninja" "ninja ninja" "direct direct"; do
    set -- $pair
    first=$1 second=$2
    rm -rf .dowel
    printf '#define VALUE 3\n' > include/value.h
    run build --executor="$first"

    printf '#define VALUE 7\n' > include/value.h
    run build --executor="$second"

    got=$(built_value)
    [ "$got" = 7 ]; verdict=$?
    fact "$verdict" "a header edit is seen after building with $first then $second"
done

printf '#define VALUE 3\n' > include/value.h
