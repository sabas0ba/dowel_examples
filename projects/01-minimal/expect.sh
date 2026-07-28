# 01-minimal — 最小のパッケージ

cd hello || exit 1

standard hello

prints "hello" "実行ファイルが動く" "$(artifact hello)"

# direct 実行器だけでも一から組める。ninja の有無に依らない経路を持つことは
# 実装の主張のひとつであり、利用者から見える差は無いはずである。
rm -rf .dowel
runs_actions 2 "direct 実行器だけで一から組める（コンパイル1・リンク1）"
prints "hello" "direct 実行器の成果物も動く" "$(artifact hello)"

# 構成を指定しなければ debug で、ビルドディレクトリは構成ごとに分かれる。
ok "release でも組める" build --config=release
if [ "$(build_dir_ids | wc -l)" = 2 ]; then
    _verdict 0 "debug と release でビルドディレクトリが分かれる"
else
    _verdict 1 "debug と release でビルドディレクトリが分かれる（$(build_dir_ids | tr '\n' ' ')）"
fi

# 成果物はパッケージの外へ出ない。唯一の例外が compile_commands.json であり、
# これは言語サーバのために置かれる（docs/00-design.md 4節）。
stray=$(find . -mindepth 1 -maxdepth 1 \
    ! -name .dowel ! -name compile_commands.json \
    ! -name dowel.toml ! -name dowel.build ! -name src -print)
if [ -z "$stray" ]; then
    _verdict 0 "パッケージ直下に余計なものを作らない"
else
    _verdict 1 "パッケージ直下に余計なものを作らない（$stray）"
fi

# test ターゲットが1つも無いパッケージで dowel test を呼んでも失敗しない。
ok "test ターゲットが無くても test は成功する" test
