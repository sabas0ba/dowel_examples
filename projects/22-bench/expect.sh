# 22-bench — 測るための種別
#
# `dowel bench` は `bench` 種別を組み、**過程まるごとの実時間**を測って
# min と median を出す（ADR-0025）。枠組みは課されず、読まれもしない。
# C には測定結果の綴りに慣習が無く、枠組みごとに1つ形式を解釈するのが
# ADR の拒む絡まりである。過程の外から測るなら、どの実行ファイルにも
# 同じ物差しが当たる。
#
# ここで見るのは4つ。
#
#   1. **速さに判定が無い。** 遅い事例は落ちない。落ちるのは走り切れな
#      かったときだけで、そのときは**数を1つも出さない**
#   2. **判定のある側と分かれている。** `dowel test` は bench を走らせず、
#      `dowel bench` は test を走らせない
#   3. **不変量。** min ≤ median ≤ max、`runs` が `--iterations` と一致
#   4. **測るものと判定するものの区別が宣言にも要る。** `should_fail` は
#      bench の事例では拒まれ、`harness` も受け付けない
#
# 時間そのものは検査にしない。速さは機械と負荷で変わるので、固定できる
# のは**関係**（min ≤ median）と**形**（数が出る／出ない）だけである。

ITER=3

# bench <dowel 引数...> — 測って出力を返す。
bench() {
    _last_cmd="dowel bench $*"
    OUT=$("$DOWEL" -C subject bench "$@" 2>&1)
    RC=$?
    return 0
}

# bench_json <dowel 引数...> — 機械可読の測定結果だけを返す。
bench_json() {
    "$DOWEL" -C subject bench "$@" --message-format=json 2>/dev/null |
        grep '"kind":"bench-result"'
}

# ------------------------------------------------------------ 1. 語彙にある

ok "the package passes check" -C subject check

kinds=$("$DOWEL" schema dump 2>/dev/null |
        jq -r '.table_kinds[] | select(.name == "bench") | "\(.is_target) \(.implemented)"')
_last_cmd="schema dump | .table_kinds[] | bench"; OUT="is_target implemented: $kinds"; RC=0
[ "$kinds" = "true true" ]
fact $? "bench is a target kind, and an implemented one"

# ------------------------------------------------------------ 2. 測れる

bench --iterations=$ITER
said=$OUT                       # 判定は OUT を消すので、先に控える
rc=$RC
_last_cmd="dowel bench --iterations=$ITER"; OUT="$said"; RC=0
[ "$rc" -eq 0 ]
fact $? "dowel bench builds the targets and measures them"

_last_cmd="dowel bench の出力"; OUT="$said"; RC=0
printf '%s' "$said" | grep -qE 'bench b:spin/small \.\.\. min .* median .* \(3 runs\)'
fact $? "reporting min and median over the requested number of runs"

# 3つの事例が独立に測られる。事例は test と同じ形で登録する。
n=$(printf '%s' "$said" | grep -c '^bench b:spin/')
_last_cmd="dowel bench | 事例の行数"; OUT="$said"; RC=0
[ "$n" = 3 ]
fact $? "each declared case is measured in its own right"

# ラベルの文法は test と同じである。
_last_cmd="dowel bench の出力"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'b:spin/big'
fact $? "under the same label grammar a test case has"

# 名指しで1件だけ測れる。
bench b:spin/small --iterations=2
said=$OUT
_last_cmd="dowel bench b:spin/small"; OUT="$said"; RC=0
n=$(printf '%s' "$said" | grep -c '^bench b:spin/')
[ "$n" = 1 ]
fact $? "and naming one measures only it"

# ------------------------------------------------------------ 3. 不変量
#
# 時間そのものは固定できない。固定できるのは関係と形である。

j=$(bench_json --iterations=$ITER)
_last_cmd="dowel bench --message-format=json"; OUT=$(printf '%s' "$j" | head -2); RC=0
[ "$(printf '%s\n' "$j" | grep -c 'bench-result')" = 3 ]
fact $? "the machine-readable form emits one bench-result per measurement"

bad=$(printf '%s' "$j" | jq -r 'select((.min_us > .median_us) or (.median_us > .max_us)) | .label')
_last_cmd="bench-result | min_us <= median_us <= max_us"
OUT=$(printf '%s' "$j" | jq -c '{label, min_us, median_us, max_us}')
RC=0
[ -z "$bad" ]
fact $? "with min never above median, and median never above max"

# 整数のマイクロ秒である。小数の描画は読む側の決めることであり、
# 数の側に持ち込むと比較のたびに丸めが問題になる。
bad=$(printf '%s' "$j" | jq -r 'select((.min_us | floor) != .min_us) | .label')
_last_cmd="bench-result | min_us が整数か"; OUT=$(printf '%s' "$j" | jq -c '.min_us'); RC=0
[ -z "$bad" ]
fact $? "and the times given as whole microseconds, leaving the rendering to the reader"

# `--iterations` が実際に効く。既定は 10 である。
runs=$(bench_json --iterations=5 | jq -r '.runs' | sort -u | paste -sd' ' -)
_last_cmd="dowel bench --iterations=5 | .runs"; OUT="runs: $runs"; RC=0
[ "$runs" = 5 ]
fact $? "the number of runs is the one asked for"

runs=$(bench_json | jq -r '.runs' | sort -u | paste -sd' ' -)
_last_cmd="dowel bench | .runs（既定）"; OUT="runs: $runs"; RC=0
[ "$runs" = 10 ]
fact $? "and ten when nothing is asked"

# 事例の属性も出る。どの引数で測ったのかが分からなければ、数は読めない。
got=$(printf '%s' "$j" | jq -r 'select(.case == "big") | .args | join(",")')
_last_cmd="bench-result | .args"; OUT="args: $got"; RC=0
[ "$got" = "big" ]
fact $? "carrying the arguments the case was measured with"

# ------------------------------------------------------------ 4. 速さに判定は無い
#
# ここが test との本質的な差である。遅いことは失敗ではない。

j=$(bench_json --iterations=2)
slow=$(printf '%s' "$j" | jq -r 'select(.case == "slow") | .min_us')
small=$(printf '%s' "$j" | jq -r 'select(.case == "small") | .min_us')
_last_cmd="bench-result | slow と small の min_us"
OUT="slow: ${slow:-?}us"$'\n'"small: ${small:-?}us"
RC=0
[ -n "$slow" ] && [ -n "$small" ] && [ "$slow" -gt "$small" ]
fact $? "the slow case really is slower, which is a measurement and not a verdict"

bench --iterations=2
said=$OUT; rc=$RC
_last_cmd="dowel bench  # 遅い事例を含む"
OUT=$(printf '%s' "$said" | tail -4); RC=0
[ "$rc" -eq 0 ]
fact $? "so a benchmark that takes longer still succeeds"

# 閾値も回帰の門も dowel には無い。下流の方針として JSON に当てるもので
# ある——ここでは「そういう旗が無い」ことを固定しておく。
_last_cmd="dowel bench --help | 閾値らしき旗"; RC=0
OUT=$("$DOWEL" bench --help 2>&1 |
      grep -oE '^[[:space:]]+--[a-z-]+' |
      grep -iE 'threshold|regression|baseline|compare|fail-if' | head -3)
[ -z "$OUT" ]
fact $? "and dowel offers no threshold of its own, leaving that to whatever reads the JSON"

# ------------------------------------------------------------ 5. 走り切れなければ落ちる
#
# 落ちるのは「走り切れなかった」ときだけである。そしてそのときは
# **数を1つも出さない**——途中までの統計は、完了した測定として読める。

cp subject/dowel.build subject/dowel.build.keep
python3 - <<'PY'
p = "subject/dowel.build"
t = open(p, encoding="utf-8").read()
t = t.replace('slow  = { args = ["slow"] }',
              'slow  = { args = ["slow"] }\nboom  = { args = ["boom"] }')
open(p, "w", encoding="utf-8").write(t)
PY

bench --iterations=$ITER
said=$OUT; rc=$RC
_last_cmd="dowel bench  # 走り切れない事例がある"
OUT=$(printf '%s' "$said" | tail -6); RC=0
[ "$rc" -ne 0 ]
fact $? "a run that could not be completed fails the whole invocation"

_last_cmd="dowel bench の出力"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'exited with status 3'
fact $? "naming what happened to it"

# その事例の数は1つも出ない。
line=$(printf '%s' "$said" | grep 'b:spin/boom' | grep -c 'min ')
_last_cmd="dowel bench | boom の行に min があるか"
OUT=$(printf '%s' "$said" | grep -A1 'b:spin/boom' | head -3)
RC=0
[ "$line" = 0 ]
fact $? "and no numbers at all for it, because a partial series reads as a finished measurement"

j=$(bench_json --iterations=$ITER)
got=$(printf '%s' "$j" | jq -r 'select(.case == "boom") | "\(.min_us) \(.median_us)"')
_last_cmd="bench-result | boom"; OUT="${got:-(no record)}"; RC=0
[ -z "$got" ] || [ "$got" = "null null" ]
fact $? "the machine-readable form withholds them too"

# 他の事例は測られる。1つ落ちても、残りの測定は捨てない。
n=$(printf '%s' "$said" | grep -c '^bench b:spin/.* min ')
_last_cmd="dowel bench | 数の出た事例"; OUT="$said"; RC=0
[ "$n" = 3 ]
fact $? "while the cases that did complete are still reported"

# 止まらない事例は timeout で殺され、同じく測定不能になる。
python3 - <<'PY'
p = "subject/dowel.build"
t = open(p, encoding="utf-8").read()
t = t.replace('boom  = { args = ["boom"] }',
              'hang  = { args = ["hang"], timeout = 2 }')
open(p, "w", encoding="utf-8").write(t)
PY
bench --iterations=2
said=$OUT; rc=$RC
_last_cmd="dowel bench  # timeout = 2 の止まらない事例"
OUT=$(printf '%s' "$said" | tail -5); RC=0
[ "$rc" -ne 0 ]
fact $? "a case that never returns is killed by its timeout and reported as unmeasurable"

line=$(printf '%s' "$said" | grep 'b:spin/hang' | grep -c 'min ')
_last_cmd="dowel bench | hang の行に min があるか"; OUT="$said"; RC=0
[ "$line" = 0 ]
fact $? "with no numbers for it either"
mv subject/dowel.build.keep subject/dowel.build

# ------------------------------------------------------------ 6. 判定する側と分かれている

run -C subject test
_last_cmd="dowel test  # 同じ木に bench もある"; OUT=$(printf '%s' "$OUT" | tail -4); RC=0
! printf '%s' "$OUT" | grep -q 'spin'
fact $? "dowel test runs the tests and not the benchmarks"

bench --iterations=2
said=$OUT
_last_cmd="dowel bench  # 同じ木に test もある"; OUT="$said"; RC=0
! printf '%s' "$said" | grep -q 'b:t'
fact $? "and dowel bench runs the benchmarks and not the tests"

# 組む側は両方を組む。測る前に組めていなければ、測定は始まらない。
run -C subject build --no-compdb
built=$(printf '%s' "$OUT" | sed -n 's/^built: //p' | sed 's|.*/||' | sort | paste -sd' ' -)
_last_cmd="dowel build | built:"; OUT="$built"; RC=0
printf '%s' "$built" | grep -q 'spin' && printf '%s' "$built" | grep -q 't'
fact $? "while an ordinary build produces both, since a benchmark is still an executable"

# ------------------------------------------------------------ 7. 宣言の側の区別
#
# 測るものと判定するものの差は、宣言にも現れる。

cp subject/dowel.build subject/dowel.build.keep
sed -i 's|small = { args = \["small"\] }|small = { args = ["small"], should_fail = true }|' \
    subject/dowel.build
fails "a bench case may not declare should_fail" -C subject check
run -C subject check
_last_cmd="dowel check  # bench の事例に should_fail"
OUT=$(printf '%s' "$OUT" | grep -m4 'error\|note')
RC=0
printf '%s' "$OUT" | grep -qi 'should_fail'
fact $? "and the refusal names it, because a measurement has no verdict to invert"
mv subject/dowel.build.keep subject/dowel.build

cp subject/dowel.build subject/dowel.build.keep
printf '\n[bench.spin.harness]\nrun = "--run"\n' >>subject/dowel.build
fails "nor may a bench discover its cases through a harness" -C subject check
mv subject/dowel.build.keep subject/dowel.build

# 始めるものが無い側は測れない。ライブラリには入口が無い。
run -C subject bench quiet
_last_cmd="dowel bench quiet  # lib"; OUT=$(printf '%s' "$OUT" | grep -m3 'error'); RC=0
[ "$RC" -eq 0 ] || true
printf '%s' "$OUT" | grep -q 'error'
fact $? "and a library cannot be benchmarked, having nothing to start"

# ------------------------------------------------------------ 8. 開ける
#
# 測って遅かったものは、次に見たいのが中身である。`dowel debug` は
# bench も受ける（bin / test / bench）。

launch=$("$DOWEL" -C subject debug b:spin/big --dap 2>/dev/null)
_last_cmd="dowel debug b:spin/big --dap"; OUT="$launch"; RC=0
printf '%s' "$launch" | jq -e '.args == ["big"]' >/dev/null 2>&1
fact $? "a benchmark case can be opened under the debugger, carrying its arguments"

# ------------------------------------------------------------ 9. 増分

"$DOWEL" -C subject build --no-compdb >/dev/null 2>&1
runs_actions 0 "a second build of the benchmark runs nothing" -C subject --no-compdb

printf '\n/* touched */\n' >>subject/src/spin.c
build_direct -C subject --no-compdb
rebuilt "spin.c" "editing the measured source recompiles it"
not_rebuilt "tests_t.c" "and leaves the test that shares the package alone"
