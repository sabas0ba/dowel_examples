# 21-debug — 宣言されたデバッガを、宣言されたスタブ越しに起こす
#
# `dowel debug <target>` は組んでから、成果物に対してデバッガを起こす
# （ADR-0024）。デバッガは道具の表の1行（`debug`、既定 gdb）であり、
# トリプルごとに選べる。クロスは runner が「保持する側」（`debug_args`）と
# 「繋ぐ側」（`debug_connect`）を宣言する。
#
# ここで見るのは3つある。
#
#   1. **起動が宣言どおりか。** どのデバッガが、どの成果物に、どの引数で。
#      偽のデバッガを PATH に置いて、渡ってきた argv を記録させる
#   2. **本物が本当に繋がるか。** gdb に标准入力から命令を流し、ブレーク
#      ポイントが実際に効くこと。ホストと、qemu-user のスタブ越しの両方
#   3. **--dap が同じ事実を書き出すか。** エディタが読む構成と実起動が
#      同じ値であること。これが2経路の食い違いを防ぐ設計の要である
#
# 落ちた事例を開き直す `--debug-failed` は、事例の宣言（args / env / cwd）を
# そのまま起動構成へ写す。手で書き写すものが無いことを、写った値で確かめる。

TRIPLE=aarch64-unknown-linux-gnu

# fake_debugger — argv を記録して即座に終わる「デバッガ」。PATH の先頭に
# 置くと、起動の形を対話なしで観測できる。18-tools と同じ手口である。
FAKE=$PWD/.fake-bin
fake_debugger() {
    mkdir -p "$FAKE"
    cat >"$FAKE/faked" <<'SH'
#!/bin/sh
printf '%s\n' "$@" >"${FAKE_LOG:?}"
exit 0
SH
    chmod +x "$FAKE/faked"
}

# gdb_says <期待の正規表現> <desc> <gdb への命令...> — 本物の gdb に命令を
# 流し、出力に期待が現れることを見る。
gdb_says() {
    local want=$1 desc=$2; shift 2
    local cmds="" c
    for c in "$@"; do cmds="$cmds$c\n"; done
    OUT=$(printf "$cmds" | timeout 60 "$DOWEL" -C subject debug app ${EXTRA:-} 2>&1)
    RC=$?
    _last_cmd="printf '...' | dowel debug app ${EXTRA:-}   # gdb へ ${*}"
    printf '%s' "$OUT" | grep -qE "$want"
    fact $? "$desc"
}

# dap [args...] — 起動構成を読む。
dap() {
    "$DOWEL" -C subject debug "$@" --dap 2>/dev/null
}

# ------------------------------------------------------------ 1. 組めて、開ける

ok "the package passes check" -C subject check

# デバッガは道具の表にある。語彙・既定・宣言の3点。
got=$("$DOWEL" schema dump 2>/dev/null |
      jq -r '.tools[] | select(.name == "debug") | .default')
[ "$got" = "gdb" ]
v=$?; RC=0; _last_cmd="schema dump | .tools[] | select(.name==\"debug\")"
OUT="default: ${got:-(absent)}"
fact $v "the debugger is a toolchain tool with gdb as its default"

# ライブラリは開けない。始めるものが無い。
diag not-debuggable "a library cannot be debugged, because there is nothing to start" \
    -C subject debug quiet

# ------------------------------------------------------------ 2. 起動の形（偽のデバッガで観測）
#
# 対話する道具の起動は、対話せずに確かめる。argv を記録するだけの偽の
# デバッガを宣言し、dowel が何をどう起こしたかを記録から読む。

fake_debugger
cp subject/dowel.toml subject/dowel.toml.keep
cat >>subject/dowel.toml <<'EOF'

[toolchain]
debug = "faked"
EOF

FAKE_LOG=$PWD/.fake.log
export FAKE_LOG
rm -f "$FAKE_LOG"
PATH="$FAKE:$PATH" "$DOWEL" -C subject debug app >/dev/null 2>&1
rc=$?
_last_cmd="PATH に偽の gdb を置いて dowel debug app"
OUT="rc: $rc"$'\n'"argv: $(tr '\n' ' ' <"$FAKE_LOG" 2>/dev/null)"
RC=0
[ "$rc" -eq 0 ] && [ -s "$FAKE_LOG" ]
fact $? "dowel builds the target and starts the declared debugger"

grep -q 'bin/app$' "$FAKE_LOG"
v=$?; RC=0; _last_cmd="偽のデバッガが記録した argv"
OUT="$(cat "$FAKE_LOG" 2>/dev/null)"
fact $v "and hands it the artifact it just built"

# 実在しないデバッガは、起動のときに missing-toolchain で断られる。
# 道具の表の規則どおり、debug しない木は gdb を要らない。
sed -i 's/debug = "faked"/debug = "no-such-debugger-19"/' subject/dowel.toml
diag missing-toolchain "a debugger that is not on PATH is refused when debugging" \
    -C subject debug app
ok "while an ordinary build never asks for it" -C subject build --no-compdb
mv subject/dowel.toml.keep subject/dowel.toml

# ------------------------------------------------------------ 3. 本物の gdb で止める
#
# 起動の形が正しくても、繋がるかどうかは別である。ブレークポイントが
# 実際に効き、止まった位置が読めることまで見る。

EXTRA=""
gdb_says 'Breakpoint 1, add \(a=2, b=2\)' \
    "a breakpoint set through dowel stops the program where the source says" \
    "break add" "run" "quit" "y"

gdb_says '= 4' \
    "and the debugger can evaluate expressions in the stopped program" \
    "break add" "run" "print a + b" "quit" "y"

# ------------------------------------------------------------ 4. クロス（スタブ越し）
#
# エミュレータ越しのデバッグは2プロセスである。qemu-user が `-g` で保持し、
# トリプルの宣言した gdb-multiarch が繋ぐ。組んだ像は aarch64 であり、
# ホストの gdb では読めない。

EXTRA="--target=$TRIPLE"
gdb_says 'Remote debugging using localhost:17233' \
    "a cross debug session attaches to the declared stub address" \
    "break add" "continue" "kill" "quit" "y"

gdb_says 'Breakpoint 1, add \(a=2, b=2\)' \
    "and stops the foreign binary at the same source line" \
    "break add" "continue" "kill" "quit" "y"
EXTRA=""

# スタブは残らない。繋ぐ側が終われば、保持する側も終わる。
n=$(pgrep -c qemu-aarch64 2>/dev/null || true)
[ "${n:-0}" = 0 ]
v=$?; RC=0; _last_cmd="pgrep -c qemu-aarch64   # デバッグの後"
OUT="stub processes left: ${n:-0}"
fact $v "the stub is killed when the debugger exits"

# 宣言の無いクロスは断られる。ホストの gdb を他所の像に向けるより良い。
cp subject/dowel.build subject/dowel.build.keep
python3 - <<'PY'
p = "subject/dowel.build"
t = open(p, encoding="utf-8").read()
t = t.replace('debug_args    = ["-g", "17233"]\n', "")
t = t.replace('debug_connect = "localhost:17233"\n', "")
open(p, "w", encoding="utf-8").write(t)
PY
diag missing-debug-stub "a cross target whose runner declares no stub is refused" \
    -C subject debug app --target=$TRIPLE

# 半分だけ宣言した場合、欠けている側を指してほしい（F-048）。
python3 - <<'PY'
p = "subject/dowel.build"
t = open(p, encoding="utf-8").read()
t = t.replace('args          = ["-L", "/usr/aarch64-linux-gnu"]',
              'args          = ["-L", "/usr/aarch64-linux-gnu"]\ndebug_args    = ["-g", "17233"]')
open(p, "w", encoding="utf-8").write(t)
PY
run -C subject debug app --target=$TRIPLE
said=$OUT
_last_cmd="dowel debug --target=...  # debug_args だけ宣言した"
OUT="$said"; RC=0
! printf '%s' "$said" | grep -q 'declares no stub'
verdict=$?
known_issue F-048
fact $verdict "a half-declared stub is told which half is missing"
mv subject/dowel.build.keep subject/dowel.build

# ------------------------------------------------------------ 5. --dap は同じ事実を書き出す
#
# エディタが読む構成と実起動が同じ値から出ること。2経路の食い違いを
# 防ぐのがこの設計の要である（ADR-0024）。

launch=$(dap app)
_last_cmd="dowel debug app --dap"; OUT="$launch"; RC=0
printf '%s' "$launch" | jq -e '.request == "launch" and .MIMode == "gdb"' >/dev/null 2>&1
fact $? "--dap writes a launch configuration instead of starting anything"

got=$(printf '%s' "$launch" | jq -r '.program')
case $got in */bin/app) v=0 ;; *) v=1 ;; esac
RC=0; _last_cmd="dap | .program"; OUT="program: ${got:-(none)}"
fact $v "naming the artifact the session would have opened"

got=$(printf '%s' "$launch" | jq -r '.cwd')
[ "$got" = "$PWD/subject" ]
v=$?; RC=0; _last_cmd="dap | .cwd"
OUT="cwd: ${got:-(none)}  (want: パッケージ根)"
fact $v "with the package root as the working directory, the same as dowel test"

launch=$(dap app --target=$TRIPLE)
_last_cmd="dowel debug app --target=... --dap"; OUT="$launch"; RC=0
printf '%s' "$launch" | jq -e '.miDebuggerServerAddress == "localhost:17233"' >/dev/null 2>&1
fact $? "a cross launch carries the declared attach address"

got=$(printf '%s' "$launch" | jq -r '.miDebuggerPath')
[ "$got" = "gdb-multiarch" ]
v=$?; RC=0; _last_cmd="dap --target=... | .miDebuggerPath"
OUT="debugger: ${got:-(none)}"
fact $v "and the debugger the triple declared, not the host's"

printf '%s' "$launch" | jq -e '.debugServerArgs | index("-g")' >/dev/null 2>&1
v=$?; RC=0; _last_cmd="dap --target=... | .debugServerArgs"
OUT=$(printf '%s' "$launch" | jq -c '.debugServerArgs')
fact $v "and the stub command that hosts the program behind it"

# ------------------------------------------------------------ 6. 落ちた事例を開き直す
#
# `--debug-failed` は失敗の記録から事例を選び、その宣言——引数・環境変数・
# 作業ディレクトリ——をそのまま起動構成にする。手で書き写すものは無い。

"$DOWEL" -C subject test >/dev/null 2>&1        # sad が落ちて記録される

launch=$("$DOWEL" -C subject test --debug-failed --dap 2>/dev/null)
_last_cmd="dowel test --debug-failed --dap"; OUT="$launch"; RC=0
printf '%s' "$launch" | jq -e '.args == ["sad"]' >/dev/null 2>&1
fact $? "the failing case's arguments become the launch arguments"

printf '%s' "$launch" | jq -e '.environment[] | select(.name == "WHY" and .value == "declared")' >/dev/null 2>&1
v=$?; RC=0; _last_cmd="dowel test --debug-failed --dap | .environment"
OUT=$(printf '%s' "$launch" | jq -c '.environment')
fact $v "and its environment"

got=$(printf '%s' "$launch" | jq -r '.cwd')
case $got in */subject/tests) v=0 ;; *) v=1 ;; esac
RC=0; _last_cmd="dowel test --debug-failed --dap | .cwd"
OUT="cwd: ${got:-(none)}"
fact $v "and the directory the case declared it runs in"

# 何も落ちていなければ、それは成功であり、そう述べる。sad を一時的に
# 「失敗を期待する」側へ倒し、全件通る記録を作ってから尋ねる。
cp subject/dowel.build subject/dowel.build.keep
python3 - <<'PY'
p = "subject/dowel.build"
t = open(p, encoding="utf-8").read()
t = t.replace('sad  = { args = ["sad"], env = { WHY = "declared" }, cwd = dir("tests") }',
              'sad  = { args = ["sad"], env = { WHY = "declared" }, cwd = dir("tests"), should_fail = true }')
open(p, "w", encoding="utf-8").write(t)
PY
"$DOWEL" -C subject test >/dev/null 2>&1        # 全件通る
run -C subject test --debug-failed
said=$OUT
[ "$RC" -eq 0 ] && printf '%s' "$said" | grep -q 'nothing to debug'
v=$?
_last_cmd="dowel test --debug-failed  # 何も落ちていない"
OUT="rc: $RC"$'\n'"$said"; RC=0
fact $v "when nothing failed there is nothing to debug, and that is a success"
mv subject/dowel.build.keep subject/dowel.build

# 複数落ちているときは選ばせる。どれが開いたのかを利用者に推測させない。
cp subject/dowel.build subject/dowel.build.keep
python3 - <<'PY'
p = "subject/dowel.build"
t = open(p, encoding="utf-8").read()
t = t.replace('calm = { args = ["calm"] }',
              'calm = { args = ["sad", "calm-flavour"] }')
open(p, "w", encoding="utf-8").write(t)
PY
"$DOWEL" -C subject test >/dev/null 2>&1        # calm も sad も落ちる
run -C subject test --debug-failed
said=$OUT
[ "$RC" -ne 0 ]
v=$?
_last_cmd="dowel test --debug-failed  # 2件落ちている"
OUT="$said"; RC=0
fact $v "two recorded failures refuse to guess which one to open"

printf '%s' "$said" | grep -q 'name one'
fact $? "and ask to name one, listing the candidates"

launch=$("$DOWEL" -C subject test subject:t/calm --debug-failed --dap 2>/dev/null)
_last_cmd="dowel test subject:t/calm --debug-failed --dap"; OUT="$launch"; RC=0
printf '%s' "$launch" | jq -e '.args == ["sad", "calm-flavour"]' >/dev/null 2>&1
fact $? "naming a case narrows the choice to it"
mv subject/dowel.build.keep subject/dowel.build
"$DOWEL" -C subject test >/dev/null 2>&1        # 記録を現在の宣言で作り直す

# 落ちていない事例は開けない。宣言を写す機構はあるのに、失敗の記録を
# 経由する道しか無い（F-049）。
run -C subject debug subject:t/calm
said=$OUT
[ "$RC" -eq 0 ]
verdict=$?
_last_cmd="dowel debug subject:t/calm  # 落ちていない事例"
OUT="$said"; RC=0
known_issue F-049
fact $verdict "a case that has not failed can be opened under the debugger"

rm -rf "$FAKE" "$FAKE_LOG"
