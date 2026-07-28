# 02-config — 構成による分岐
#
# 主張の大半は C 側の #error と実行時の比較に書いてある。
# ここに書くのは、C から観測できないものだけである。

cd app || exit 1

standard app

# --------------------------------------------------- 構成ごとの具体化

prints "app_opt=0 probe_opt=0 arch=1 os=1 trace=1" \
    "debug: match の結果が引数まで届く" "$(artifact app)"

ok "release でも組める" build --config=release
prints "app_opt=1 probe_opt=1 arch=1 os=1 trace=1" \
    "release: 依存の公開定義も切り替わる" \
    "$(find .dowel/build -path '*release*/bin/app')"

# 構成を切り替えてもマニフェスト評価はやり直さない、という主張の外形。
# 利用者から見える形は「ビルドディレクトリが構成ごとに分かれる」ことである。
ids=$(build_dir_ids | tr '\n' ' ')
case $ids in
    *debug*release*|*release*debug*)
        fact 0 "構成ごとにビルドディレクトリが分かれる" ;;
    *)  fact 1 "構成ごとにビルドディレクトリが分かれる（$ids）" ;;
esac

# --------------------------------------------------- 機能フラグと後置 when

ok "機能フラグを外しても組める" build --no-default-features
prints "app_opt=0 probe_opt=0 arch=1 os=1 trace=0" \
    "when feature.trace が落ちると定義も消える" \
    "$(find .dowel/build -name app -path '*debug/bin/*')"

# 機能はビルドディレクトリの識別子に入る。入らないと、機能を切り替えた
# 結果が同じディレクトリに混ざる。
if build_dir_ids | grep -q 'debug-trace'; then
    fact 0 "機能フラグがビルドディレクトリの識別子に入る"
else
    fact 1 "機能フラグがビルドディレクトリの識別子に入る（$(build_dir_ids | tr '\n' ' ')）"
fi

# --------------------------------------------------- 実引数の観測
#
# 「なぜこの引数になったのか」はアクショングラフで追える。
# compile_commands.json は同じ内容が言語サーバへ渡る形であり、
# ここが崩れると補完と診断も同じだけ崩れる。

args_have app:app "-DAPP_OPT=0"  "app の引数に具体化後の定義が入る"
args_have app:app "-DPROBE_API=1" "依存の公開定義が app の引数に届く"

# 伝播しないことは、値の不在でしか観測できない。C 側の #ifdef でも
# 見ているが、そちらはヘッダを include した翻訳単位しか覆えない。
args_lack app:app "PROBE_TRACE" "依存の非公開フラグは依存元の引数に現れない"
args_lack app:app "PROBE_OS"    "依存の非公開定義は依存元の引数に現れない"
args_lack app:app "/probe/src"  "依存の非公開インクルードは依存元に現れない"

# probe 自身のコンパイルには効いている。効かなければ「非公開」ではなく
# 「消えている」ことになる。
args_have probe:probe "PROBE_TRACE" "非公開フラグは自分のコンパイルには効く"
args_have probe:probe "/probe/src"  "非公開インクルードは自分には効く"

compdb=$(find .dowel/build -name compile_commands.json -path '*debug-trace*' | head -1)
if [ -n "$compdb" ] && grep -q '"-DAPP_OPT=0"' "$compdb"; then
    fact 0 "compile_commands.json に具体化後の定義が入る"
else
    fact 1 "compile_commands.json に具体化後の定義が入る"
fi

# --------------------------------------------------- 網羅性の要求

cd ../probe || exit 1
ok "probe: check が通る"   check
ok "probe: test が通る"    test
ok "probe: release でも test が通る" test --config=release
