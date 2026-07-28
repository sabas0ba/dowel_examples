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
if build_dir_ids | grep -q 'debug-trace'; then
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

compdb=$(find .dowel/build -name compile_commands.json -path '*debug-trace*' | head -1)
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
