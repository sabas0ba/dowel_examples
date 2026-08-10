# 20-cases — 1本の実行ファイルから複数のテストを登録する
#
# `[test.<name>.cases]` は ctest の `add_test` にあたる（ADR-0022）。事例は
# **同じ実行ファイルの別の起動**であり、翻訳単位を増やさない。分けるのは
# 引数だけである。ハーネスの規約は採らない——dowel は実行ファイルに
# 「どんな事例を含むか」を尋ねない。
#
# ここで見るのは3つある。
#
#   1. **宣言が届くか。** args / env / timeout / should_fail / labels
#   2. **選べるか。** --label / --failed / --fail-fast / --test-jobs、
#      そして印字された名前をコマンドラインに渡し返せるか
#   3. **宣言が語彙として見えるか。** schema dump と言語サーバ、
#      走らせずに一覧すること
#
# 3 が本スイートの持ち場である。1 と 2 は本体も内側から見ているが、
# 「文書に書いてあるとおりか」「エディタが同じことを知っているか」は
# 外側からしか問えない。

SUBJECT=$PWD/subject
RUN=$SUBJECT/run

# labels_of — 事例の名前だけを並べる。
ran() {
    "$DOWEL" -C subject test "$@" 2>&1 | sed -n 's/^test \(subject:[^ ]*\) \.\.\..*/\1/p'
}

# case_status <dowel args...> — 走らせて状態だけを RC に置く。
CASE_SAID=""
case_status() {
    CASE_SAID=$("$DOWEL" -C subject test "$@" 2>&1)
    RC=$?
    _last_cmd="dowel test $*"
    return 0
}

# with_cases <置換前> <置換後> — cases の表を書き換える。
CASES_BAK=""
with_cases() {
    [ -n "$CASES_BAK" ] || CASES_BAK=$(cat subject/dowel.build)
    python3 - "$1" "$2" <<'PY'
import sys
p = "subject/dowel.build"
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(t.replace(sys.argv[1], sys.argv[2]))
PY
}

restore_cases() {
    [ -n "$CASES_BAK" ] && printf '%s\n' "$CASES_BAK" >subject/dowel.build
    CASES_BAK=""
}

# ------------------------------------------------------------ 1. 宣言が届く

ok "a package that registers cases passes check" -C subject check
ok "and all of its cases pass"                   -C subject test

got=$(ran | tr '\n' ' ' | sed 's/ *$//')
want="subject:suite/plain subject:suite/slow subject:suite/rejects subject:suite/strict subject:suite/patient subject:lone"
[ "$got" = "$want" ]
v=$?; RC=0; _last_cmd="dowel test | 走った事例"
OUT="want: $want"$'\n'"got:  $got"
fact $v "each case is reported under <package>:<target>/<case>"

# 事例を書かない目標は、目標自身が1件である。規則は ADR-0022 が定めている。
case $got in *subject:lone*) v=0 ;; *) v=1 ;; esac
RC=0; _last_cmd="dowel test | 走った事例"; OUT="$got"
fact $v "a target with no cases block is one test named after the target"

# 事例は翻訳単位を増やさない。5件でも実行ファイルは1本である。
n=$("$DOWEL" -C subject graph --kind=action --format=json 2>/dev/null |
    jq -r '.steps[] | select(.kind == "link") | .outputs[]' | sort -u | wc -l)
[ "$n" = 2 ]
v=$?; RC=0; _last_cmd="graph --kind=action | link の出力"
OUT="linked binaries: ${n:-?} (suite と lone の2本。事例は5件ある)"
fact $v "cases add no translation unit; five of them share one binary"

# args は起動の末尾に付く。事例を分けているのはこれである。
out_has "argv[1]=plain" "the args of a case reach the binary" \
    -C subject test --nocapture

# env はその事例にだけ効く。
out_has "SUITE_MODE=strict" "the env of a case reaches the binary" \
    -C subject test --nocapture

# should_fail は判定を反転する。
_last_cmd="dowel test | rejects"
OUT=$("$DOWEL" -C subject test 2>&1 | grep 'rejects')
RC=0
printf '%s' "$OUT" | grep -q '\.\.\. ok'
fact $? "should_fail turns a nonzero exit into a pass"

# 状態0で終わったら、期待の側を述べて落ちる。
with_cases 'rejects = { args = ["fail"], should_fail = true }' \
           'rejects = { args = ["plain"], should_fail = true }'
case_status
said=$CASE_SAID
_last_cmd="dowel test  # should_fail の事例が状態0で終わった"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'should_fail'
fact $? "and a case that was supposed to fail says so rather than reporting a bare status"
restore_cases

# ------------------------------------------------------------ 2. 時間切れ

with_cases 'patient = { args = ["plain"], timeout = 30 }' \
           'patient = { args = ["hang"], timeout = 2 }'
case_status
said=$CASE_SAID
_last_cmd="dowel test  # 固まる事例に timeout = 2"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'timed out'
fact $? "a case past its timeout is killed and reported as timed out"

# 時間切れは should_fail に優先する。異常な終わり方は期待された失敗ではない。
with_cases 'patient = { args = ["hang"], timeout = 2 }' \
           'patient = { args = ["hang"], timeout = 2, should_fail = true }'
case_status
said=$CASE_SAID
_last_cmd="dowel test  # should_fail と timeout の両方"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'timed out'
fact $? "a timeout wins over should_fail, so a hang is never an expected failure"

# 同じ理屈がシグナルにも要る（docs/10-findings.md F-032）。
with_cases 'patient = { args = ["hang"], timeout = 2, should_fail = true }' \
           'patient = { args = ["crash"], should_fail = true }'
case_status
said=$CASE_SAID
[ "$RC" -ne 0 ]
verdict=$?
_last_cmd="dowel test  # should_fail の事例が SIGSEGV で死ぬ"; OUT="$said"; RC=0
known_issue F-032
fact $verdict "a case killed by a signal does not satisfy should_fail"

OUT=$("$DOWEL" -C subject test --message-format=json 2>/dev/null |
      jq -c 'select(.target | endswith("patient"))')
RC=0
printf '%s' "$OUT" | grep -qE '"signal"|"killed"'
verdict=$?
_last_cmd="dowel test --message-format=json | patient"
known_issue F-032
fact $verdict "and the report distinguishes a crash from a nonzero exit"
restore_cases

# 0 以下の timeout は宣言として意味を成さない（F-033）。
with_cases 'patient = { args = ["plain"], timeout = 30 }' \
           'patient = { args = ["plain"], timeout = 0 }'
OUT=$(json_diags -C subject check)
RC=0
printf '%s' "$OUT" | jq -e '.code' >/dev/null 2>&1
verdict=$?
_last_cmd="dowel check  # timeout = 0"
known_issue F-033
fact $verdict "a timeout of zero or less is refused"
restore_cases

# ------------------------------------------------------------ 3. 選ぶ

got=$(ran --label slow)
[ "$got" = "subject:suite/slow" ]
v=$?; RC=0; _last_cmd="dowel test --label slow"; OUT="ran: ${got:-(nothing)}"
fact $v "a label selects the cases that carry it"

# 誰も持たないラベルは、0件通過にしてはならない。60-cli.md がそう述べている
# （docs/10-findings.md F-034）。
case_status --label nosuch
said=$CASE_SAID
[ "$RC" -ne 0 ]
verdict=$?
_last_cmd="dowel test --label nosuch; echo \$?"
OUT="rc: $RC"$'\n'"$said"; RC=0
known_issue F-034
fact $verdict "naming a label nobody carries does not pass with zero tests"

printf '%s' "$said" | grep -q 'no test carries'
fact $? "and it does say which label found nothing"

# 印字された名前をコマンドラインに渡し返せること（F-035）。
run -C subject test 'subject:suite/plain'
said=$OUT
[ "$RC" -eq 0 ] && printf '%s' "$said" | grep -q 'suite/plain'
verdict=$?
_last_cmd="dowel test subject:suite/plain"; OUT="$said"; RC=0
known_issue F-035
fact $verdict "the label a case is reported under selects that case on the command line"

got=$(ran suite)
n=$(printf '%s' "$got" | grep -c 'suite/')
[ "$n" = 5 ]
v=$?; RC=0; _last_cmd="dowel test suite"; OUT="$got"
fact $v "naming the target runs all of its cases"

# --fail-fast は最初の失敗で止め、走らなかった数を述べる。
with_cases 'plain   = { args = ["plain"] }' 'aaa_bad = { args = ["fail"] }'
case_status --fail-fast
said=$CASE_SAID
_last_cmd="dowel test --fail-fast"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'not run'
fact $? "--fail-fast stops at the first failure and says how many did not run"

# --failed は事例の単位で覚えている。
case_status
case_status --failed
said=$CASE_SAID
_last_cmd="dowel test; dowel test --failed"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'aaa_bad'
fact $? "--failed reruns the case that failed, not its whole target"

# 覚えていた事例が消えたら、それを述べる（F-036）。
with_cases 'aaa_bad = { args = ["fail"] }' 'renamed = { args = ["plain"] }'
case_status --failed
said=$CASE_SAID
[ "$RC" -ne 0 ]
verdict=$?
_last_cmd="覚えている事例を改名して dowel test --failed"
OUT="rc: $RC"$'\n'"$said"; RC=0
known_issue F-036
fact $verdict "rerunning failures says so when the remembered case is gone"
restore_cases

# ------------------------------------------------------------ 4. 並列

# 事例は並列に走る。表示は要求順である（60-cli.md）。
with_cases 'slow    = { args = ["sleep1"], labels = ["slow"] }' \
           'slow    = { args = ["sleep2"], labels = ["slow"] }'
start=$(now_ms)
"$DOWEL" -C subject test --test-jobs=4 >/dev/null 2>&1
elapsed=$(( $(now_ms) - start ))
[ "$elapsed" -lt 4000 ]
v=$?; RC=0; _last_cmd="time dowel test --test-jobs=4"
OUT="elapsed: ${elapsed}ms (sleep2 と sleep1 が直列なら 3000ms を超える)"
fact $v "cases of one target run at the same time under --test-jobs"

got=$(ran --test-jobs=4)
want=$(ran --test-jobs=1)
[ "$got" = "$want" ]
v=$?; RC=0; _last_cmd="dowel test --test-jobs=4   vs   --test-jobs=1"
OUT="parallel:"$'\n'"$got"$'\n'"sequential:"$'\n'"$want"
fact $v "and the display stays in request order however many run at once"
restore_cases

# ------------------------------------------------------------ 5. 事例の検証

# 未知の鍵は拒み、受け付ける鍵を並べる。
with_cases 'plain   = { args = ["plain"] }' 'plain   = { args = ["plain"], nosuchkey = 1 }'
diag unknown-property "an unknown key in a case is refused" -C subject check
run -C subject check
said=$OUT
_last_cmd="dowel check  # 未知の鍵"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'a case accepts'
fact $? "and the accepted keys are listed"
restore_cases

with_cases 'plain   = { args = ["plain"] }' 'plain   = { args = "plain" }'
diag type-mismatch "a value of the wrong type in a case is refused" -C subject check
restore_cases

# 誤っている鍵を指すこと（F-037）。
with_cases 'strict  = { args = ["env"], env = { SUITE_MODE = "strict" } }' \
           'strict  = { args = ["env"], timeout = "x", env = { SUITE_MODE = "strict" } }'
OUT=$("$DOWEL" -C subject check 2>&1)
RC=0
_last_cmd="dowel check  # 長い事例の1つの鍵だけが誤り"
# 下線が事例全体に引かれていれば、その長さは事例の綴りと同じになる。
carets=$(printf '%s' "$OUT" | sed -n 's/^ *| *\(\^*\)$/\1/p' | head -1)
[ -n "$carets" ] && [ "${#carets}" -lt 30 ]
verdict=$?
OUT="$OUT"$'\n'"underlined: ${#carets} characters"
known_issue F-037
fact $verdict "a type error inside a case points at the key that is wrong"
restore_cases

# 事例の名前はラベルの一部になる。文法を壊す名前は拒みたい（F-038）。
with_cases 'plain   = { args = ["plain"] }' '"a/b"   = { args = ["plain"] }'
OUT=$(json_diags -C subject check)
RC=0
printf '%s' "$OUT" | jq -e '.code' >/dev/null 2>&1
verdict=$?
_last_cmd="dowel check  # 事例の名前が a/b"
known_issue F-038
fact $verdict "a case name that breaks the label grammar is refused"
restore_cases

with_cases 'plain   = { args = ["plain"] }' 'plain   = { args = ["plain"] }
plain   = { args = ["fail"] }'
diag duplicate-key "two cases with the same name are refused" -C subject check
restore_cases

# 表見出しで書くのは TOML では自然な形である。直し方を述べてほしい（F-039）。
cp subject/dowel.build subject/dowel.build.keep
printf '\n[test.suite.cases.extra]\nargs = ["plain"]\n' >>subject/dowel.build
run -C subject check
said=$OUT
_last_cmd="dowel check  # [test.suite.cases.extra] と書いた"; OUT="$said"; RC=0
printf '%s' "$said" | grep -qE 'inline table|args = \[|entries of'
verdict=$?
known_issue F-039
fact $verdict "writing a case as a table header says how to write it as an entry"
mv subject/dowel.build.keep subject/dowel.build

# cases は test だけのものである。
cp subject/dowel.build subject/dowel.build.keep
printf '\n[bin.app]\nsources = [file("tests/suite.c")]\n\n[bin.app.cases]\nx = { args = ["plain"] }\n' \
    >>subject/dowel.build
diag unknown-block "a cases block on a bin target is refused" -C subject check
run -C subject check
said=$OUT
_last_cmd="dowel check  # [bin.app.cases]"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'only `test` targets register cases'
fact $? "with what to do instead"
mv subject/dowel.build.keep subject/dowel.build

# 空の表は「事例を書かない」とは別の意図である（F-040）。
cp subject/dowel.build subject/dowel.build.keep
printf '\n[test.empty]\nsources = [file("tests/suite.c")]\n\n[test.empty.private]\nflags = ["-std=gnu11"]\nabi = "gnu11"\n\n[test.empty.cases]\n' \
    >>subject/dowel.build
OUT=$(json_diags -C subject check)
RC=0
printf '%s' "$OUT" | jq -e '.code' >/dev/null 2>&1
verdict=$?
_last_cmd="dowel check  # 空の [test.empty.cases]"
known_issue F-040
fact $verdict "a cases block with no case in it is not silently one bare run"
mv subject/dowel.build.keep subject/dowel.build

# ------------------------------------------------------------ 6. 構成ごとの値

# 事例の中の値は分岐できる。ADR-0022 が挙げる例である。
with_cases 'patient = { args = ["plain"], timeout = 30 }' \
           'patient = { args = ["plain"], timeout = match cfg.opt { debug => 30, release => 5 } }'
ok "a value inside a case can branch on the configuration" -C subject check

# 事例そのものは分岐できない（F-041）。
with_cases 'patient = { args = ["plain"], timeout = match cfg.opt { debug => 30, release => 5 } }' \
           'patient = { args = ["plain"] } when cfg.opt == "debug"'
OUT=$("$DOWEL" -C subject check 2>&1)
RC=0
! printf '%s' "$OUT" | grep -q 'type-mismatch'
verdict=$?
_last_cmd="dowel check  # 事例そのものに後置 when"
known_issue F-041
fact $verdict "a case can be registered only for some configurations"

printf '%s' "$OUT" | grep -q 'expected `{ args'
v=$?; RC=0; _last_cmd="dowel check  # 事例そのものに後置 when"
fact $v "and the diagnostic for a conditional case shows the literal form"
restore_cases

# ------------------------------------------------------------ 7. 語彙として見える

# `docs/12-build-reference.md` は、この頁の機械可読形が `schema dump` であり、
# 頁とエディタと診断は黙って食い違えない、と述べている（F-042）。
OUT=$("$DOWEL" schema dump 2>/dev/null)
RC=0
printf '%s' "$OUT" | jq -e 'has("case_properties")' >/dev/null 2>&1
verdict=$?
_last_cmd="dowel schema dump | keys"
OUT=$(printf '%s' "$OUT" | jq -c 'keys')
known_issue F-042
fact $verdict "the schema dump describes the properties a case accepts"

# 兄弟の2つは出ている。抜けているのが `cases` だけであることを見る。
OUT=$("$DOWEL" schema dump 2>/dev/null | jq -c 'keys')
RC=0
printf '%s' "$OUT" | grep -q 'artifact_properties'
v=$?
printf '%s' "$OUT" | grep -q 'inspection_properties'
[ "$v" = 0 ] && [ "$?" = 0 ]
fact $? "the two sibling blocks are described, which is the shape cases should follow"

# ------------------------------------------------------------ 8. 走らせずに知る

# 走るものを走らせずに並べられること（F-043）。事例が時間切れを含む木では、
# 一覧のために全部走らせることになる。
run -C subject test --no-run
said=$OUT
printf '%s' "$said" | grep -q 'suite/plain'
verdict=$?
_last_cmd="dowel test --no-run"; OUT="$said"; RC=0
known_issue F-043
fact $verdict "the cases that would run can be listed without running them"

# グラフにも出ない。事例は翻訳単位を作らないので、アクションの側に無いのは
# 設計どおりである。目標のグラフの側にも無い。
OUT=$("$DOWEL" -C subject graph --kind=target --format=json 2>/dev/null)
RC=0
printf '%s' "$OUT" | jq -e '[.targets[].label] | index("subject:suite/plain")' >/dev/null 2>&1
verdict=$?
_last_cmd="dowel graph --kind=target | 事例が出るか"
OUT=$(printf '%s' "$OUT" | jq -c '[.targets[].label]')
known_issue F-043
fact $verdict "or found in the target graph"

# ------------------------------------------------------------ 9. 機械可読の面

# 流れは分かれている。診断と結果は stdout、進行は stderr（60-cli.md）。
n=$("$DOWEL" -C subject test --message-format=json 2>/dev/null | grep -c '^{')
[ "${n:-0}" -ge 6 ]
v=$?; RC=0; _last_cmd="dowel test --message-format=json | stdout の JSON 行"
OUT="json lines on stdout: ${n:-0}"
fact $v "the machine-readable results go to stdout while the progress goes to stderr"

# 目標と事例を別に名乗ってほしい（F-044）。今は `target` に両方入っている。
OUT=$("$DOWEL" -C subject test --message-format=json 2>/dev/null |
      jq -c 'select(.target | test("plain"))')
RC=0
printf '%s' "$OUT" | jq -e 'has("case")' >/dev/null 2>&1
verdict=$?
_last_cmd="dowel test --message-format=json | plain の行"
known_issue F-044
fact $verdict "the machine-readable result names the target and the case separately"

OUT=$("$DOWEL" -C subject test --message-format=json 2>/dev/null |
      jq -c 'select(.target | test("rejects"))')
RC=0
printf '%s' "$OUT" | jq -e 'has("should_fail")' >/dev/null 2>&1
verdict=$?
_last_cmd="dowel test --message-format=json | rejects の行"
known_issue F-044
fact $verdict "and says whether the case was expected to fail"

# ------------------------------------------------------------ 10. 作業ディレクトリ

# 事例がどこから走るかは、資料を相対パスで開くテストの前提そのものである。
rm -rf "$RUN"; mkdir -p "$RUN"
with_cases 'plain   = { args = ["plain"] }' 'plain   = { args = ["openrun"] }'
ok "a case runs in the root of the package that declares it" -C subject test suite
restore_cases

# ただしそれは文書のどこにも書かれていない。指定する鍵も無い（F-045）。
grep -q 'cwd' subject/dowel.build
verdict=$?
RC=0; _last_cmd="grep cwd subject/dowel.build"
OUT="a case cannot be told where to run; the observed default is the package root"
known_issue F-045
fact $verdict "a case can be given the directory it runs in"
rm -rf "$RUN"
