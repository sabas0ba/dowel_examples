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

# ------------------------------------------------------- 肥大と収集（ADR-0037）
#
# 2つ育つ。**値の記録**は追記のみなので、同じ鍵を上書きすると古いバイトが
# 残る。**ビルドディレクトリ**は構成ごとにあり、debug と release を往復
# すれば前の方が丸ごと残る。後者の方が桁が大きい。
#
# 既定は**報せるだけ**である。圧縮はファイルを書き直すので、利用者が
# 頼んでいない時間を build が使うことになる。

# dead — 到達できないバイト数。
dead() { "$DOWEL" -C subject cache info 2>/dev/null | sed -n 's/^dead *\([0-9]*\).*/\1/p'; }
# builds_n — ビルドディレクトリの数。
builds_n() { "$DOWEL" -C subject cache info 2>/dev/null | sed -n 's/^builds .* in \([0-9]*\) configuration.*/\1/p'; }

# 記録を太らせる。マニフェストを繰り返し変えると、評価の結果が上書きされる。
i=1
while [ "$i" -le 25 ]; do
    manifest "$GOOD
[bin.subject.public]
defines = { CHURN = $i }
"
    "$DOWEL" -C subject build --no-compdb >/dev/null 2>&1
    i=$((i + 1))
done

d=$(dead)
_last_cmd="dowel cache info | dead"; OUT="dead: ${d:-?} bytes"; RC=0
[ -n "$d" ] && [ "$d" -gt 0 ]
fact $? "overwriting a key leaves bytes behind, and cache info reports them as dead"

# 予算は生きているバイトそのものである。木の大きさに追随するので、
# 1つのリポジトリに合う固定値を選ぶ必要が無い。
manifest "$GOOD
[bin.subject.public]
defines = { CHURN = 99 }
"
run -C subject build --no-compdb
said=$OUT
_last_cmd="dowel build  # 予算を超えている"; OUT=$(printf '%s' "$said" | grep -i 'note:'); RC=0
printf '%s' "$said" | grep -q 'no longer reachable'
fact $? "a run that ends over budget says so"

_last_cmd="同じ報せ"; OUT=$(printf '%s' "$said" | grep -i 'note:'); RC=0
printf '%s' "$said" | grep -q 'cache gc' && printf '%s' "$said" | grep -q 'DOWEL_CACHE'
fact $? "naming both how to collect it once and how to make it automatic"

# 黙らせられる。報せは既定であって強制ではない。
manifest "$GOOD
[bin.subject.public]
defines = { CHURN = 98 }
"
_last_cmd="DOWEL_CACHE=off dowel build"; RC=0
OUT=$(DOWEL_CACHE=off "$DOWEL" -C subject build --no-compdb 2>&1 | grep -i 'note:.*reachable')
[ -z "$OUT" ]
fact $? "and DOWEL_CACHE=off stops saying it"

# 頼めば集める。既定が集めないのは、圧縮がファイルを書き直すからである。
before=$(dead)
manifest "$GOOD
[bin.subject.public]
defines = { CHURN = 97 }
"
DOWEL_CACHE=gc "$DOWEL" -C subject build --no-compdb >/dev/null 2>&1
after=$(dead)
_last_cmd="DOWEL_CACHE=gc dowel build"
OUT="dead: ${before:-?} -> ${after:-?}"; RC=0
[ -n "$before" ] && [ "$before" -gt 0 ] && [ "${after:-1}" = 0 ]
fact $? "while DOWEL_CACHE=gc compacts in place, which is what the note offers"

ok "and the tree still builds after it" -C subject build --no-compdb

# ------------------------------------------------------- ビルドディレクトリ
#
# こちらが桁の大きい方である。構成ごとに1つ残る。

"$DOWEL" -C subject build --no-compdb --config=release >/dev/null 2>&1
n=$(builds_n)
_last_cmd="dowel cache info | builds"; RC=0
OUT=$("$DOWEL" -C subject cache info 2>/dev/null | sed -n '/^builds/,/^facts/p' | head -4)
[ "${n:-0}" -ge 2 ]
fact $? "cache info counts the build directories, one per configuration"

# 数だけでは片づけられない。**いつ書かれたか**が要る。
_last_cmd="dowel cache info | builds の各行"; RC=0
OUT=$("$DOWEL" -C subject cache info 2>/dev/null | grep -E '^  x86_64' | head -3)
printf '%s' "$OUT" | grep -qE '[0-9]+ days'
fact $? "with how long ago each was written, which is what selects one for removal"

# 数を渡さなければ触らない。「今のもの以外」は、2つの構成を日々往復して
# いる利用者の片方を消すことになる。
before=$(builds_n)
"$DOWEL" -C subject cache gc >/dev/null 2>&1
after=$(builds_n)
_last_cmd="dowel cache gc  # 日数を渡さない"
OUT="configurations: ${before:-?} -> ${after:-?}"; RC=0
[ "$before" = "$after" ]
fact $? "gc without a number leaves them all, since nobody said which are unused"

# 古いものは消せる。ここでは release の側を 60 日前に見せかける。
old=$(find subject/.dowel/build -maxdepth 1 -mindepth 1 -type d -name '*release*' | head -1)
find "$old" -exec touch -d '60 days ago' {} + 2>/dev/null
touch -d '60 days ago' "$old"

run -C subject cache gc --older-than=30
said=$OUT
_last_cmd="dowel cache gc --older-than=30"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'release'
fact $? "gc with a number removes a configuration nobody has built in that long"

n=$(builds_n)
_last_cmd="dowel cache info | builds"; OUT="configurations left: ${n:-?}"; RC=0
[ "${n:-0}" = 1 ]
fact $? "leaving the one that is still in use"

# 消しても失われない。ビルドディレクトリの中身は組み直せる。
ok "and what was removed builds again" -C subject build --no-compdb --config=release

# 掃除はマニフェストを読まない。壊れた木でも片づけられなければ意味が無い。
manifest 'this is not a manifest {{{'
ok "cache info works even when the manifest is broken" -C subject cache info
ok "and so does gc"                                    -C subject cache gc
manifest "$GOOD"
