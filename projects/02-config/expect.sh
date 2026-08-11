# 02-config — 構成による分岐
#
# 主張の大半は C 側の #error と実行時の比較に書いてある。
# ここに書くのは、C から観測できないものだけである。

cd app || exit 1

standard app

# --------------------------------------------------- 構成ごとの具体化

prints "app_opt=0 probe_opt=0 arch=1 os=1 trace=1" \
    "debug: the arms chosen by match reach the compiler" "$(artifact app)"

ok "release builds too" build --config=release
prints "app_opt=1 probe_opt=1 arch=1 os=1 trace=1" \
    "release: the public defines of a dependency switch as well" \
    "$(find .dowel/build -path '*release*/bin/app')"

# 構成を切り替えてもマニフェスト評価はやり直さない、という主張の外形。
# 利用者から見える形は「ビルドディレクトリが構成ごとに分かれる」ことである。
ids=$(build_dir_ids | tr '\n' ' ')
case $ids in
    *debug*release*|*release*debug*)
        fact 0 "each configuration gets its own build directory" ;;
    *)  fact 1 "each configuration gets its own build directory (got: $ids)" ;;
esac

# --------------------------------------------------- 機能フラグと後置 when

ok "the default features can be turned off" build --no-default-features
prints "app_opt=0 probe_opt=0 arch=1 os=1 trace=0" \
    "dropping when feature.trace drops the define with it" \
    "$(find .dowel/build -name app -path '*debug/bin/*')"

# 機能はビルドディレクトリの識別子に入る。入らないと、機能を切り替えた
# 結果が同じディレクトリに混ざる。
if build_dir_ids | grep -q 'debug-app--trace'; then
    fact 0 "enabled features appear in the build directory identifier"
else
    fact 1 "enabled features appear in the build directory identifier (got: $(build_dir_ids | tr '\n' ' '))"
fi

# --------------------------------------------------- 実引数の観測
#
# 「なぜこの引数になったのか」はアクショングラフで追える。
# compile_commands.json は同じ内容が言語サーバへ渡る形であり、
# ここが崩れると補完と診断も同じだけ崩れる。

args_have app:app "-DAPP_OPT=0"  "the specialized defines reach the arguments of app"
args_have app:app "-DPROBE_API=1" "the public defines of a dependency reach app"

# 伝播しないことは、値の不在でしか観測できない。C 側の #ifdef でも
# 見ているが、そちらはヘッダを include した翻訳単位しか覆えない。
args_lack app:app "PROBE_TRACE" "private flags of a dependency never reach a dependent"
args_lack app:app "PROBE_OS"    "private defines of a dependency never reach a dependent"
args_lack app:app "/probe/src"  "private includes of a dependency never reach a dependent"

# probe 自身のコンパイルには効いている。効かなければ「非公開」ではなく
# 「消えている」ことになる。
args_have probe:probe "PROBE_TRACE" "private flags still apply to the target's own compilation"
args_have probe:probe "/probe/src"  "private includes still apply to the target's own compilation"

compdb=$(find .dowel/build -name compile_commands.json -path '*debug-app--trace*' | head -1)
if [ -n "$compdb" ] && grep -q '"-DAPP_OPT=0"' "$compdb"; then
    fact 0 "compile_commands.json carries the specialized defines"
else
    fact 1 "compile_commands.json carries the specialized defines"
fi

# --------------------------------------------------- 網羅性の要求

cd ../probe || exit 1
ok "probe: check passes"                check
ok "probe: test passes"                 test
ok "probe: test passes in release too"  test --config=release

# --------------------------------------------------- 述語の合成（ADR-0032）
#
# `when` の述語が `and` / `or` / `not` と括弧で組めるようになった。
# 見るのは3つである。
#
#   1. 真理値が合っていること
#   2. **偽になる述語がある**こと。真になるものだけ並べると、常に真の
#      実装でも検査が通る
#   3. 語彙の検査が葉まで届くこと。合成の中に隠れた綴り違いを見逃さない
#
# `not` が要るのは「Windows 以外のどこでも」を正しく保つためである。
# 他の値を並べる形は、`target.os` に語が1つ足された日に黙って覆わなくなる。

cd ../app || exit 1

args_have app:app "-DP_EITHER" "or joins two comparisons on the same key"
args_have app:app "-DP_NOTWIN" "not inverts one, which is how everywhere-except is written"
args_have app:app "-DP_BOTH"   "and joins a feature with a negated one"
args_have app:app "-DP_PAREN"  "and parentheses group across two different keys"

# 常に偽の述語。合成が「何を書いても真」でないことの対照である。
args_lack app:app "-DP_NEVER"  "a predicate that cannot hold contributes nothing"

# 優先順位。`a and not b or b` は `(a and (not b)) or b` である。
# quiet を立てると前半が偽になるが、後半で真に戻る——括弧を書かずに
# その形になっていることが、not > and > or の観測になる。
# `args_have` / `args_lack` は追加の dowel 引数を渡さないので、構成を
# 変えて見るここでは `cc_args` を直に使う。
# said <desc> <正規表現> <have|lack> <dowel args...>
under() {
    local want=$1 how=$2; shift 2
    local desc=$1; shift
    local got; got=$(cc_args app:app "$@")
    _last_cmd="cc_args app:app $*  | grep -- $want"
    OUT=$(printf '%s' "$got" | tr ' ' '\n' | grep '^-DP_' | paste -sd' ' -)
    RC=0
    if [ "$how" = have ]; then
        printf '%s' "$got" | grep -qF -- "$want"
    else
        ! printf '%s' "$got" | grep -qF -- "$want"
    fi
    _verdict $? "$desc"
}

under "-DP_BOTH" lack "raising a feature drops the conjunction that excluded it" \
    --features=quiet
under "-DP_PREC" have "while the disjunction still holds, which is not > and > or" \
    --features=quiet

# 両方の項を落とすと、その or も落ちる。上が「or が常に真」でないことの対照。
under "-DP_PREC" lack "and with neither term it holds no longer" \
    --no-default-features

# 構成の側の項も効く。release では括弧の中の cfg.opt が偽になる。
under "-DP_PAREN"  lack "a term naming the configuration drops with it"   --config=release
under "-DP_EITHER" have "while the terms that do not name it stay"        --config=release

# 語彙の検査は葉まで届く。合成の中に隠れた綴り違いは、単独のときと同じに
# 拒まれる——ここが緩いと、合成は誤りを隠す場所になる。
probe_dir=$(mktemp -d)
mkdir -p "$probe_dir/src"
cat >"$probe_dir/dowel.toml" <<'TOML'
[package]
name = "bad"
version = "0.1.0"
edition = "2026"
TOML
printf 'int main(void){ return 0; }\n' >"$probe_dir/src/main.c"

for form in 'not target.os == "windwos"' \
            'target.os == "linux" or target.os == "windwos"' \
            'target.os == "windwos" and cfg.opt == "debug"'; do
    printf '[bin.app]\nsources = [file("src/main.c")]\n\n[bin.app.private]\nflags = ["-DX" when %s]\n' \
        "$form" >"$probe_dir/dowel.build"
    diag unknown-pattern "a misspelled value is refused inside: $form" -C "$probe_dir" check
done
rm -rf "$probe_dir"
