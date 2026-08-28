# 28-progress — 同時に走らせ、走っている間に見せる（ADR-0056 / ADR-0057）
#
# `dowel build` は `-j, --jobs <n>` を取り、「backend へ渡す並列度」と
# 書かれていた。ninja と make は渡していた。direct はそれを受け取って
# **床に落としていた**。
#
# その backend は珍しい経路ではない。ninja が PATH に無ければ `backend::select`
# が必ずそこへ落ちる（ADR-0018）——`dowelup install` の直後の機械がまさに
# その状態であり、最初のビルドに toolchain の組み立てを要らなくするのが
# dowel の主張である（ADR-0036）。その機械へ単線のビルドを渡していた。
#
# そして同じ機械には、**何も出ていなかった**。direct は段ごとの告知を
# `log_info!` で出しており、既定の log level は warn なので誰にも届かない。
# 大きさのあるビルドでは、`dowel build` は停止と区別が付かなかった。
#
# ここで見るのは2つである。
#
#   1. 本当に同時に走ること。**時間ではなく段自身に観測させる**——各段は
#      走っている間だけ印を置き、その時点で見えた印の数を記録する。逐次
#      なら1、並列なら2以上。壁時計の閾値は負荷の高い機械で falsely 落ちる
#   2. 走っている間に出ること。3つの backend で1段1行、stderr へ、
#      log level を通さずに

bdir() { find .dowel/build -mindepth 1 -maxdepth 1 -type d | head -1; }

RUN=$PWD/run

# observed <dowel args...> — 空から組み、段が観測した同時数の最大を置く。
#
#   SEEN  同時に見えた数の最大（逐次なら 1）
#   SAID  出力
#
# 値を返さず変数へ置くのは、`n=$(observed)` と書くと部分シェルで走り、
# 中で設定した変数が呼び出し側に残らないためである。
SEEN=""; SAID=""
observed() {
    rm -rf .dowel
    rm -f "$RUN"/*.running "$RUN"/*.seen
    OUT=$("$DOWEL" build --no-compdb "$@" 2>&1)
    RC=$?
    SAID=$OUT
    _last_cmd="dowel build $*"
    SEEN=$(cat "$RUN"/*.seen 2>/dev/null | sort -n | tail -1)
}

# stamped <dowel args...> — 進行の行だけを、届いた時刻つきで。
# 「まとめて最後に」と「走りながら」を分けられるのはこれだけである。
stamped() {
    rm -rf .dowel
    rm -f "$RUN"/*.running "$RUN"/*.seen
    "$DOWEL" build --no-compdb "$@" 2>&1 >/dev/null |
        while IFS= read -r line; do printf '%s %s\n' "$(now_ms)" "$line"; done
}

# --------------------------------------------------------------- 1. 逐次が観測できること

observed --backend=direct --jobs 1
[ "$RC" -eq 0 ] && [ "$SEEN" = 1 ]
_verdict $? "--jobs 1 runs the steps one at a time"
prints "4" "and what it built runs" "$(bdir)/bin/app"

# --------------------------------------------------------------- 2. 並列

observed --backend=direct --jobs 4
[ "$RC" -eq 0 ] && [ "${SEEN:-0}" -ge 2 ]
_verdict $? "--jobs 4 really runs steps at the same time under direct"

# 既定は機械の並列度である。1本しか走らないなら、`dowelup install` 直後の
# 機械は単線のままである——それがこの決定の動機だった。
observed --backend=direct
[ "$RC" -eq 0 ] && [ "${SEEN:-0}" -ge 2 ]
_verdict $? "and the default is the machine's parallelism, not one"

# 他の2つも同じである。同じグラフを受け取る以上、走らせ方が backend で
# 変わっても、走ることは変わらない。
for b in ninja make; do
    observed --backend=$b --jobs 4
    [ "$RC" -eq 0 ] && [ "${SEEN:-0}" -ge 2 ]
    _verdict $? "--jobs 4 runs steps at the same time under $b too"
done

# --------------------------------------------------------------- 3. 同時でも同じものを組む
#
# 順序が片方の綴りにしか現れていなければ、それは競合である。逐次なら
# どちらか一方で足りていた——`deps` で整列しても、file の関係は結果として
# 満たされていた。同時に走らせるとそうはならない。
#
# 競合は1度で出るとは限らないので、繰り返して見る。

bad=0
for i in 1 2 3 4 5; do
    rm -rf .dowel
    rm -f "$RUN"/*.running "$RUN"/*.seen
    "$DOWEL" build --no-compdb --backend=direct --jobs 8 >/dev/null 2>&1 || bad=$((bad + 1))
    [ "$("$(bdir)/bin/app" 2>/dev/null)" = 4 ] || bad=$((bad + 1))
done
_last_cmd="dowel build --backend=direct --jobs 8   # 空から5回"
OUT="$bad failures across 5 clean builds"; RC=0
[ "$bad" -eq 0 ]
fact $? "a clean concurrent build produces the same program every time"

# 3つの backend が同じ答を出す（ADR-0018）。
for b in ninja make direct; do
    rm -rf .dowel
    rm -f "$RUN"/*.running "$RUN"/*.seen
    "$DOWEL" build --no-compdb --backend=$b --jobs 4 >/dev/null 2>&1
    prints "4" "and $b builds the same program with steps running at once" \
           "$(bdir)/bin/app"
done

# --------------------------------------------------------------- 4. 進行は出力であって log ではない（ADR-0057）

# stdout ではない。`dowel graph --format=dot | dot` が通ることが、
# この分け方の約束である。
rm -rf .dowel
rm -f "$RUN"/*.running "$RUN"/*.seen
_last_cmd="dowel build --backend=direct 2>/dev/null   # stdout だけ"
OUT=$("$DOWEL" build --no-compdb --backend=direct 2>/dev/null); RC=0
! printf '%s' "$OUT" | grep -q '^\['
fact $? "progress does not go to stdout, which stays for what the command returns"

# log level を通さない。`--log-level=off` だけが黙らせる——利用者が持って
# いる沈黙の摘みはそれ1つだからである。
rm -rf .dowel
rm -f "$RUN"/*.running "$RUN"/*.seen
_last_cmd="dowel build --backend=direct --log-level=off"
OUT=$("$DOWEL" build --no-compdb --backend=direct --log-level=off 2>&1); RC=0
! printf '%s' "$OUT" | grep -q 'GEN \|CC \|LINK '
fact $? "--log-level=off silences it, being the only knob for silence"

# 既定（warn）で出る。かつては `log_info!` だったので、ここに何も無かった。
for b in ninja make direct; do
    rm -rf .dowel
    rm -f "$RUN"/*.running "$RUN"/*.seen
    _last_cmd="dowel build --backend=$b   # stderr だけ"
    OUT=$("$DOWEL" build --no-compdb --backend=$b 2>&1 >/dev/null); RC=0
    n=$(printf '%s\n' "$OUT" | grep -c 'GEN \|CC \|LINK ')
    [ "$n" -eq 10 ]
    fact $? "$b prints one line per step at the default log level ($n of 10)"
done

# 記述は最後に来る。3つで揃っているのはこの形である。
rm -rf .dowel
rm -f "$RUN"/*.running "$RUN"/*.seen
LINES=$("$DOWEL" build --no-compdb --backend=direct 2>&1 >/dev/null | grep '^\[')
_last_cmd="dowel build --backend=direct   # 進行の行"
OUT=$LINES; RC=0
printf '%s\n' "$LINES" | grep -q '^\[10/10\] LINK bin/app$'
fact $? "direct counts the steps it ran out of the steps in the graph"

# 番号は終わった順に、記録するのと同じ錠の下で振られる。だから番号は
# 順に届き、並んだ行と食い違わない。
_last_cmd="dowel build --backend=direct   # 進行の行の番号"
OUT=$(printf '%s\n' "$LINES" | sed -n 's/^\[\([0-9]*\)\/10\].*/\1/p' | paste -sd' ' -)
RC=0
[ "$OUT" = "1 2 3 4 5 6 7 8 9 10" ]
fact $? "and the numbers arrive in order, matching the lines"

# 増分では m まで行かない。m はビルドの大きさであって、どれだけ組み直すかの
# 予報ではない——後者を出すには走らせる前に鮮度を決めることになる。
touch src/main.c
_last_cmd="dowel build --backend=direct   # 1つだけ触ったあと"
OUT=$("$DOWEL" build --no-compdb --backend=direct 2>&1 >/dev/null | grep -c '^\[')
RC=0
[ "$OUT" -lt 10 ] && [ "$OUT" -gt 0 ]
fact $? "an incremental build stops short of m, m being the size of the build"

# --------------------------------------------------------------- 5. 走っている間に出ること
#
# ここが元の壊れ方である。`drive` は生成器を `Command::output` で走らせて
# いた——プロセスの終了を待ち、捕まえた stdout をそのあとで流し直す。
# 1.3 秒のビルドの11行が、最後の19ミリ秒に固まって出ていた。
#
# 段を1つずつ走らせて、行の届く時刻が散っていることを見る。まとめて
# 流し直しているなら、全部が最後に固まる。

_last_cmd="dowel build --backend=direct --jobs 1   # 行ごとの到着時刻"
OUT=$(stamped --backend=direct --jobs 1 | grep '\] GEN ')
RC=0
first=$(printf '%s\n' "$OUT" | head -1 | cut -d' ' -f1)
last=$(printf '%s\n' "$OUT" | tail -1 | cut -d' ' -f1)
spread=$((last - first))
OUT="$OUT"$'\n'"spread: ${spread}ms across the four generations"
# 4つの生成はそれぞれ 500ms 待つ。まとめて出しているなら差は数ミリ秒に
# なる。しきい値は 1 秒——4つで 1.5 秒以上開くはずのものに対して、
# 遅い機械でも falsely 落ちない側へ大きく寄せてある。
[ "$spread" -gt 1000 ]
fact $? "the progress lines arrive while the build runs, not replayed at the end"

rm -rf .dowel compile_commands.json
rm -f "$RUN"/*.running "$RUN"/*.seen
