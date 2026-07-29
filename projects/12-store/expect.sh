# 12-store — プロセスを跨いだ評価結果の復元
#
# `dowel` は常駐しない（ADR-0002）。1回の実行ごとにプロセスが終わるため、
# **次のプロセスが前回の仕事を引き継げるかどうか**がそのまま増分の土台になる。
# 引き継ぎはディスク上のストア（`.dowel/cache/<形式版>/`）が担う。
#
# 05-incremental は同一プロセス内での再ビルドを見る。ここで見るのはその手前、
# **プロセスを跨いだ復元**である。F-014 が示したように、記録が引き継がれない
# 経路は黙って古い結果を返す。だから復元は「速くなったか」ではなく
# 「何を引き継いだか」と「引き継げなくても答が変わらないか」で見る。

SUBJECT=$PWD/subject
CACHE=$SUBJECT/.dowel/cache/v1

# store_line <dowel args...> — 実行ごとの要約（debug ログに出る）。
store_line() {
    "$DOWEL" -C subject check --log-level=debug "$@" 2>&1 |
        sed -n 's/.*store: \(wrote .*\)/\1/p' | tail -1
}

# store_field <語> — 直近の要約から数を取る。
store_field() { printf '%s' "$1" | sed -n "s/.*$2 \([0-9]*\).*/\1/p"; }

# verdicts <dowel args...> — 変更検出の判定（trace ログに出る）。
verdicts() {
    "$DOWEL" -C subject check --log-level=trace "$@" 2>&1 |
        grep -oE 'UnchangedByStat|UnchangedByContent|Changed' | sort -u | tr '\n' ' '
}

fresh() { rm -rf "$SUBJECT/.dowel"; }
manifest() { printf '%s' "$1" > "$SUBJECT/dowel.build"; }
GOOD='[bin.subject]
sources = glob("src/*.c")

[bin.subject.private]
flags = [match cfg.opt { debug => "-O0", release => "-O2" }]
'

# ------------------------------------------------------- 引き継ぎが起きること

manifest "$GOOD"
fresh
first=$(store_line)
[ "$(store_field "$first" wrote)" -gt 0 ] && [ "$(store_field "$first" restored)" = 0 ]
fact $? "the first run in a fresh tree stores and restores nothing"

second=$(store_line)
[ "$(store_field "$second" restored)" -gt 0 ]
fact $? "the next process restores what the first one stored"
[ "$(store_field "$second" wrote)" = 0 ]
fact $? "and stores nothing new when nothing changed"

# 復元しても答は変わらない。速くなることではなく、同じ答が出ることが前提である。
ok "a restored run still passes check" -C subject check
ok "a restored run still builds" -C subject build

# ------------------------------------------------------- 変更の検出
#
# 変更検出は (mtime, size, inode, ctime) の比較で行い、差異が出た場合にのみ
# 内容の指紋を取る。触っただけと書き換えたのを区別できなければ、
# 触るたびに評価をやり直すか、書き換えても気づかないかのどちらかになる。

store_line >/dev/null
got=$(verdicts)
case $got in *UnchangedByStat*) fact 0 "an untouched file is judged unchanged by its stat alone" ;;
    *) fact 1 "an untouched file is judged unchanged by its stat alone" ;; esac

touch "$SUBJECT/dowel.build"
got=$(verdicts)
case $got in *UnchangedByContent*) fact 0 "a touched file falls back to its content fingerprint" ;;
    *) fact 1 "a touched file falls back to its content fingerprint" ;; esac

# 触っただけなら、格納し直す必要は無い。
line=$(store_line)
[ "$(store_field "$line" restored)" -gt 0 ]
fact $? "a touched but unchanged file is still restored"

manifest "$GOOD
# a comment
"
got=$(verdicts)
case $got in *Changed*) fact 0 "an edited file is judged changed" ;;
    *) fact 1 "an edited file is judged changed" ;; esac

# 判定を見る実行が、そのまま格納もしてしまう。数を見るときは編集し直して、
# その編集後の最初の実行を測る。
manifest "$GOOD
# another comment
"
line=$(store_line)
[ "$(store_field "$line" wrote)" -gt 0 ]
fact $? "an edited file is evaluated again and stored again"

# ------------------------------------------------------- 診断を持つファイル
#
# 格納の対象は、診断を1件も出さずに評価できたファイルに限る。誤りを含む
# 評価結果を引き継ぐと、直したあとも古い診断が残りうる。

manifest '[bin.subject]
sources = glob("src/*.c")

[bin.subject.private]
flags = ["-O0" when cfg.nosuch]
'
fresh
line=$(store_line)
[ "$(store_field "$line" skipped)" -gt 0 ]
fact $? "a file whose evaluation produced diagnostics is not stored"
diag unknown-cfg-key "the diagnostic is reported on the first run" -C subject check
diag unknown-cfg-key "and on the next process too, not only the first" -C subject check

# 直したら、その診断は消える。
manifest "$GOOD"
no_diag unknown-cfg-key "fixing the manifest clears the diagnostic in the next process" \
    -C subject check

# ------------------------------------------------------- 壊れたストア
#
# 「形式の版が合わない場合、切り詰められた場合、外部から書き換えられた場合の
# いずれでも、結果は変わらず速度のみを失う」。ストアは速度のための記録であり、
# 答の一部ではない。壊れた記録が答を変えるなら、それは記録ではなく入力である。

fresh
run -C subject check
GOOD_OUT=$OUT
cp -r "$CACHE" "$SUBJECT/.cache-good"

# same_answer <desc> — 直前に壊したストアで、答が変わらないこと。
same_answer() {
    run -C subject check
    [ "$RC" -eq 0 ] && [ "$OUT" = "$GOOD_OUT" ]
    _verdict $? "$1"
}
restore_cache() { rm -rf "$CACHE"; cp -r "$SUBJECT/.cache-good" "$CACHE"; }

truncate -s 10 "$CACHE/values"
same_answer "a truncated value log does not change the answer"
restore_cache; truncate -s 0 "$CACHE/values"
same_answer "an empty value log does not change the answer"
restore_cache; truncate -s 7 "$CACHE/index"
same_answer "an index cut at a partial record does not change the answer"
restore_cache; head -c 64 /dev/urandom > "$CACHE/index"
same_answer "an index full of noise does not change the answer"
restore_cache; head -c 200 /dev/urandom > "$CACHE/values"
same_answer "a value log full of noise does not change the answer"
restore_cache; rm -f "$CACHE/index"
same_answer "a missing index does not change the answer"
restore_cache; rm -f "$CACHE/values"
same_answer "a missing value log does not change the answer"
restore_cache; rm -rf "$SUBJECT/.dowel/cache"; mkdir -p "$SUBJECT/.dowel/cache/v99"
same_answer "a store written by an unknown format version does not change the answer"

# 壊れたストアのあとも、次の実行で作り直せること。壊れたまま固まるなら、
# 一度の破損が恒久的に速度を失わせる。
restore_cache
head -c 200 /dev/urandom > "$CACHE/values"
run -C subject check
line=$(store_line)
[ "$(store_field "$line" restored)" -gt 0 ]
fact $? "the store recovers by itself after being corrupted"

# ------------------------------------------------------- 掃除

fresh
run -C subject check
run cache info -C subject
said=$OUT      # 判定のたびに OUT は捨てられる。先に控える。
printf '%s' "$said" | grep -q 'records'
fact $? "cache info reports what the store holds"
printf '%s' "$said" | grep -q 'format'
fact $? "cache info names the format version"

mkdir -p "$SUBJECT/.dowel/cache/v0"
: > "$SUBJECT/.dowel/cache/v0/values"
ok "cache gc runs" -C subject cache gc
if [ -d "$SUBJECT/.dowel/cache/v0" ]; then
    fact 1 "cache gc removes stores left by older formats"
else
    fact 0 "cache gc removes stores left by older formats"
fi
if [ -d "$CACHE" ]; then
    fact 0 "cache gc keeps the store of the current format"
else
    fact 1 "cache gc keeps the store of the current format"
fi
ok "check still passes after gc" -C subject check

rm -rf "$SUBJECT/.cache-good"
manifest "$GOOD"
