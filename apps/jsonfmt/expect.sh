# apps/jsonfmt — 依存を持たない実アプリ
#
# `projects/` が dowel の約束を1つずつ固定するのに対し、`apps/` が見るのは
# **それらを組み合わせて本物を書けるか**である。ここは外部依存が1つも無い
# 層であり、C コンパイラだけで完結する。
#
# 形は2パッケージ。
#
#   core/   解析と整形。公開する見出しは include/json/json.h の1枚だけ
#   cli/    引数を解釈して読み書きする。core の内部見出しは見えない
#
# 実アプリとして意味を持たせているもの。
#
#   - 公開と非公開の分離が**本当に使える形**であること（src/ を渡さない）
#   - 機能フラグが依存先へ転送されること（cli の deep → core の deep）
#   - テストがパッケージを跨いで置けること
#   - 走らせて答が合うこと。整形結果は文字単位で見る
#   - **敵対的な入力で落ちないこと**。計装した版を組んで実際に食わせる（8節）

# ------------------------------------------------------------ 道具立て

# jsonfmt [dowel args...] — 組んだ実行ファイルの道。
jsonfmt() {
    find cli/.dowel/build -type f -path "*$1/bin/jsonfmt" 2>/dev/null | head -1
}

# formats <入力> <期待> <desc> [引数...] — 標準入力から読ませて出力を見る。
formats() {
    local in=$1 want=$2 desc=$3; shift 3
    local bin; bin=$(jsonfmt "-debug")
    local got; got=$(printf '%s' "$in" | "${bin:-/nonexistent}" "$@" 2>&1)
    [ "$got" = "$want" ]
    local v=$?
    RC=0; _last_cmd="printf '%s' '$in' | jsonfmt $*"
    OUT="want: ${want//$'\n'/\\n}"$'\n'"got:  ${got//$'\n'/\\n}"
    fact $v "$desc"
}

# ------------------------------------------------------------ 1. 組める

ok "the library package passes check"     -C core check
ok "the application package passes check" -C cli  check
ok "the application builds"               -C cli  build --no-compdb

# 依存を持たない層である。pkg-config も外部の道具も要らない。
_last_cmd="dowel -C cli graph --kind=action | grep -- -l"
OUT=$("$DOWEL" -C cli graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "link") | ([.program] + .arguments) | join(" ")')
RC=0
! printf '%s' "$OUT" | grep -qE '(^| )-l'
fact $? "nothing outside the standard library is linked in"

# ------------------------------------------------------------ 2. 公開と非公開
#
# 使う側が要るのは include/json/json.h の1枚だけである。src/ の内部見出しを
# 渡してしまうと、ライブラリの内側が API になる。

cli_args() {
    "$DOWEL" -C cli graph --kind=action --format=json 2>/dev/null |
        jq -r '.steps[] | select(.kind == "cc" and (.target | test("jsonfmt:")))
               | ([.program] + .arguments) | join(" ")'
}

got=$(cli_args)
_last_cmd="cc_args jsonfmt:jsonfmt"; OUT=$got; RC=0
printf '%s' "$got" | grep -q 'core/include'
fact $? "the public include directory of the library reaches the application"

printf '%s' "$got" | grep -q 'core/src'
verdict=$?
_last_cmd="cc_args jsonfmt:jsonfmt"; OUT=$got; RC=0
[ "$verdict" -ne 0 ]
fact $? "but its private one does not, so the internals stay internal"

# 内部の見出しを直に取り込もうとすると通らない。分離が名目でないことを見る。
cp cli/src/main.c cli/src/main.c.bak
sed -i '1i #include "internal.h"' cli/src/main.c
fails "including a private header of the library does not compile" -C cli build
mv cli/src/main.c.bak cli/src/main.c
ok "and removing it builds again" -C cli build --no-compdb

# ------------------------------------------------------------ 3. 走らせて答が合う
#
# 整形の結果は文字単位で見る。組めたことは、正しいことを意味しない。

formats '{"a":1}' '{
  "a": 1
}' "an object is laid out over lines with two spaces"

formats '{"a":1}' '{"a":1}' "-c lays the same object out on one line" -c
formats '[1,[2]]' '[
  1,
  [
    2
  ]
]' "nesting indents by depth"
formats '  17  ' '17' "surrounding space is dropped"
formats '"a\"b"' '"a\"b"' "an escaped quote inside a string survives"
formats '[]' '[]' "an empty array stays on one line"
formats '{"a":1}' '{
    "a": 1
}' "-i sets the width" -i 4

# 誤った入力は位置つきで拒む。実アプリとして使えるかどうかの分かれ目である。
bin=$(jsonfmt "-debug")
said=$(printf '{"a" 1}' | "${bin:-/nonexistent}" 2>&1); rc=$?
_last_cmd="printf '{\"a\" 1}' | jsonfmt"; OUT="$said"; RC=$rc
[ "$rc" -eq 1 ] && printf '%s' "$said" | grep -q 'syntax error at byte'
fact $? "a syntax error is refused with its byte offset"

# ------------------------------------------------------------ 4. テスト

# 検査はパッケージごとに走る。使う側から `dowel test` を打っても、依存の
# 検査は集められない（F-055 の修正）。それ以前は cli から2件が走っていた。
#
# 依存の検査を走らせるのは依存の作者であり、使う側ではない、という形で
# ある。ここでは両方のパッケージで実際に走ることを、別々に確かめる。
ok "the consumer's own tests run and pass"   -C cli  test
out_has "1 passed" "and only its own are collected" -C cli test

ok "the library's tests run and pass from its own package" -C core test
out_has "jsonfmt-core:parse" "carrying the label of the package that declares them" \
    -C core test

# テストは別パッケージの木に置いてある。実アプリではテストを1か所へ
# まとめることが多く、それが書けるかどうかは形の自由度の問題である。
assert "the test sources live outside the packages that declare them" \
    test -f tests/parse.c

# ------------------------------------------------------------ 5. 機能の転送
#
# cli の `deep` は core の `deep` へ転送される。実アプリでは、上位が下位の
# 構成を選ぶこの形が普通に要る。

ok "building with a forwarded feature passes" -C cli build --no-compdb --features=deep

depth_of() {
    local bin; bin=$(find cli/.dowel/build -type f -path "$1/bin/jsonfmt" | head -1)
    [ -n "$bin" ] && "$bin" --max-depth
}
got=$(depth_of '*-debug')
[ "$got" = 256 ]
v=$?; RC=0; _last_cmd="jsonfmt --max-depth"; OUT="depth = ${got:-(none)}"
fact $v "the default build has the ordinary depth limit"

got=$(depth_of '*deep*')
[ "$got" = 4096 ]
v=$?; RC=0; _last_cmd="jsonfmt --max-depth  # built with --features=deep"
OUT="depth = ${got:-(none)}"
fact $v "a feature forwarded to a dependency reaches it"

# 転送した名前は `<パッケージ>/<機能>` である。その `/` が構成の識別子に
# 入ると、パス区切りとして展開され、1つの構成が2階層になる
# （docs/10-findings.md F-023）。
n=$(find cli/.dowel/build -mindepth 1 -maxdepth 1 -type d | wc -l)
deep_dirs=$(find cli/.dowel/build -mindepth 2 -maxdepth 2 -type d -name deep | wc -l)
[ "$deep_dirs" = 0 ]
verdict=$?
RC=0; _last_cmd="find cli/.dowel/build -mindepth 2 -maxdepth 2 -type d"
OUT="$(find cli/.dowel/build -mindepth 1 -maxdepth 2 -type d | sed 's|.*/build/||' | sort)"
fact $verdict "a forwarded feature does not split the build directory in two"

# ------------------------------------------------------------ 6. 構成

ok "the application builds in release" -C cli build --no-compdb --config=release

# 直前に `test` を挟んでいるため、まず debug を組み直してから測る。
# 挟まないと F-024 の分が乗って、ここが見たい性質と混ざる。
"$DOWEL" -C cli build --no-compdb >/dev/null 2>&1
runs_actions 0 "a second build of the same configuration runs nothing" \
    -C cli --no-compdb

# 実アプリは何度も組み直される。編集して組み直したときに走る量が、
# 木の大きさではなく変更の大きさで決まること。
printf '\n/* touched */\n' >>core/src/sink.c
build_direct -C cli --no-compdb
rebuilt "sink.c" "editing one source recompiles it"
not_rebuilt "scan.c" "and does not recompile its neighbours"

# ------------------------------------------------------------ 7. 呼び出しの形
#
# 開発中は `test` と `build` を交互に打つ。狭い呼び出し（一部の目標だけを
# 計画するもの）が記録を自分の分だけで上書きするため、次に全体を組むと
# 何も編集していないのにやり直しが走る（docs/10-findings.md F-024）。

"$DOWEL" -C cli build --no-compdb >/dev/null 2>&1
"$DOWEL" -C cli test >/dev/null 2>&1
build_direct -C cli --no-compdb
n=$(_ran_actions)
[ "${n:-1}" = 0 ]
verdict=$?
RC=0; _last_cmd="dowel -C cli build; dowel -C cli test; dowel -C cli build"
OUT="ran ${n:-?} actions after running the tests"
fact $verdict "running the tests does not make the next build redo work"

# 逆向きは無害である。広い呼び出しは狭い呼び出しを含む。
"$DOWEL" -C cli build --no-compdb >/dev/null 2>&1
out=$("$DOWEL" -C cli test --backend=direct --log-level=debug 2>&1)
n=$(printf '%s' "$out" | sed -n 's/.*ran \([0-9]*\) steps.*/\1/p' | tail -1)
[ "${n:-1}" = 0 ]
RC=0; _last_cmd="dowel -C cli build; dowel -C cli test"
OUT="ran ${n:-?} actions after a full build"
fact $? "and a full build leaves nothing for the tests to redo"

# 一部の目標だけを指定した場合も同じ形である。
"$DOWEL" -C cli build --no-compdb >/dev/null 2>&1
"$DOWEL" -C cli build --no-compdb jsonfmt >/dev/null 2>&1
build_direct -C cli --no-compdb
n=$(_ran_actions)
[ "${n:-1}" = 0 ]
verdict=$?
RC=0; _last_cmd="dowel -C cli build; dowel -C cli build jsonfmt; dowel -C cli build"
OUT="ran ${n:-?} actions after building one target"
fact $verdict "building one target does not make the next full build redo work"

# ------------------------------------------------------------ 8. 実行時に落ちないこと
#
# 組めたことも、正しい入力で答が合うことも、実アプリの条件としては足りない。
# 利用者が食わせるのは壊れた入力である。ここで見るのは2つある。
#
#   1. **アプリ側** — 敵対的な入力で落ちないか、未定義動作を踏まないか
#   2. **dowel 側** — 計装のような「翻訳とリンクの両方に乗せる必要があり、
#      かつ依存先にも同じものを乗せないと意味が無い」フラグを、
#      マニフェストの語彙だけで書き切れるか
#
# 2 が成り立たなければ 1 は確かめられない。計装は `sanitize` 機能として
# 宣言し、cli から core へ転送する。

ok "the instrumented configuration passes check" -C cli check --features=sanitize
ok "and builds"                                  -C cli build --no-compdb --features=sanitize

# 計装は翻訳だけでは効かない。ライブラリの private な link_flags が、
# それを使う側のリンクにも乗ること（F-018 で入った性質）を実地で使う。
got=$("$DOWEL" -C cli graph --kind=action --format=json --features=sanitize 2>/dev/null |
      jq -r '.steps[] | select(.kind == "link" and (.target | test("jsonfmt:jsonfmt")))
             | ([.program] + .arguments) | join(" ")')
_last_cmd="graph --features=sanitize | select(.kind==\"link\")"; OUT="$got"; RC=0
printf '%s' "$got" | grep -q 'fsanitize'
fact $? "the instrumentation the library asks for reaches the link of the application"

# 計装した版でテストが通る。答が合うことと、その途中で未定義動作を踏んで
# いないことは別の事柄である。
ok "the tests pass with the instrumentation on" -C cli test --features=sanitize

# 敵対的な入力を食わせる。落ちてよいのは「文法の誤り」としてであり、
# シグナルでも計装の報告でもない。
sanbin=$(find cli/.dowel/build -type f -path '*sanitize*/bin/jsonfmt' | head -1)
report=$(JSONFMT="${sanbin:-/nonexistent}" python3 - <<'PY' 2>&1
import os, subprocess
b = os.environ["JSONFMT"]
cases = {
    "an unterminated string":      b'{"a": "xxx',
    "an unterminated object":      b'{"a": 1',
    "an unterminated array":       b'[[[[',
    "a trailing backslash":        b'"\\',
    "empty input":                 b'',
    "a lone quote":                b'"',
    "a key with no value":         b'{"a":}',
    "10k unclosed brackets":       b'[' * 10000,
    "10k closed brackets":         b'[' * 10000 + b']' * 10000,
    "control bytes in a value":    b'{"a":\x01\x02}',
    "a 100k atom":                 b'a' * 100000,
    "an object of 20k members":    b'{' + b','.join(b'"k%d":%d' % (i, i)
                                                   for i in range(20000)) + b'}',
    "bytes that are not UTF-8":    b'{"a":"\xff\xfe"}',
    "50k escape sequences":        b'"' + b'\\n' * 50000,
}
bad = []
for name, data in cases.items():
    p = subprocess.run([b], input=data, capture_output=True)
    why = []
    if p.returncode < 0:
        why.append("killed by signal %d" % -p.returncode)
    elif p.returncode not in (0, 1):
        why.append("exit %d" % p.returncode)
    err = p.stderr
    if b"runtime error" in err or b"Sanitizer" in err:
        why.append(err.decode("utf-8", "replace").strip().splitlines()[0])
    if why:
        bad.append("%s: %s" % (name, "; ".join(why)))
print("\n".join(bad) if bad else "%d inputs, none crashed" % len(cases))
PY
)
printf '%s' "$report" | grep -q 'none crashed'
v=$?
RC=0; _last_cmd="feed 14 hostile inputs to the instrumented jsonfmt"
OUT="$report"
fact $v "hostile input is refused rather than crashing the instrumented build"

# 深い入れ子は再帰の深さそのものである。上限で拒むのであって、
# スタックを溢れさせて落ちるのではない。
ok "the deep configuration builds with the instrumentation too" \
    -C cli build --no-compdb --features=deep,sanitize

deepbin=$(find cli/.dowel/build -type f -path '*deep*sanitize*/bin/jsonfmt' | head -1)
said=$(python3 -c "import sys; sys.stdout.write('['*100000)" |
       "${deepbin:-/nonexistent}" 2>&1 >/dev/null); rc=$?
_last_cmd="printf '[' x100000 | jsonfmt   # --features=deep,sanitize"
OUT="rc: $rc"$'\n'"said: $said"; RC=0
[ "$rc" -eq 1 ] && printf '%s' "$said" | grep -q 'nesting too deep'
fact $? "nesting past the raised limit is refused, not met with a stack overflow"
