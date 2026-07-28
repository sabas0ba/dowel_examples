# 01-minimal — 最小のパッケージ
#
# 検査の名前は英語で書く（docs/00-design.md 6節）。説明のコメントは日本語でよい。

cd hello || exit 1

standard hello

prints "hello" "the binary runs and prints hello" "$(artifact hello)"

# direct 実行器だけでも一から組める。ninja の有無に依らない経路を持つことは
# 実装の主張のひとつであり、利用者から見える差は無いはずである。
rm -rf .dowel
runs_actions 2 "the direct executor builds from scratch in 2 actions (1 compile, 1 link)"
prints "hello" "the direct executor produces a working binary too" "$(artifact hello)"

# 構成を指定しなければ debug で、ビルドディレクトリは構成ごとに分かれる。
ok "release builds too" build --config=release
if [ "$(build_dir_ids | wc -l)" = 2 ]; then
    fact 0 "debug and release get separate build directories"
else
    fact 1 "debug and release get separate build directories (got: $(build_dir_ids | tr '\n' ' '))"
fi

# 成果物はパッケージの外へ出ない。唯一の例外が compile_commands.json であり、
# これは言語サーバのために置かれる（docs/00-design.md 4節）。
stray=$(find . -mindepth 1 -maxdepth 1 \
    ! -name .dowel ! -name compile_commands.json \
    ! -name dowel.toml ! -name dowel.build ! -name src -print)
if [ -z "$stray" ]; then
    fact 0 "nothing unexpected is written next to the manifest"
else
    fact 1 "nothing unexpected is written next to the manifest (found: $stray)"
fi

# test ターゲットが1つも無いパッケージで dowel test を呼んでも失敗しない。
ok "test succeeds when the package declares no test target" test
