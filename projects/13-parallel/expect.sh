# 13-parallel — テストの並列実行
#
# `--test-jobs=<n>` で同時に走らせる。既定は逐次であり、これは意図した既定で
# ある。C のテストは共有資源（同じ作業ディレクトリ、固定のポート、書き出し先）
# を用いる場合があり、並列を既定にすると順序に依存する失敗が発生する。
#
# 同時に走っているかどうかを、**時間ではなくテスト自身に観測させる**。
# 各テストは自分の印を置き、少し待ち、その時点で見えた印の数を記録する。
# 逐次なら常に1、並列なら2以上が現れる。壁時計の閾値に頼ると、
# 負荷の高い機械で falsely 落ちる検査になる（docs/00-design.md 6節）。

SUBJECT=$PWD/subject
RUN=$SUBJECT/run

# observed <dowel args...> — テストを走らせ、結果を変数へ置く。
#
#   SEEN  同時に見えた数の最大（逐次なら 1）
#   SAID  出力（判定のたびに OUT は捨てられるため別に控える）
#   RC    終了状態
#
# 値を返さず変数へ置くのは、`n=$(observed)` と書くと部分シェルで走り、
# 中で設定した変数が呼び出し側に残らないためである。
SEEN=""; SAID=""
observed() {
    rm -rf "$RUN"; mkdir -p "$RUN"
    OUT=$("$DOWEL" -C subject test "$@" 2>&1)
    RC=$?
    SAID=$OUT
    _last_cmd="dowel test $*"
    SEEN=$(cat "$RUN"/*.seen 2>/dev/null | sort -n | tail -1)
}

# order <dowel args...> — 報告に現れたテストの順序。
order() {
    "$DOWEL" -C subject test "$@" 2>&1 | grep -oE 'subject:t[0-9]' | tr '\n' ' '
}

mkdir -p "$RUN"

# ------------------------------------------------------- 既定は逐次

observed
[ "$RC" -eq 0 ] && [ "$SEEN" = 1 ]
_verdict $? "by default the tests do not overlap"
printf '%s' "$SAID" | grep -q '4 passed'
fact $? "all of them pass when run sequentially"

observed --test-jobs=1
[ "$RC" -eq 0 ] && [ "$SEEN" = 1 ]
_verdict $? "--test-jobs=1 is the same as the default"

# ------------------------------------------------------- 並列

observed --test-jobs=4
[ "$RC" -eq 0 ] && [ "${SEEN:-0}" -ge 2 ]
_verdict $? "--test-jobs=4 really runs them at the same time"
printf '%s' "$SAID" | grep -q '4 passed'
fact $? "all of them pass when run in parallel"

# 同時に走らせても、走らせる本数は変わらない。取りこぼしは件数に出る。
observed --test-jobs=2
[ "$RC" -eq 0 ] && [ "${SEEN:-0}" -ge 2 ]
_verdict $? "--test-jobs=2 overlaps as well"
printf '%s' "$SAID" | grep -q '4 passed'
fact $? "every test still runs when only two go at a time"

# ------------------------------------------------------- 表示は常に要求順
#
# 並列にすると終わる順序は入れ替わる。報告まで入れ替わると、
# 実行のたびに出力が変わり、差分で読めなくなる。

want=$(order)
got=$(order --test-jobs=4)
[ "$want" = "$got" ]
_last_cmd="dowel test --test-jobs=4 | grep -o 'subject:t[0-9]'"
OUT="sequential: $want / parallel: $got"
_verdict $? "the report keeps the requested order under parallelism"

# ------------------------------------------------------- 失敗の扱い
#
# 並列にしたときだけ落ちた回数が変わるなら、どちらの結果を信じてよいのか
# 分からなくなる。

sed -i 's|return overlap_observe(RUN_DIR, "t2") < 0 ? 1 : 0;|return 3;|' \
    "$SUBJECT/tests/t2.c"

rm -rf "$RUN"; mkdir -p "$RUN"
fails "a failing test fails the run when sequential" -C subject test
out_has "3 passed; 1 failed" "the sequential summary counts it once" -C subject test

rm -rf "$RUN"; mkdir -p "$RUN"
fails "a failing test fails the run when parallel" -C subject test --test-jobs=4
out_has "3 passed; 1 failed" "the parallel summary counts it the same" \
    -C subject test --test-jobs=4
out_has "exited with status 3" "the exit status of the failing test survives parallelism" \
    -C subject test --test-jobs=4

# 落ちたものだけを走らせ直す経路も、並列のあとで効く必要がある。
out_has "0 passed; 1 failed" "--failed reruns only the failure after a parallel run" \
    -C subject test --failed
out_lacks "subject:t1" "--failed leaves the passing tests alone after a parallel run" \
    -C subject test --failed

sed -i 's|return 3;|return overlap_observe(RUN_DIR, "t2") < 0 ? 1 : 0;|' \
    "$SUBJECT/tests/t2.c"
rm -rf "$RUN"; mkdir -p "$RUN"
ok "the repaired test passes again in parallel" -C subject test --test-jobs=4

# ------------------------------------------------------- 引数

fails "--test-jobs with a negative count is refused" -C subject test --test-jobs=-1
fails "--test-jobs with a non-number is refused"     -C subject test --test-jobs=abc

rm -rf "$RUN"
