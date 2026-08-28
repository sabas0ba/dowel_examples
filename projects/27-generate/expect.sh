# 27-generate — ソースを作る段をビルドの中へ入れる（ADR-0054 / ADR-0058）
#
# 解析器を bison から、走査器を flex から、表を script から。dowel は既に在る
# ソースしか翻訳できず、作られるソースを持つプロジェクトはマニフェストに
# それを書けなかった。唯一の組み方は「先に手で生成器を走らせる」であり、
# そうすると生成物は checked-in のソースに見え、その鮮度はビルドの外へ出る。
#
# 抜けはプロジェクトの内側からも見えていた。Meson の取り込みは読んだ目標の
# 生成ソースを毎回落としており、その理由を自分の code に書いていた——
# 「規則が dowel 側に無く、黙って落とすと下書きが組めるように見えて足りない
# 形になる」。
#
# ここで見るのは3つである。
#
#   1. 段がグラフの中に在ること。`dowel build` が作り、読むものが変われば
#      作り直し、出てきたソースが宣言した目標へ翻訳される
#   2. **走る場所**。生成器は自分の出力が落ちる場所で走る。だから `-o rows.c`
#      がそのままの意味になり、2つの生成が互いを踏まない
#   3. 綴れない命令は書き換えられずに拒まれること（ADR-0058）。ninja と make
#      は1つの段を1行で綴るので、改行を含む命令を綴れない

bdir() { find .dowel/build -mindepth 1 -maxdepth 1 -type d | head -1; }

# gen_dir <目標> <生成の名前> — その生成が走る場所。
#
# 絶対で綴る。アクショングラフの path は絶対であり、突き合わせる相手が
# 相対だと、在るのに一致しないという読みにくい落ち方をする。
gen_dir() { printf '%s/%s/generated/gen/%s/%s' "$PWD" "$(bdir)" "$1" "$2"; }

cp dowel.build dowel.build.keep
restore() { cp dowel.build.keep dowel.build; }

# --------------------------------------------------------------- 1. 普通の段である

ok "a package whose sources are generated builds" build --no-compdb
prints "26 4" "and the program it produced runs" "$(bdir)/bin/app"

# 生成した `.c` は宣言した目標へ翻訳される。使う側ではなく、書いた側へ。
_last_cmd="graph --kind=action | the compile of the generated source"
OUT=$("$DOWEL" graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc") | "\(.target) \(.inputs[0])"'); RC=0
printf '%s' "$OUT" | grep -q 'gen:table .*generated/gen/table/code/rows\.c'
fact $? "the generated source is compiled into the target that declares it"

# 進行の行が `GEN` と言う。段の種別はアクショングラフにも出る。
_last_cmd="graph --kind=action | .kind"
OUT=$("$DOWEL" graph --kind=action --format=json 2>/dev/null | jq -r '.steps[].kind'); RC=0
[ "$(printf '%s\n' "$OUT" | grep -c '^generate$')" = 2 ]
fact $? "the action graph names each generation as its own kind of step"

# --------------------------------------------------------------- 2. 走る場所
#
# ここが「マニフェストが何を綴らねばならないか」を決める。ビルド
# ディレクトリの名前は構成に依るので、そこへの path はマニフェストからは
# 組み立てられない。走る場所が出力の側なら、綴るのは相対名だけで足りる。

[ -f "$(gen_dir table code)/rows.c" ] && [ -f "$(gen_dir table decl)/rows.h" ]
_last_cmd="ls generated/gen/table/{code,decl}"
OUT=$(ls "$(gen_dir table code)" "$(gen_dir table decl)" 2>&1 | paste -sd' ' -); RC=0
fact $? "each generation gets a directory of its own, named for it"

_last_cmd="graph --kind=action | the generate step's cwd"
OUT=$("$DOWEL" graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "generate") | .cwd' | sort); RC=0
[ "$OUT" = "$(printf '%s\n%s' "$(gen_dir table code)" "$(gen_dir table decl)")" ]
fact $? "and the program runs in it, which is why the outputs are plain names"

# 命令行の形は `<command> <args...> <inputs...>` である。dowel が組み立てる
# あらゆる命令と同じ並びであり（ADR-0008）、生成器が期待する形でもある。
gen_args() {
    "$DOWEL" graph --kind=action --format=json 2>/dev/null |
        jq -r '.steps[] | select(.kind == "generate") | .arguments | join(" ")' | sort
}
_last_cmd="graph --kind=action | the generate step's arguments"
OUT=$(gen_args); RC=0
printf '%s' "$OUT" | grep -q 'gen/rows\.sh .*gen/seed\.txt$'
fact $? "the inputs are appended after the arguments, as everywhere else"

# `file()` は絶対 path へ開く。走る場所が出力の側にある以上、相対 path では
# パッケージへ届かない。
_last_cmd="graph --kind=action | the generate step's arguments"
OUT=$(gen_args); RC=0
printf '%s' "$OUT" | grep -q "^$PWD/gen/rows\.sh"
fact $? "and a file() in the arguments opens to an absolute path"

# --------------------------------------------------------------- 3. 出てきた見出しの経路
#
# 生成した見出しは名前で取り込まれる。ビルドディレクトリを指す `includes` を
# 別に書かせるのは、dowel がいま決めたことを利用者に綴らせることである。

cc_args gen:table | grep -q -- "-I$(gen_dir table decl)"
_last_cmd="cc_args gen:table"; OUT=$(cc_args gen:table); RC=0
fact $? "the output directory joins the include path without being declared"

# `public = true` は使う側へも伝える。`public.includes` の伝わり方と同じ。
cc_args gen:app | grep -q -- "-I$(gen_dir table decl)"
_last_cmd="cc_args gen:app"; OUT=$(cc_args gen:app); RC=0
fact $? "and public = true propagates it to a dependent"

# 既定はそうではない。`code` は `public` を書いていないので、宣言した目標に
# 留まる。伝わることが確かめられるのは、伝わらないものが隣に在るからである。
cc_args gen:app | grep -q -- "-I$(gen_dir table code)"
v=$?
_last_cmd="cc_args gen:app"; OUT=$(cc_args gen:app); RC=0
[ $v -ne 0 ]
fact $? "while a generation that does not say public stays with its own target"

# --------------------------------------------------------------- 4. 読むものが変われば作り直す

build_direct --no-compdb
rm -rf .dowel
build_direct --no-compdb
rebuilt "GEN" "a first build runs the generation"

build_direct --no-compdb
not_rebuilt "GEN" "and a second runs nothing"

printf '2 4 6 8 10\n' > gen/seed.txt
build_direct --no-compdb
rebuilt "GEN" "editing what the generation reads runs it again"
rebuilt "rows.c" "and recompiles the source it produced"
prints "30 5" "the program that comes out is the new one" "$(bdir)/bin/app"

# 使う側も翻訳し直す。生成した見出しを読んでいるのはそちらである。
rebuilt "main.c" "the dependent is recompiled too, having seen the generated header"

printf '3 5 7 11\n' > gen/seed.txt
build_direct --no-compdb

# --------------------------------------------------------------- 5. 順序が保たれること
#
# ここが ADR-0054 の測った箇所である。ninja は plan の `deps` を読まず、
# `build <出力>: <規則> <入力>` の file の関係だけで順序を決める。生成した
# 見出しをどの翻訳も入力に挙げていなければ、**順序は付かない**——翻訳が先に
# 走り、生成は一度も走らない。
#
# だから生成した出力は、届く範囲の**全ての**翻訳の入力になる。見出しを
# 取り込む翻訳だけではない。どの翻訳がどの見出しを読むかは depfile の答で
# あり、それが出るのは最初の翻訳が通ったあと——順序を決めるには遅すぎる。
_last_cmd="graph --kind=action | inputs of every compile"
OUT=$("$DOWEL" graph --kind=action --format=json 2>/dev/null |
      jq -r '[.steps[] | select(.kind == "cc")] as $cc
             | [$cc[] | select([.inputs[] | test("generated/gen/table/decl")] | any)] | length
             as $with | "\($with) of \($cc | length) compiles take a generated output as an input"')
RC=0
printf '%s' "$OUT" | grep -q '^3 of 3 '
fact $? "every compile in the reach takes the generated outputs as inputs"

# 主張ではなく結果で見る。空から組み直しても翻訳が生成を追い越さないこと。
# 一度通るだけでは足りない——順序が付いていない木は、付いていないまま
# たまたま通ることがある。
#
# 3つとも見る。木の生成は1つずつ出力を書くので、make も組める。
for b in ninja make direct; do
    rm -rf .dowel
    ok "a clean build under $b never lets a compile outrun the generation" \
       build --no-compdb --backend=$b
    prints "26 4" "and what $b built prints the same thing" "$(bdir)/bin/app"
done

# 出力が2つ以上の生成は make で組めない。**黙って別のものを組むのではなく**
# 拒み、どの段が何を超えたのかと、代わりに何を使えばよいのかを言う。
# bison の `-d` はまさにこの形（`.c` と `.h` を1度に書く）なので、
# 避けて通れる話ではない。
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t.replace(
    'decl = { command = "sh", args = [file("gen/decl.sh")], inputs = [file("gen/seed.txt")], outputs = ["rows.h"], public = true }',
    'decl = { command = "sh", args = [file("gen/both.sh")], inputs = [file("gen/seed.txt")], outputs = ["rows.h", "seen.h"], public = true }'))
PY
rm -rf .dowel
ok "a generation with two outputs builds under ninja" build --no-compdb --backend=ninja
fails "while make refuses it" build --no-compdb --backend=make
out_has "exactly one output per step" "saying it takes one output per step" \
        build --no-compdb --backend=make
out_has "backend=ninja" "and naming a backend that has no such limit" \
        build --no-compdb --backend=make
restore

# --------------------------------------------------------------- 6. 書けないもの

# 生成器が PATH に無い。計画の段で言う——issue #50 が missing compiler に
# 選んだのと同じ位置である。
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t.replace('command = "sh"', 'command = "no-such-generator"'))
PY
fails "a generator that is not on PATH fails" check
diag missing-generator "with its own code" check
diag_where missing-generator '.labels[0].line' "at the declaration" check
out_has "no-such-generator" "naming the program it looked for" check
# 道具ではなく命令である。cross build で組む機械は目標の機械ではない。
out_has "build machine" "and saying it runs on the build machine" check
out_has "toolchain" "so [toolchain] is not where it comes from" check
restore

# 自分の場所を出る出力。dowel はどこへ落ちるかを知らなければ、それを
# 翻訳の入力にできない。
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t.replace('outputs = ["rows.c"]', 'outputs = ["../rows.c"]'))
PY
diag invalid-output "an output naming a path outside its directory is refused" check
out_has "../rows.c" "naming the output that leaves" check
out_has "where the program runs" "and saying what the names are relative to" check
restore

# 何も書かない生成。目標へ何も足せない段は宣言の誤りであって、
# 走らせてから気づくものではない（ADR-0051 の立場を一段手前で）。
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t.replace('outputs = ["rows.c"]', 'outputs = []'))
PY
diag generates-nothing "a generation that writes nothing is refused" check
out_has "adds nothing" "and says why that is a declaration error" check
restore

# --------------------------------------------------------------- 7. backend が綴れない命令（ADR-0058）
#
# ninja も make も1つの段を1行で綴る。行終端を含む命令はそのままでは綴れず、
# **書き換えずに拒む**。書き換えた結果が通ってしまうのが元の壊れ方だった——
# ninja は改行を空白へ潰し、別の命令が成功していた。
# `\n` は TOML の文字列の escape なので、`printf` が受け取るより先に改行
# そのものへ変わる。それが、backend が1行で綴れない命令になる。
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t.replace(
    'decl = { command = "sh", args = [file("gen/decl.sh")], inputs = [file("gen/seed.txt")], outputs = ["rows.h"], public = true }',
    'decl = { command = "sh", args = ["-c", "printf \'extern const int rows[];\\nextern const int rows_len;\\n\' > rows.h"], outputs = ["rows.h"], public = true }'))
PY

for b in ninja make; do
    rm -rf .dowel
    fails "$b refuses a command it cannot spell" build --no-compdb --backend=$b
    out_has "cannot spell a newline" "saying what $b cannot spell" \
            build --no-compdb --backend=$b
    # 大抵は綴りの取り違えである。診断は直し方を名指す。
    out_has '\\n' "and naming the spelling that works everywhere, to $b's reader" \
            build --no-compdb --backend=$b
    out_has "backend=direct" "and the backend that runs argv without a shell ($b)" \
            build --no-compdb --backend=$b
done

# 書き換えないことは、**何も書かない**ことでしか言えない。半端に書かれた
# ビルドファイルは、前のものを壊したまま残る。
rm -rf .dowel
"$DOWEL" build --no-compdb --backend=ninja >/dev/null 2>&1
_last_cmd="ls .dowel/build/*/build.ninja after the refusal"
OUT=$(ls "$(bdir)"/build.ninja 2>&1); RC=0
[ ! -f "$(bdir)/build.ninja" ]
fact $? "and writes no build file at all, rather than a half-written one"

# direct は argv をそのまま渡すので、同じ宣言が組み上がる。この差が
# 「make の path の制限」と違って **shell の行を組む backend だけの制限**で
# あることは、これが無いと言えない。
rm -rf .dowel
ok "the same declaration builds under direct, which passes argv" \
   build --no-compdb --backend=direct

# そして書かれたのは、頼んだとおり改行を含む2行である。ninja が黙って
# 空白へ潰していた頃は、ここが1行になっていた。
_last_cmd="wc -l generated/gen/table/decl/rows.h"
OUT=$(wc -l < "$(gen_dir table decl)/rows.h" 2>&1); RC=0
[ "$OUT" = "2" ]
fact $? "and the file it wrote holds the newline that was asked for"
restore

# --------------------------------------------------------------- 8. 2つの生成は踏み合わない
#
# 走る場所が出力の側にあることの、もう1つの帰結である。同じ名前の生成を
# 2つの目標に置いても、書く先が違う。

# 同じ名前 `decl` の生成を使う側にも置く。書く先のファイル名まで同じに
# して、踏み合うなら踏み合うようにしてある。
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t + '''
[bin.app.generate]
decl = { command = "sh", args = [file("gen/appdecl.sh")], outputs = ["app.h"] }
''')
PY
rm -rf .dowel
ok "two generations may share a name across targets" build --no-compdb
[ -f "$(gen_dir table decl)/rows.h" ] && [ -f "$(gen_dir app decl)/app.h" ]
_last_cmd="ls generated/gen/{table,app}/decl"
OUT=$(ls "$(gen_dir table decl)" "$(gen_dir app decl)" 2>&1 | paste -sd' ' -); RC=0
fact $? "each writing into a directory named for its own target"
sh_run cat "$(gen_dir table decl)/rows.h"
! printf '%s' "$OUT" | grep -q 'APP_LOCAL'
fact $? "and neither one overwrites the other"
restore

# --------------------------------------------------------------- 9. まだ塞がっていないもの

# 宣言した出力を書かない生成。ADR-0054 は「何も書かない生成は ADR-0051 の
# ビルド後の検査が捕まえる」と書いているが、その検査は生成の出力へは
# 及んでいない（[F-068](../../docs/10-findings.md#f-068)）。
# 出力を1つだけ持ち、それを誰も取り込まない生成を足す。取り込まれていると
# 翻訳が「そんなファイルは無い」と落ちてしまい、**dowel が気づいたのか
# 翻訳器が落ちたのか**が分からなくなる。
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t + '''
[bin.app.generate]
liar = { command = "true", args = [], outputs = ["never.h"] }
''')
PY
# 対照。direct は段ごとに出力を見るので捕まえる。
rm -rf .dowel
fails "direct fails a generation that does not write what it declared" \
      build --no-compdb --backend=direct
out_has "GEN " "naming the generation, not the compiler's word two stages later" \
        build --no-compdb --backend=direct

for b in ninja make; do
    rm -rf .dowel
    "$DOWEL" build --no-compdb --backend=$b >/dev/null 2>&1
    v=$?
    _last_cmd="dowel build --backend=$b  # 宣言した never.h を書かない生成"
    OUT="exit $v; never.h exists: $([ -f "$(gen_dir app liar)/never.h" ] && echo yes || echo no)"
    RC=0
    known_issue F-068
    [ "$v" -ne 0 ]
    fact $? "$b fails it too, the declared output not being there"
done
restore

# `invalid-output` が `generates-nothing` を連れてくる。1つの誤りに2件出る
# うえ、下線の付いた行の `outputs` は空ではない
# （[F-069](../../docs/10-findings.md#f-069)）。
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t.replace('outputs = ["rows.c"]', 'outputs = ["../rows.c"]'))
PY
_last_cmd="dowel check --message-format=json | .code"
OUT=$("$DOWEL" check --message-format=json 2>/dev/null | jq -r .code | paste -sd' ' -)
RC=0
known_issue F-069
[ "$OUT" = "invalid-output" ]
fact $? "one rejected output produces one diagnostic"
restore

# backend の拒否には診断コードも位置も無い。JSON を読む側には、
# 診断0件で落ちたビルドに見える（[F-070](../../docs/10-findings.md#f-070)）。
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t.replace(
    'decl = { command = "sh", args = [file("gen/decl.sh")], inputs = [file("gen/seed.txt")], outputs = ["rows.h"], public = true }',
    'decl = { command = "sh", args = ["-c", "printf \'a\\nb\\n\' > rows.h"], outputs = ["rows.h"], public = true }'))
PY
rm -rf .dowel
_last_cmd="dowel build --backend=ninja --message-format=json"
OUT=$("$DOWEL" build --no-compdb --backend=ninja --message-format=json 2>/dev/null |
      jq -r .code | paste -sd' ' -)
RC=0
known_issue F-070
[ -n "$OUT" ]
fact $? "a refusal a backend makes carries a code, like every other refusal"
restore

# `args` に書いた `file()` は入力ではない。生成器が実際に読む script を
# 書き換えても、ビルドは最新のままである
# （[F-071](../../docs/10-findings.md#f-071)）。
rm -rf .dowel
"$DOWEL" build --no-compdb >/dev/null 2>&1
cp gen/rows.sh gen/rows.sh.keep
cat > gen/rows.sh <<'SH'
printf 'const int rows[] = { 111, 0 };\nconst int rows_len = 1;\n' > rows.c
SH
build_direct --no-compdb
_last_cmd="editing the script the generation runs, then dowel build"
OUT="$RAN"
RC=0
known_issue F-071
printf '%s\n' "$RAN" | grep -q 'GEN'
fact $? "editing the program a generation runs re-runs it"
mv gen/rows.sh.keep gen/rows.sh

# 生成が載せた `-I` を `dowel why` が説明できない。使う側が別の目標の
# 生成した置き場を見ている場合でも黙る（[F-072](../../docs/10-findings.md#f-072)）。
rm -rf .dowel
"$DOWEL" build --no-compdb >/dev/null 2>&1
_last_cmd="dowel why app includes"
OUT=$("$DOWEL" why app includes 2>&1)
RC=0
known_issue F-072
printf '%s' "$OUT" | grep -qF "$(gen_dir table decl)"
fact $? "why accounts for the include path a generation put on the command line"

rm -f dowel.build.keep gen/rows.sh.keep
rm -rf .dowel compile_commands.json
