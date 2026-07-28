# dowel_examples

[dowel](https://github.com/sabas0ba/dowel) で組む C/C++ プロジェクトを集めたもの。
利用例であると同時に、外側から dowel を検査するテストスイートである。

dowel 本体は自分自身を内側から検査している（`crates/*/tests/`、`tests/projects/`）。
本リポジトリが受け持つのは、そこから見えない側である。すなわち、
**本体のソースを一切参照せず、公開されたコマンドと診断コードだけを使って
利用者と同じ立場から確かめる**こと。実装の内部を知らないため、
仕様と実装の食い違いを仕様の側から見つけられる。

見つけたものは [docs/10-findings.md](docs/10-findings.md) に記録し、本体へ報告する。

## 走らせる

```sh
make verify              # 全プロジェクト + 集計。CI もこれと同じものを実行する
./run.sh                 # 検査だけ
./run.sh 02-config       # 名前（接頭辞）で絞る
```

`dowel` の探索順は、環境変数 `DOWEL` → `PATH` → `../dowel/target/release/dowel`。

```sh
DOWEL=/path/to/dowel make verify
```

必要なもの: C コンパイラ（`cc`）、`ninja`、`jq`、`python3`、bash 4 以降。

プロジェクトの実体は変更しない。`.work/` へ複製してから走らせる。
集計の結果は `.work/report/`（`summary.md` / `results.json` / `index.html`）に残る。

## 出力

1 検査 1 行。既知の未修正事項に対する検査は `xfail` として登録してある。
本体側が直ると `XPASS` になって落ち、この宣言を外すべきことが分かる。

```
02-config
  ok   app: check が通る
  ok   依存の非公開フラグは依存元の引数に現れない

04-diagnostics
  xfail 修正提案を適用したマニフェストが check を通る  [F-006]

合計 89 件: 成功 80 / 失敗 0 / 既知の未修正 9 / 修正済み 0
```

## プロジェクト

| プロジェクト | 何を固定するか |
|---|---|
| [01-minimal](projects/01-minimal/) | 最小のマニフェスト。ビルドディレクトリの分離、実行器の等価性 |
| [02-config](projects/02-config/) | `match` / 後置 `when` の具体化。公開と非公開の分離 |
| [03-features](projects/03-features/) | 機能フラグによる依存の辺の出現と消失。任意の依存 |
| [04-diagnostics](projects/04-diagnostics/) | 誤ったマニフェストに対する応答。診断コードと位置と修正提案 |

設計と規約は [docs/00-design.md](docs/00-design.md) にある。

## CI

`main` への押し込み、pull request、手動実行で走る。dowel は
`sabas0ba/dowel` から取り出してその場で組み立てる。非公開リポジトリであるため
読み取り専用のデプロイキー（`DOWEL_DEPLOY_KEY`）が要る。

検証に用いる版は [`dowel-ref`](dowel-ref) にコミットで固定してある。枝を指すと、
本リポジトリを何も変えていないのに結果が動き、赤がこちらの退行なのか本体の変更
なのかを区別できなくなる。追随はこの1行を書き換える pull request として現れる。

結果は3か所に出る。ジョブ要約（直近の実行）、成果物（30 日保持）、
そして掲示用の枝 `gh-pages` に積んだ履歴の表である。手動実行では
`dowel_ref` を渡せるため、本体の修正が本スイートの `xfail` を
`xpass` に変えるかどうかを、固定値を書き換える前に確かめられる。

準備と設定は [docs/20-ci.md](docs/20-ci.md) にある。

## 文書

| 文書 | 内容 |
|---|---|
| [docs/00-design.md](docs/00-design.md) | スイートの設計。層の分け方、検査の置き場所、書き方の規約 |
| [docs/10-findings.md](docs/10-findings.md) | 本スイートが見つけたもの。報告状況と、対応する検査 |
| [docs/20-ci.md](docs/20-ci.md) | CI の準備と構成。掲示用の枝と表の読み方 |
