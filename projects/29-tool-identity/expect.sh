# 29-tool-identity — 道具の同一性を入力として記録する（ADR-0055）
#
# dowel は2つのものから何が古いかを決めていた——アクションが読むファイルと、
# 走らせる命令行。どちらも**プログラムが変わったこと**に気づかない。
# 命令行は `cc` と書いてある。入れ替えたあとも `cc` と書いてある。
#
# プロジェクトは道具の同一性の綴り方を既に持っていた。ADR-0028 は
# `facts::identity`——path・大きさ・mtime——を記録した probe の鍵へ混ぜて
# おり、まさに「入れ替えられた道具の答を古い記録から返さない」ためである。
# その同一性が、ビルド自身の鮮度へは渡っていなかった。
#
# 運び方は2つありえた。plan の辺と、file である。ADR-0054 が測ったとおり
# ninja は plan の `deps` を読まないので、**file の関係でない順序は順序では
# ない**。だから file にした——3つの backend が揃ってやっている唯一のことは、
# 入力と出力を比べることである。
#
# ここで見るのは、入れ替えれば組み直し、入れ替えなければ組み直さないこと。
# 後者が無ければ「毎回組み直している」と区別が付かない。

bdir() { find .dowel/build -mindepth 1 -maxdepth 1 -type d | head -1; }
tools() { printf '%s/tools' "$(bdir)"; }

BIN=$PWD/bin
mkdir -p "$BIN"

# wrap <中身の旗> — `cc` の代わりに置く包み。旗を足すか足さないかだけが違う。
#
# 包みを書き換えるのは、道具そのものを入れ替える手のうち、**手元で再現
# できる**形である。パッケージ管理器が同じ場所へ新しい gcc を置くのと、
# dowel から見て起きることは同じ——同じ path、違う中身。
wrap() {
    printf '#!/bin/sh\nexec cc %s "$@"\n' "$1" > "$BIN/mycc"
    chmod +x "$BIN/mycc"
}

# 道具を包みへ向ける。
python3 - "$BIN" <<'PY'
import sys
p = "dowel.toml"
t = open(p).read()
open(p, "w").write(t + '\n[toolchain]\nc = "%s/mycc"\n' % sys.argv[1])
PY

# --------------------------------------------------------------- 1. 記録されていること

wrap ""
rm -rf .dowel
ok "a package whose compiler is a wrapper builds" build --no-compdb
prints "1" "and what it built runs" "$(bdir)/bin/app"

# 板が1つ、道具ごとに置かれる。名前は読めるまま、digest が宣言を分ける。
_last_cmd="ls .dowel/build/*/tools"
OUT=$(ls "$(tools)" 2>&1 | paste -sd' ' -); RC=0
ls "$(tools)" | grep -q '^mycc-[0-9a-f]\{8\}\.stamp$'
fact $? "a stamp is written for the tool, named for it and for its declaration"

# 中身は PATH 上で解決した実体の同一性である。名前の同一性ではない。
_last_cmd="cat .dowel/build/*/tools/mycc-*.stamp"
OUT=$(cat "$(tools)"/mycc-*.stamp 2>&1); RC=0
printf '%s' "$OUT" | grep -qF "$BIN/mycc"
fact $? "and holds the identity of the program as resolved, not of the name"

# 板はアクションの入力である。辺ではなく file にしたのはこのためで、
# `build-graph.json` にも両方が現れる。
_last_cmd="graph --kind=action --format=json | .tool_stamps"
OUT=$("$DOWEL" graph --kind=action --format=json 2>/dev/null |
      jq -r '.tool_stamps[]?.path'); RC=0
printf '%s' "$OUT" | grep -q 'tools/mycc-'
fact $? "the graph carries the stamps a reader has to write before running"

_last_cmd="graph --kind=action --format=json | inputs of the compiles"
OUT=$("$DOWEL" graph --kind=action --format=json 2>/dev/null |
      jq -r '[.steps[] | select(.kind == "cc")] as $cc
             | [$cc[] | select([.inputs[] | test("tools/mycc-")] | any)] | length
             as $with | "\($with) of \($cc | length) compiles take the stamp as an input"')
RC=0
printf '%s' "$OUT" | grep -q '^2 of 2 '
fact $? "and every action that runs the tool takes its stamp as an input"

# 版は上がっている。`cwd` と `tool_stamps` はどちらも「この文書を走らせると
# 何が起きるか」を変えるので、古い読み手が読み違える。
_last_cmd="graph --kind=action --format=json | .version"
OUT=$("$DOWEL" graph --kind=action --format=json 2>/dev/null | jq -r .version); RC=0
[ "$OUT" = "2" ]
fact $? "the build graph says version 2, a version-1 reader having no stamps to write"

# --------------------------------------------------------------- 2. 入れ替えれば組み直す
#
# ADR-0055 が測った箇所。包みを書き換えても、古いコンパイラで作った目的
# ファイルが最新のままだった——3つの backend すべてで。

for b in direct ninja make; do
    wrap ""
    rm -rf .dowel
    "$DOWEL" build --no-compdb --backend=$b >/dev/null 2>&1
    prints "1" "$b: the program built by the first wrapper runs" "$(bdir)/bin/app"

    # 同じ秒の中で差し替えると同一性が動かない。mtime は1秒刻みであり、
    # ADR-0028 がコンパイラを数十メガバイト読まないために選んだ粒度である。
    sleep 1.1
    wrap "-DPATCHED"
    "$DOWEL" build --no-compdb --backend=$b >/dev/null 2>&1
    prints "2" "$b: replacing the compiler rebuilds what it produced" "$(bdir)/bin/app"
done

# 板は中身が変わったときだけ書かれる。書き直せば mtime が動き、mtime が
# 動けばその道具を使う全てが組み直る——道具が変わったときには正しく、
# 変わっていないときには誤りである。
wrap "-DPATCHED"
rm -rf .dowel
"$DOWEL" build --no-compdb >/dev/null 2>&1
STAMP=$(echo "$(tools)"/mycc-*.stamp)
m1=$(stat -c %Y "$STAMP")
sleep 1.1
"$DOWEL" build --no-compdb >/dev/null 2>&1
m2=$(stat -c %Y "$STAMP")
_last_cmd="stat -c %Y .dowel/build/*/tools/mycc-*.stamp   # ビルドを挟んで"
OUT="before: $m1"$'\n'"after:  $m2"; RC=0
[ "$m1" = "$m2" ]
fact $? "an unchanged tool leaves its stamp alone, mtime being what rebuilds"

# 組み直さないことの対照。上が「毎回組み直す」ではないと言えるのは、
# ここが 0 だからである。
build_direct --no-compdb
n=$(_ran_actions)
_last_cmd="dowel build --backend=direct"; OUT="ran ${n:-?} actions"; RC=0
[ "${n:-1}" = 0 ]
fact $? "and a build with the same tool runs nothing"

# --------------------------------------------------------------- 3. 名前ではなく綴り
#
# digest が分けているのは**書かれた綴り**である。`cc` と `/usr/bin/cc` は
# 同じファイルに解決しても別の宣言であり、別の板を持つ。中身は等しくなる
# ので、板がそれだけで何かを組み直させることはない。

cp dowel.toml dowel.toml.keep

set_cc() {
    python3 - "$1" <<'PY'
import re, sys
p = "dowel.toml"
t = open(p).read()
open(p, "w").write(re.sub(r'^c = ".*"$', 'c = "%s"' % sys.argv[1], t, flags=re.M))
PY
}

rm -rf .dowel
set_cc cc
"$DOWEL" build --no-compdb >/dev/null 2>&1
set_cc "$(command -v cc)"
"$DOWEL" build --no-compdb >/dev/null 2>&1
_last_cmd="ls .dowel/build/*/tools   # cc と $(command -v cc) の双方を宣言したあと"
OUT=$(ls "$(tools)" 2>&1 | paste -sd' ' -); RC=0
[ "$(ls "$(tools)" | grep -c '^cc-')" = 2 ]
fact $? "two spellings of the same program get two stamps, the digest being of the spelling"

_last_cmd="cat .dowel/build/*/tools/cc-*.stamp"
OUT=$(cat "$(tools)"/cc-*.stamp 2>&1); RC=0
[ "$(cat "$(tools)"/cc-*.stamp | sort -u | grep -c .)" = 1 ]
fact $? "and their contents are equal, both resolving to the same program"

cp dowel.toml.keep dowel.toml

# --------------------------------------------------------------- 4. check は解決するが書かない
#
# 計画は自分が決める材料を stat するだけで、書くのは組むつもりの実行だけ
# である。

rm -rf .dowel
ok "check passes without building" check
_last_cmd="ls .dowel/build/*/tools after check"
OUT=$(ls "$(tools)" 2>&1); RC=0
[ ! -d "$(tools)" ]
fact $? "and writes no stamp, planning only stat-ing what it decides from"

# --------------------------------------------------------------- 5. 無い道具
#
# 計画が先に拒む。板の話に届く前に止まる。

set_cc "$BIN/no-such-cc"
fails "a compiler that is not there fails" check
diag missing-toolchain "with its own code" check
cp dowel.toml.keep dowel.toml

rm -f dowel.toml.keep
rm -rf .dowel compile_commands.json "$BIN"
