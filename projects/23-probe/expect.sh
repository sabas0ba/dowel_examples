# 23-probe — 道具に訊いたことを、プロジェクトの外に憶える
#
# dowel が道具に確かめた事実は、**利用者の cache 領域**に記録される
# （ADR-0028）。プロジェクトの中ではない。
#
#   $XDG_CACHE_HOME/dowel/facts/v1/facts    1行1件、<鍵>\t<値>
#
# 置き場所が外なのは、**事実が道具のものだから**である。同じコンパイラを
# 使う限り答はどの木でも同じで、`.dowel/cache/` の下に置けば木の数だけ
# 同じ問いを繰り返すことになる。耐久性の階層の頂点にあるものが、最も
# 揮発しやすい場所に住むことになってしまう。
#
# ここで見るのは3つ。
#
#   1. **訊いていること。** ホストの triple は dowel が組まれたときの綴りでは
#      なく、その機械のコンパイラが名乗る綴りである。訊かなければ、自分の
#      gcc の綴りを `--target` に渡した利用者が cross 扱いされる
#   2. **憶えていること。** 同じ問いを繰り返さない。別の木でも訊き直さない
#   3. **鍵が道具の同一性を持つこと。** 道具を差し替えれば鍵が変わり、
#      古い事実は「誤り」ではなく**届かない**ものになる
#
# 記録の場所は expect.sh が握る。本物の利用者 cache を触ると、検査が
# 手元の履歴に依存し、走らせた順で結果が変わる。

FACTS_HOME=$PWD/.facts
FACTS=$FACTS_HOME/dowel/facts/v1/facts
SHIM=$PWD/shim

export XDG_CACHE_HOME=$FACTS_HOME
PATH="$SHIM:$PATH"
export PATH

rm -rf "$FACTS_HOME"

# facts_dumpmachine — 記録された名乗りの答（複数あれば全部）。
facts_dumpmachine() {
    grep '^dumpmachine' "$FACTS" 2>/dev/null | sed 's|^dumpmachine||'
}

# facts_lines — 記録の件数。
facts_lines() { grep -c . "$FACTS" 2>/dev/null || printf 0; }

# ------------------------------------------------------------ 1. 訊いている

ok "the package builds with the renamed compiler" -C subject build --no-compdb

_last_cmd="cat \$XDG_CACHE_HOME/dowel/facts/v1/facts"
OUT=$(cat "$FACTS" 2>&1)
RC=0
[ -f "$FACTS" ]
fact $? "a fact database appears in the user's cache area"

# プロジェクトの中には無い。事実は道具のものであって木のものではない。
_last_cmd="find subject/.dowel -name facts"; RC=0
OUT=$(find subject/.dowel -name 'facts*' 2>/dev/null | paste -sd' ' -)
[ -z "$OUT" ]
fact $? "and not inside the project, because a fact belongs to the tool"

# 訊いた内容が読める。何を訊き、何と答えたか。
got=$(facts_dumpmachine | sed 's|.*/||')
_last_cmd="facts | dumpmachine"; OUT="$got"; RC=0
printf '%s' "$got" | grep -q 'x86_64-pc-linux-gnu'
fact $? "recording what the compiler answered when asked what it calls itself"

# ------------------------------------------------------------ 2. 訊いた答が効く
#
# ここが ADR の言う「記録されない入力」である。dowel が組まれたときの
# 綴りは x86_64-unknown-linux-gnu だが、この機械のコンパイラは
# x86_64-pc-linux-gnu と名乗る。後者を `--target` に渡した利用者は、
# 訊いていなければ cross 扱いされ、存在しえない runner を求められる。

ok "the triple the compiler calls itself is accepted as the host" \
    -C subject build --target=x86_64-pc-linux-gnu --no-compdb

# dowel 自身の綴りも通る。両方が同じ機械を指しているのだから、
# 片方だけを認めるのは利用者から見て恣意である。
ok "and so is the one dowel was built with, since both name this machine" \
    -C subject build --target=x86_64-unknown-linux-gnu --no-compdb

# 本当に別の機械は、変わらず断られる。上が「何でも通る」ではないことの対照。
diag missing-toolchain "while a genuinely foreign triple is still refused" \
    -C subject build --target=aarch64-unknown-linux-gnu --no-compdb

# ------------------------------------------------------------ 3. 憶えている
#
# 同じ問いを繰り返さない。以前は ninja が `--version` に答えるかどうかを、
# `dowel build` のたび、木のたびに訊いていた。

before=$(md5sum "$FACTS" | cut -d' ' -f1)
n_before=$(facts_lines)
"$DOWEL" -C subject build --no-compdb >/dev/null 2>&1
after=$(md5sum "$FACTS" | cut -d' ' -f1)
n_after=$(facts_lines)
_last_cmd="md5 facts   前後"
OUT="before: ${before:0:8} ($n_before records)"$'\n'"after:  ${after:0:8} ($n_after records)"
RC=0
[ "$before" = "$after" ]
fact $? "a second build in the same tree records nothing new"

# 別の木でも訊き直さない。**事実が道具のものである**ことの一番はっきりした
# 現れ方である。`.dowel/cache/` の下に置く設計では、ここで必ず1件増える。
n_before=$(facts_lines)
ok "a second package builds with the same compiler" -C other build --no-compdb
n_after=$(facts_lines)
seen=$(facts_dumpmachine | grep -c 'mycc')
_last_cmd="facts の件数   別の木を組む前後"
OUT="before: $n_before"$'\n'"after:  $n_after"$'\n'"dumpmachine records for this tool: $seen"
RC=0
[ "$n_before" = "$n_after" ] && [ "$seen" = 1 ]
fact $? "and asks the tool nothing again, because the answer is not a property of the tree"

# ------------------------------------------------------------ 4. 鍵は道具の同一性を持つ
#
# 鍵には道具の道・大きさ・更新時刻が入る。無効化の機構は意図的に無い——
# 道具を差し替えれば鍵が変わり、古い事実は二度と引かれない。

key=$(grep '^dumpmachine' "$FACTS" | head -1 | cut -f1)
_last_cmd="facts | 鍵"; OUT="$key"; RC=0
printf '%s' "$key" | grep -qE 'mycc:[0-9]+:[0-9]+$'
fact $? "the key carries the tool's path, size and mtime"

# 差し替える。大きさも更新時刻も変わるので、鍵が変わる。
n_before=$(facts_dumpmachine | grep -c 'mycc')
printf '\n# changed\n' >>"$SHIM/mycc"
ok "the tree still builds after the tool is replaced" -C subject build --no-compdb
n_after=$(facts_dumpmachine | grep -c 'mycc')
_last_cmd="facts | この道具の dumpmachine の件数"
OUT="$(facts_dumpmachine | sed 's|.*/shim/||')"
RC=0
[ "$n_after" -gt "$n_before" ]
fact $? "replacing it asks again under a new key, rather than trusting the old answer"

# 古い記録は残っている。上書きではなく**届かなくなる**のが設計である。
# 消す機構が無いぶん、誤った事実が生き残ることも無い。
_last_cmd="facts | 古い鍵"; OUT="$(facts_dumpmachine | sed 's|.*/shim/||')"; RC=0
[ "$n_after" -ge 2 ]
fact $? "leaving the old record in place, unreachable rather than wrong"

# ------------------------------------------------------------ 5. cache が両方を数える
#
# 2つある。木ごとの store と、利用者ごとの事実。片方しか出ないと、
# 「どこを消せばよいか」が利用者に分からない。

run -C subject cache info
said=$OUT
_last_cmd="dowel cache info"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q '\.dowel/cache'
fact $? "cache info names the per-project store"

_last_cmd="dowel cache info"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'facts'
fact $? "and the per-user fact database beside it"

_last_cmd="dowel cache info | facts の道"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q "$FACTS_HOME"
fact $? "giving the path it actually used, which is the one to delete by hand"

# 読むのにマニフェストは要らない。壊れた木でも掃除できなければ意味が無い。
cp subject/dowel.build subject/dowel.build.keep
printf 'this is not a manifest {{{\n' >subject/dowel.build
ok "cache info works even when the manifest is broken" -C subject cache info
mv subject/dowel.build.keep subject/dowel.build

# ------------------------------------------------------------ 6. 消しても安全
#
# どちらも cache である。手で消して壊れるなら、それは cache ではない。

rm -f "$FACTS"
ok "the tree builds again after the fact database is deleted by hand" \
    -C subject build --no-compdb

_last_cmd="facts   消してから組み直した後"; OUT=$(cat "$FACTS" 2>&1); RC=0
[ -s "$FACTS" ]
fact $? "and the next run asks again, writing what it learned back"

got=$(facts_dumpmachine | sed 's|.*/||')
_last_cmd="facts | dumpmachine"; OUT="$got"; RC=0
printf '%s' "$got" | grep -q 'x86_64-pc-linux-gnu'
fact $? "arriving at the same answer, because the tool has not changed"

# 集める側。古い形式の残骸を片づける。
ok "gc runs without a manifest too" -C subject cache gc
_last_cmd="dowel cache gc の後に組めるか"; RC=0
ok "and the tree still builds after it" -C subject build --no-compdb
