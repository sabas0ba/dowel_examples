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
want="subject:suite/plain subject:suite/slow subject:suite/rejects subject:suite/strict subject:suite/patient subject:lone subject:disc/alpha subject:disc/beta subject:disc/gamma"
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
[ "$n" = 3 ]
v=$?; RC=0; _last_cmd="graph --kind=action | link の出力"
OUT="linked binaries: ${n:-?} (suite / lone / disc の3本。事例は8件ある)"
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

# 同じ理屈がシグナルにも効く（F-032 / #88 で入った）。
with_cases 'patient = { args = ["hang"], timeout = 2, should_fail = true }' \
           'patient = { args = ["crash"], should_fail = true }'
case_status
said=$CASE_SAID
[ "$RC" -ne 0 ]
v=$?
_last_cmd="dowel test  # should_fail の事例が SIGSEGV で死ぬ"; OUT="$said"; RC=0
fact $v "a case killed by a signal does not satisfy should_fail"

printf '%s' "$said" | grep -q 'killed by signal'
fact $? "and the failure names the signal, not a bare status"

OUT=$("$DOWEL" -C subject test --message-format=json 2>/dev/null |
      jq -c 'select(.case == "patient")')
RC=0
printf '%s' "$OUT" | jq -e '.signal == 11' >/dev/null 2>&1
v=$?
_last_cmd="dowel test --message-format=json | case == patient"
fact $v "and the report distinguishes a crash from a nonzero exit"
restore_cases

# 0 以下の timeout は宣言として意味を成さない（F-033）。
with_cases 'patient = { args = ["plain"], timeout = 30 }' \
           'patient = { args = ["plain"], timeout = 0 }'
diag invalid-value "a timeout of zero or less is refused" -C subject check
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
v=$?
_last_cmd="dowel test --label nosuch; echo \$?"
OUT="rc: $RC"$'\n'"$said"; RC=0
fact $v "naming a label nobody carries does not pass with zero tests"

printf '%s' "$said" | grep -q 'no test carries'
fact $? "and it does say which label found nothing"

printf '%s' "$said" | grep -q -- '--no-run'
fact $? "and points at the listing that shows the labels that do exist"

# 印字された名前をコマンドラインに渡し返せること（F-035）。
run -C subject test 'subject:suite/plain'
said=$OUT
[ "$RC" -eq 0 ] && [ "$(printf '%s' "$said" | grep -c '^test subject:')" = 1 ]
v=$?
_last_cmd="dowel test subject:suite/plain"; OUT="$said"; RC=0
fact $v "the label a case is reported under selects that case on the command line"

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
v=$?
_last_cmd="覚えている事例を改名して dowel test --failed"
OUT="rc: $RC"$'\n'"$said"; RC=0
fact $v "rerunning failures says so when the remembered case is gone"
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

# 誤っている値を指すこと（F-037 / #101 で入った）。下線は誤った値だけに引かれる。
with_cases 'strict  = { args = ["env"], env = { SUITE_MODE = "strict" } }' \
           'strict  = { args = ["env"], timeout = "x", env = { SUITE_MODE = "strict" } }'
OUT=$("$DOWEL" -C subject check 2>&1)
RC=0
_last_cmd="dowel check  # 長い事例の1つの鍵だけが誤り"
carets=$(printf '%s' "$OUT" | sed -n 's/^ *| *\(\^\^*\).*$/\1/p' | head -1)
[ -n "$carets" ] && [ "${#carets}" -lt 10 ]
v=$?
OUT="$OUT"$'\n'"underlined: ${#carets} characters"
fact $v "a type error inside a case points at the key that is wrong"
restore_cases

# 事例の名前はラベルの一部になる。文法を壊す名前は拒みたい（F-038）。
with_cases 'plain   = { args = ["plain"] }' '"a/b"   = { args = ["plain"] }'
diag invalid-name "a case name that breaks the label grammar is refused" \
    -C subject check
run -C subject check
said=$OUT
_last_cmd="dowel check  # 事例の名前が a/b"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'separates the target from the case'
fact $? "and the diagnostic says why the grammar owns that character"
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
printf '%s' "$said" | grep -q 'inline tables inside it'
fact $? "writing a case as a table header says how to write it as an entry"
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
diag empty-block "a cases block with no case in it is not silently one bare run" \
    -C subject check
mv subject/dowel.build.keep subject/dowel.build

# ------------------------------------------------------------ 6. 構成ごとの値

# 事例の中の値は分岐できる。ADR-0022 が挙げる例である。
with_cases 'patient = { args = ["plain"], timeout = 30 }' \
           'patient = { args = ["plain"], timeout = match cfg.opt { debug => 30, release => 5 } }'
ok "a value inside a case can branch on the configuration" -C subject check

# 事例そのものも分岐できる（F-041 / #92 で入った）。構成に無い事例は
# 登録されず、走らない。
with_cases 'patient = { args = ["plain"], timeout = match cfg.opt { debug => 30, release => 5 } }' \
           'patient = { args = ["plain"] } when cfg.opt == "debug"'
ok "a case can be registered only for some configurations" -C subject check

n=$(ran | grep -c 'suite/')
[ "$n" = 5 ]
v=$?; RC=0; _last_cmd="dowel test  # patient は debug でだけ登録される"
OUT="cases run in debug: ${n:-?}"
fact $v "the case exists in the configuration its condition names"

n=$("$DOWEL" -C subject test --no-run --config=release 2>&1 | grep -c '^subject:suite/')
[ "$n" = 4 ]
v=$?; RC=0; _last_cmd="dowel test --no-run --config=release"
OUT="cases listed in release: ${n:-?}"
fact $v "and is absent from the one it does not"
restore_cases

# ------------------------------------------------------------ 7. 語彙として見える

# `docs/12-build-reference.md` は、この頁の機械可読形が `schema dump` であり、
# 頁とエディタと診断は黙って食い違えない、と述べている（F-042）。
keys=$("$DOWEL" schema dump 2>/dev/null | jq -c 'keys')
OUT="$keys"; RC=0; _last_cmd="dowel schema dump | keys"
printf '%s' "$keys" | grep -q 'case_properties'
fact $? "the schema dump describes the properties a case accepts"

printf '%s' "$keys" | grep -q 'runner_properties'
v=$?; OUT="$keys"; RC=0; _last_cmd="dowel schema dump | keys"
fact $v "and the runner's, which was the other block missing from it"

got=$("$DOWEL" schema dump 2>/dev/null |
      jq -r '.case_properties[].name' | sort | paste -sd' ' -)
[ "$got" = "args cwd env labels should_fail timeout" ]
v=$?; RC=0; _last_cmd="schema dump | .case_properties[].name"
OUT="described: ${got:-(none)}"
fact $v "and the case keys it lists are exactly the ones the type checker accepts"

# ------------------------------------------------------------ 8. 走らせずに知る

# 走るものを走らせずに並べられること（F-043）。事例が時間切れを含む木では、
# 一覧のために全部走らせることになる。
run -C subject test --no-run
said=$OUT
printf '%s' "$said" | grep -q 'suite/plain'
v=$?
_last_cmd="dowel test --no-run"; OUT="$said"; RC=0
fact $v "the cases that would run can be listed without running them"

printf '%s' "$said" | grep -q 'should_fail'
fact $? "with the properties that change how a case is judged"

got=$("$DOWEL" -C subject test --no-run --label slow 2>&1 | grep -c 'suite/')
[ "$got" = 1 ]
v=$?; RC=0; _last_cmd="dowel test --no-run --label slow"
OUT="listed: ${got:-?}"
fact $v "and the listing honours the selection that was asked for"

# ------------------------------------------------------------ 9. 機械可読の面

# 流れは分かれている。診断と結果は stdout、進行は stderr（60-cli.md）。
n=$("$DOWEL" -C subject test --message-format=json 2>/dev/null | grep -c '^{')
[ "${n:-0}" -ge 6 ]
v=$?; RC=0; _last_cmd="dowel test --message-format=json | stdout の JSON 行"
OUT="json lines on stdout: ${n:-0}"
fact $v "the machine-readable results go to stdout while the progress goes to stderr"

# 目標と事例は別の欄で名乗る（F-044 / #100 で入った）。
OUT=$("$DOWEL" -C subject test --message-format=json 2>/dev/null |
      jq -c 'select(.case == "plain")')
RC=0
printf '%s' "$OUT" | jq -e '.target == "subject:suite"' >/dev/null 2>&1
v=$?
_last_cmd="dowel test --message-format=json | case == plain"
fact $v "the machine-readable result names the target and the case separately"

OUT=$("$DOWEL" -C subject test --message-format=json 2>/dev/null |
      jq -c 'select(.case == "rejects")')
RC=0
printf '%s' "$OUT" | jq -e '.should_fail == true and .exit_status == 3' >/dev/null 2>&1
v=$?
_last_cmd="dowel test --message-format=json | case == rejects"
fact $v "and says whether the case was expected to fail"

# ------------------------------------------------------------ 10. 作業ディレクトリ

# 事例がどこから走るかは、資料を相対パスで開くテストの前提そのものである。
rm -rf "$RUN"; mkdir -p "$RUN"
with_cases 'plain   = { args = ["plain"] }' 'plain   = { args = ["openrun"] }'
ok "a case runs in the root of the package that declares it" -C subject test suite
restore_cases

# 指定もできる（F-045 / #95 で入った）。`cwd` は Path を受ける。
with_cases 'plain   = { args = ["plain"] }' \
           'plain   = { args = ["plain"], cwd = dir("tests") }'
out=$("$DOWEL" -C subject test subject:suite/plain --nocapture 2>&1 | sed -n 's/^cwd=//p')
case $out in */tests) v=0 ;; *) v=1 ;; esac
RC=0; _last_cmd="dowel test  # cwd = dir(\"tests\")"
OUT="ran in: ${out:-(unknown)}"
fact $v "a case can be given the directory it runs in"
restore_cases
rm -rf "$RUN"

# ------------------------------------------------------------ 11. 事例をコードの側に持つ (ADR-0023)
#
# suite の事例はコードにある。マニフェストへ書き写すと2つの一覧が漂流し、
# 漂流は効く方向に黙って出る——ソースに足した事例が走らず、誰も何も
# 言わない。`[test.<name>.harness]` は列挙の規約を宣言する。dowel は
# 枠組みを1つも知らない。

got=$(ran disc | tr '\n' ' ' | sed 's/ *$//')
[ "$got" = "subject:disc/alpha subject:disc/beta subject:disc/gamma" ]
v=$?; RC=0; _last_cmd="dowel test disc"
OUT="discovered and ran: ${got:-(none)}"
fact $v "the binary lists its own cases and each runs as its own test"

# 空行と # 始まりは読み飛ばされる。それ以上の解釈は無い。
n=$(ran disc | grep -c 'disc/')
[ "$n" = 3 ]
v=$?; RC=0; _last_cmd="dowel test disc  # 列挙には注釈と空行が混ざっている"
OUT="cases: ${n:-?} (listing prints 5 lines; 2 are skipped)"
fact $v "blank lines and comment lines in the listing are skipped"

# 発見された事例もラベルを持ち、選べる。
got=$(ran --label discovered | grep -c 'disc/')
[ "$got" = 3 ]
v=$?; RC=0; _last_cmd="dowel test --label discovered"
OUT="selected: ${got:-?}"
fact $v "a label declared on the harness reaches every discovered case"

# 両方は書けない。どちらも「事例は何か」に答えるためである。
cp subject/dowel.build subject/dowel.build.keep
printf '\n[test.disc.cases]\nx = { args = ["--run", "alpha"] }\n' >>subject/dowel.build
diag conflicting-declaration "cases and harness cannot both be declared" \
    -C subject check
mv subject/dowel.build.keep subject/dowel.build

# 列挙に失敗した目標は、0件ではなく失敗である。列挙できないことと
# 走るものが無いことは別であり、黙った0件はスイートが消える形である。
cp subject/tests/harness.c subject/tests/harness.c.keep
python3 - <<'PATCH'
p = "subject/tests/harness.c"
t = open(p, encoding="utf-8").read()
t = t.replace('        puts("gamma");\n        return 0;',
              '        puts("gamma");\n        return 3;')
open(p, "w", encoding="utf-8").write(t)
PATCH
case_status disc
said=$CASE_SAID
[ "$RC" -ne 0 ] && printf '%s' "$said" | grep -q 'could not list the cases'
v=$?
_last_cmd="dowel test disc  # 列挙が状態3で終わる"
OUT="$said"; RC=0
fact $v "a listing that fails is a failure of the target, not zero tests"

# 固まる列挙も同じである。harness の timeout が列挙自身にも効く。
python3 - <<'PATCH'
p = "subject/tests/harness.c"
t = open(p, encoding="utf-8").read()
t = t.replace('strcmp(argv[1], "--list") == 0) {',
              'strcmp(argv[1], "--list") == 0) { for (;;) { }')
open(p, "w", encoding="utf-8").write(t)
PATCH
cp subject/dowel.build subject/dowel.build.keep
python3 - <<'PATCH'
p = "subject/dowel.build"
t = open(p, encoding="utf-8").read()
t = t.replace('timeout = 10', 'timeout = 2')
open(p, "w", encoding="utf-8").write(t)
PATCH
case_status disc
said=$CASE_SAID
[ "$RC" -ne 0 ] && printf '%s' "$said" | grep -q 'timed out'
v=$?
_last_cmd="dowel test disc  # 列挙が固まる。harness の timeout = 2"
OUT="$said"; RC=0
fact $v "and a listing that hangs is killed by the harness timeout"
mv subject/dowel.build.keep subject/dowel.build
cp subject/tests/harness.c.keep subject/tests/harness.c

# 列挙が返す名前は選べない。既存の枠組みの出力には空白も `/` も普通に
# 混ざるが、いまは素通りしてラベルの文法を壊す（F-047）。マニフェスト側の
# 同じ名前は invalid-name で拒まれる——規則が片方の入口にしか無い。
python3 - <<'PATCH'
p = "subject/tests/harness.c"
t = open(p, encoding="utf-8").read()
t = t.replace('        puts("beta");', '        puts("a/b");')
open(p, "w", encoding="utf-8").write(t)
PATCH
case_status disc
said=$CASE_SAID
! printf '%s' "$said" | grep -q 'disc/a/b'
verdict=$?
_last_cmd="dowel test disc  # 列挙が a/b という名前を返す"
OUT="$said"; RC=0
known_issue F-047
fact $verdict "a discovered name that breaks the label grammar is not silently accepted"
cp subject/tests/harness.c.keep subject/tests/harness.c
rm -f subject/tests/harness.c.keep

# 発見された事例の宣言は、失敗の記録からデバッガへも届く（21-debug が
# 起動の側を見る）。ここでは記録の形だけを確かめる。
"$DOWEL" -C subject test disc >/dev/null 2>&1
OUT=$("$DOWEL" -C subject test disc --message-format=json 2>/dev/null |
      jq -c 'select(.case == "gamma")')
RC=0
printf '%s' "$OUT" | jq -e '.target == "subject:disc"' >/dev/null 2>&1
fact $? "a discovered case reports under the same label grammar as a declared one"
