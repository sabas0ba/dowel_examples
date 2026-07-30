# 参照 compile_commands.json

`migrate verify` に渡す参照。`@ROOT@` を複製先の絶対パスに差し替えてから使う
（`expect.sh` の `ref`）。移行元の道具に依らせないため、CMake から生成せず
手で書いてある。

| ファイル | 何を見るか | 期待 |
|---|---|---|
| `baseline.json.in` | 翻訳を決めないもの（コンパイラの名前、`-c`、`-o`、`-MD` の一族）が差にならない | 2 equivalent |
| `spellings.json.in` | `-DA` ≡ `-D A=1` ≡ `-DA=1` | 2 equivalent |
| `relative.json.in` | 相対の `-I` と相対のファイル名が `directory` を基に解決される | 2 equivalent |
| `shuffled.json.in` | 引数の順序が差にならない | 2 equivalent |
| `differing.json.in` | 本物の差は残る。`one.c` から `-Wall` を落とし `-DEXTRA=1` を足した | 1 equivalent, 1 differing |
| `partial.json.in` | 参照に無く dowel にあるものは `only in dowel` | 1 equivalent, 1 only in dowel |
| `unported.json.in` | 参照にあり dowel に無いものは `not ported` | 1 not ported, 2 only in dowel |
| `broken.json.in` | JSON でないものは拒む | 非0 |
| `empty.json.in` | 空の参照は拒む。突き合わせる相手が無いのに 0 で終わると、通ったと読める | 非0 |

`command`（文字列）と `arguments`（配列）の両方の形を使っている。
どちらも clang の仕様が認めており、生成する道具によって分かれる。
