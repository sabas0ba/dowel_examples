# 07-robustness — 壊れた入力に対する応答の形
#
# 04-diagnostics が見るのは「正しく診断される誤り」である。構文としては
# 通り、型検査や併合で落ちるものを並べてある。ここで見るのはその手前、
# **診断を組み立てる前に壊れている入力**に対する応答である。
#
# 見るのは診断の中身ではなく、応答の形の4つだけ。
#
#   1. シグナルで死なない
#   2. 受理するか拒むかのどちらかである（拒むなら非零で終わる）
#   3. 拒むなら、機械可読な診断を1件以上、位置つきで出す
#   4. 返ってくる
#
# これらは診断コードと違って一件も文書化されていないが、破れたときの
# 現れ方が最も悪い。abort したビルドツールは「マニフェストが誤っている」
# ではなく「道具が壊れた」として現れ、CI では基盤の不調と区別がつかない。
#
# 入力は inputs/<名前>.build に置き、subject/ の dowel.build へ差し替える。
# ok- で始まるものは受理されるべきもの、それ以外は拒まれるべきものである。
# 符号化と大きさに関わるものは git や編集器を通ると形が変わるため、
# ファイルに置かず下で生成する。

# 応答が返るまでの上限。性能を見るためではなく「返ってくる」ことを見る
# ためのものなので、遅い機械でも余る値を置く。
LIMIT_S=6
LIMIT_MS=5000

# ------------------------------------------------------------------ 下ごしらえ

SUBJECT=$PWD/subject
TOML=$(cat "$SUBJECT/dowel.toml")

# probe <ラベル> — subject/ に置いてある dowel.build に check を掛け、
# 応答の形を PROBE_* に記録する。判定は行わない。
PROBE_LABEL=""; PROBE_RC=0; PROBE_MS=0; PROBE_LOC=0; PROBE_ERR=""; PROBE_CODES=""
probe() {
    PROBE_LABEL=$1
    local t0 t1 json=$SUBJECT/../probe.json
    t0=$(now_ms)
    PROBE_ERR=$(cd "$SUBJECT" && timeout "$LIMIT_S" \
        "$DOWEL" check --message-format=json 2>&1 >"$json")
    PROBE_RC=$?
    t1=$(now_ms)
    PROBE_MS=$(( t1 - t0 ))
    PROBE_LOC=$(jq -rs '[.[] | select(.code and (.labels | length) > 0)] | length' \
        <"$json" 2>/dev/null)
    PROBE_CODES=$(jq -rs '[.[] | select(.code)] | map(.code) | unique | join(",")' \
        <"$json" 2>/dev/null)
    : "${PROBE_LOC:=0}"
}

# feed <名前> — inputs/<名前>.build を対象へ置いて probe する。
feed() { cp "inputs/$1.build" "$SUBJECT/dowel.build"; probe "$1"; }

# feed_gen <ラベル> <python 式> — 生成した内容を対象へ置いて probe する。
feed_gen() { python3 -c "$2" >"$SUBJECT/dowel.build"; probe "$1"; }

# 以下の5つが、この層で固定したい性質そのものである。
# いずれも PROBE_* を読むだけで、改めて dowel を走らせない。
#
# 検査名に実行時の値を混ぜない。名前は publish の表と履歴にそのまま並び、
# 文書からも引用される。回ごとに変わる名前は、同じ検査として追えなくなる。
# 観測した値は落ちたときの付帯情報として出す。

# _detail — 落ちたときに出す材料を harness の変数へ移す。
_detail() {
    RC=$PROBE_RC
    _last_cmd="dowel check --message-format=json   # subject/dowel.build = $PROBE_LABEL"
    OUT=$(printf 'elapsed=%sms  located=%s  codes=%s\n%s' \
        "$PROBE_MS" "$PROBE_LOC" "${PROBE_CODES:--}" "$PROBE_ERR")
}

# シグナルによる終了は 128+N として返る。パニックの文言も見る。
# abort した実行はここでしか観測できない（診断は1件も出ない）。
survives() {
    _detail
    [ "$PROBE_RC" -lt 128 ] &&
        ! printf '%s' "$PROBE_ERR" | grep -qE 'panicked|overflowed its stack'
    fact $? "$PROBE_LABEL does not abort dowel"
}

# 拒むこと。シグナルによる終了も時間切れも「拒んだ」ではない。
refused() {
    _detail
    [ "$PROBE_RC" -gt 0 ] && [ "$PROBE_RC" -lt 124 ]
    fact $? "$PROBE_LABEL is refused"
}

accepted() {
    _detail
    [ "$PROBE_RC" -eq 0 ]
    fact $? "$PROBE_LABEL is accepted"
}

# 位置の無い診断は「どこを直せばよいか」を伝えない。04-diagnostics は
# 同じことを型検査の側の診断について見ている（F-005）。
located() {
    _detail
    [ "$PROBE_LOC" -ge 1 ]
    fact $? "$PROBE_LABEL is refused with a source location"
}

answers() {
    _detail
    [ "$PROBE_MS" -lt "$LIMIT_MS" ] && [ "$PROBE_RC" -ne 124 ]
    fact $? "$PROBE_LABEL is answered within the budget"
}

# ------------------------------------------------------- 利用者が書き間違える形
#
# 括弧・引用符の閉じ忘れ、他の記法との取り違え（YAML の `:`、JSON、CMake、
# C の `;`）、`=>` の書き間違い。いずれも実際に手が滑る形である。

for name in $(cd inputs && ls *.build | sed 's/\.build$//' | grep -v '^ok-'); do
    feed "$name"
    survives
    refused
    located
    answers
done

# ------------------------------------------------------- 受理されるべきもの
#
# 見た目は変わっているが、いずれも正しい記述である。ここが落ちるように
# なると、実在するマニフェストが読めなくなる。拒む側だけを固定すると
# 「厳しくしすぎた」退行が検出できない。

for name in $(cd inputs && ls ok-*.build | sed 's/\.build$//'); do
    feed "$name"
    survives
    accepted
done

# ------------------------------------------------------- 符号化
#
# 内容は正しいが、バイト列が素直でないもの。CRLF と BOM は Windows の
# 編集器が黙って付ける。どちらも利用者が書いた覚えの無い違いである。

feed_gen "CRLF line endings" \
    'import sys; sys.stdout.buffer.write(b"[bin.subject]\r\nsources = glob(\"src/*.c\")\r\n")'
survives
accepted

# BOM は Windows の編集器と PowerShell のリダイレクトが付ける。付いたことは
# 画面に出ないため、拒まれると「正しい行なのに拒まれた」としか見えない
# （docs/10-findings.md F-011）。些末部として読み飛ばされる。
feed_gen "a UTF-8 BOM on dowel.build" \
    'import sys; sys.stdout.buffer.write(b"\xef\xbb\xbf[bin.subject]\nsources = glob(\"src/*.c\")\n")'
survives
accepted

printf '\xef\xbb\xbf%s\n' "$TOML" >"$SUBJECT/dowel.toml"
printf '[bin.subject]\nsources = glob("src/*.c")\n' >"$SUBJECT/dowel.build"
probe "a UTF-8 BOM on dowel.toml"
survives
accepted
printf '%s\n' "$TOML" >"$SUBJECT/dowel.toml"

# 先頭以外に現れた同じバイト列は、些末部ではなく誤りである。
feed_gen "a BOM in the middle of a line" \
    'import sys; sys.stdout.buffer.write(b"[bin.subject]\nsources = \xef\xbb\xbfglob(\"src/*.c\")\n")'
survives
refused
located

# 読めないバイト列。ここは拒むのが正しい。位置を持つことだけ見る。
feed_gen "invalid UTF-8 bytes" \
    'import sys; sys.stdout.buffer.write(b"[bin.subject]\nsources = glob(\"src/\xff\xfe.c\")\n")'
survives
refused
located

feed_gen "a NUL byte" \
    'import sys; sys.stdout.buffer.write(b"[bin.subject]\nsources\x00= glob(\"src/*.c\")\n")'
survives
refused
located

# ------------------------------------------------------- 大きさ
#
# 手で書く形ではないが、マニフェストを生成する道具（移行、コード生成）は
# この大きさを作る。落ちるとしても、落ち方が診断でなければならない。

feed_gen "a 200k element list" \
    'print("[bin.subject]"); print("sources = [" + ",".join(["\"src/main.c\""]*200000) + "]")'
survives
refused
located
answers

feed_gen "a 10MB string literal" \
    'print("[bin.subject]"); print("sources = \"" + "a"*(10*1024*1024) + "\"")'
survives
refused
located
answers

feed_gen "200k comment lines" \
    'import sys; w = sys.stdout.write; w("[bin.subject]\n");
[w("# %d\n" % i) for i in range(200000)]; w("sources = glob(\"src/*.c\")\n")'
survives
accepted
answers

# ------------------------------------------------------- 入れ子の深さ
#
# 再帰下降の解析器に深さの上限が無いと、入れ子はそのまま呼び出し段数になる。
# かつては上限が無く、超えた時点で abort していた（docs/10-findings.md F-010）。
# 上限は診断として現れる必要がある。
#
# 深さ 100000 を選ぶのは、上限を持たない実装では確実に溢れ、上限を持つ
# 実装では即座に診断で拒まれるためである。どちらでも待たされない。境目の
# 付近を選ぶと、dowel ではなく実行した機械の stack の大きさを記録することになる。

for form in \
    'print("[bin.subject]"); print("sources = " + "["*100000 + "]"*100000)|100k nested arrays' \
    'print("[bin.subject]"); print("sources = " + "{a="*100000 + "1" + "}"*100000)|100k nested inline tables' \
    'print("[bin.subject]"); print("sources = " + "glob("*50000 + "\"x\"" + ")"*50000)|50k nested calls'
do
    feed_gen "${form#*|}" "${form%|*}"
    survives
    refused
    located
    answers
    case $PROBE_CODES in
        *nesting-too-deep*) fact 0 "$PROBE_LABEL is refused as nesting-too-deep" ;;
        *) fact 1 "$PROBE_LABEL is refused as nesting-too-deep (got $PROBE_CODES)" ;;
    esac
done

# かつて超線形だったところ。入力は 4KB しかないのに応答が秒の単位になっていた。
feed_gen "2k nested inline tables" \
    'print("[bin.subject]"); print("sources = " + "{a="*2000 + "1" + "}"*2000)'
survives
answers

# ------------------------------------------------------- 上限そのもの
#
# 上限は生成された記述を拒むためのものであり、人が書く深さを拒んではならない。
# どこに置かれているかと、動かせることを見る。
#
# 入れ子には型として通る形を使う。配列を重ねると深さの前に型で落ちてしまい、
# 何を見ているのか分からなくなる。

nested() {
    feed_gen "$2" "
n = $1
print('[bin.subject]')
print('sources = ' + 'match cfg.opt { debug => '*n + 'glob(\"src/*.c\")' + ', release => [] }'*n)
"
}

nested 63 "nesting 63 deep"
accepted
nested 100 "nesting 100 deep"
refused
located

# 上限は動かせる。生成された記述を扱う利用者に逃げ道が要る。
nested 100 "nesting 100 deep with a raised limit"
_last=$PROBE_LABEL
probe_with() {
    local json=$SUBJECT/../probe.json
    (cd "$SUBJECT" && timeout "$LIMIT_S" "$DOWEL" check --message-format=json "$@" >"$json" 2>/dev/null)
    PROBE_RC=$?
}
probe_with --max-nesting=200
[ "$PROBE_RC" -eq 0 ]
fact $? "--max-nesting raises the limit"
probe_with --max-nesting=50
[ "$PROBE_RC" -ne 0 ]
fact $? "--max-nesting can lower the limit too"

# 上限そのものにも上限がある。無制限にできるなら、上限を置いた意味が無い。
nested 10 "a shallow value"
for bad in 0 513 abc -1; do
    probe_with "--max-nesting=$bad"
    [ "$PROBE_RC" -eq 2 ]
    fact $? "--max-nesting=$bad is refused as a usage error"
done

# ------------------------------------------------------- I/O
#
# マニフェストがファイルとして読めない形。読めないこと自体は誤りではなく、
# 誤りとして報告されるべきものである。

rm -f "$SUBJECT/dowel.build" && mkdir -p "$SUBJECT/dowel.build"
probe "dowel.build being a directory"
survives
refused
located
rmdir "$SUBJECT/dowel.build"

ln -s dowel.build "$SUBJECT/loop" && ln -s loop "$SUBJECT/dowel.build"
probe "dowel.build being a symlink loop"
survives
refused
located
rm -f "$SUBJECT/dowel.build" "$SUBJECT/loop"

# ------------------------------------------------------- 誤りの取りこぼし
#
# 誤りが1つ見つかった時点で止まると、利用者は直しては走らせるを繰り返す。
# 独立した誤りは1回の実行でまとめて出るのが望ましい。

printf '[bin.subject]\nsources =\nincludes =\nflags =\n' >"$SUBJECT/dowel.build"
probe "three independent errors"
n=$(jq -rs '[.[] | select(.code)] | length' <"$SUBJECT/../probe.json" 2>/dev/null)
_detail
[ "${n:-0}" -ge 3 ]
fact $? "three independent errors are reported in one run"

# ------------------------------------------------------- 後始末
#
# 対象を元に戻す。run.sh の「実体を汚していないことの確認」は projects/ を
# 見るが、.work/ の中も次の検査の入力になる。
printf '# expect.sh がここを差し替える。置いてあるのは差し替え前の正しい形。\n[bin.subject]\nsources = glob("src/*.c")\n' >"$SUBJECT/dowel.build"
rm -f "$SUBJECT/../probe.json"
