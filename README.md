# dowel_examples

[dowel](https://github.com/sabas0ba/dowel) で組む C/C++ プロジェクトを集めたもの。
利用例であると同時に、外側から dowel を検査するテストスイートである。

dowel 本体は自分自身を内側から検査している（`crates/*/tests/`、`tests/projects/`）。
本リポジトリが受け持つのは、そこから見えない側である。すなわち、
**本体のソースを一切参照せず、公開されたコマンドと診断コードだけを使って
利用者と同じ立場から確かめる**こと。実装の内部を知らないため、
仕様と実装の食い違いを仕様の側から見つけられる。

見つけたものは [docs/10-findings.md](docs/10-findings.md) に記録し、本体へ報告する。
これまでに 24 件を報告し、19 件が修正された。

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

必要なもの: C コンパイラ（`cc`）、`ninja`、`jq`、`python3`、`git`、`cargo`、
bash 4 以降。

C++ とクロスの層は `g++` / `clang++` / `aarch64-linux-gnu-g++` /
`qemu-aarch64-static` も要る。`cc` だけで走らせると、実際に検査されるのは
その機械の既定のコンパイラ1つだけになる。移行の層（`16-migrate`）は移行元を
組み立てるために `cmake` を、依存の層（`17-deps`）はシステムパッケージの解決先
として `pkg-config` を、道具の層（`18-tools` / `19-artifacts`）は `gcc-ar` と
`objcopy`（クロスの側も）を使う。

`09-acquisition` は `dowelup` と dowel の**作業木**も要る。取得を検査する層で
あり、上流にあたる git リポジトリを手元へ複製して相手にするためである
（実際の上流には触れない）。既定では `dowel` の隣と `../dowel` を探す。

```sh
DOWELUP=/path/to/dowelup DOWEL_SRC=/path/to/dowel ./run.sh
```

見つからなければ始めない。環境によって走る検査が変わると、結果を過去の実行と
比べられなくなる。

プロジェクトの実体は変更しない。`.work/` へ複製してから走らせる。
集計の結果は `.work/report/`（`summary.md` / `results.json` / `index.html`）に残る。

## 出力

1 検査 1 行。本体が直していない事項に対する検査は `xfail` として登録する。
本体側が直ると `XPASS` になって落ち、宣言を外すべきことが分かる。現在は 6 件で、
[F-011](docs/10-findings.md#f-011) の残っている側、
[F-020](docs/10-findings.md#f-020) の残っている側（検査の道具）、
[F-022](docs/10-findings.md#f-022)、[F-023](docs/10-findings.md#f-023)、
[F-024](docs/10-findings.md#f-024) に対応する。

```
02-config
  ok   app: check passes
  ok   private flags of a dependency never reach a dependent

07-robustness
  ok   unclosed-paren is refused with a source location
  ok   100k nested arrays is refused as nesting-too-deep

11-cross
  ok   the cross tests run under the emulator and pass
  ok   an artifact filed under a triple is built for that triple

apps/jsonfmt
  ok   including a private header of the library does not compile
  xfail running the tests does not make the next build redo work  [F-024]

total 893 checks: 887 passed, 0 failed, 6 known, 0 fixed
```

検査名は英語で書く。実装の中身ではなく、何が固定されているかを1行で読ませる
ためのものであり、CI の要約と掲示にもそのまま並ぶ（[docs/00-design.md](docs/00-design.md) 6節）。

## プロジェクト

| プロジェクト | 何を固定するか |
|---|---|
| [01-minimal](projects/01-minimal/) | 最小のマニフェスト。ビルドディレクトリの分離、実行器の等価性 |
| [02-config](projects/02-config/) | `match` / 後置 `when` の具体化。公開と非公開の分離 |
| [03-features](projects/03-features/) | 機能フラグによる依存の辺の出現と消失。任意の依存 |
| [04-diagnostics](projects/04-diagnostics/) | 誤ったマニフェストに対する応答。診断コードと位置と修正提案 |
| [05-incremental](projects/05-incremental/) | 編集してからの再ビルド。depfile、波及の範囲、テストの再実行 |
| [06-runner](projects/06-runner/) | `[runner.<triple>]`。宣言が無いときの拒否、引数の形、転送 |
| [07-robustness](projects/07-robustness/) | 壊れた入力に対する応答の形。abort しないこと、位置つきで拒むこと |
| [08-lsp](projects/08-lsp/) | 言語サーバ。CLI との一致、UTF-16 の桁、ホバー、壊れた JSON-RPC |
| [09-acquisition](projects/09-acquisition/) | `dowelup`。版の選択順、pin ファイル、指定子の解決、失敗した取得 |
| [10-toolchain](projects/10-toolchain/) | gcc と clang の双方。宣言が起動に届くか、成果物が宣言どおりか |
| [11-cross](projects/11-cross/) | 本物のクロスコンパイル。翻訳先が変わること、qemu 経由の実行 |
| [12-store](projects/12-store/) | プロセスを跨いだ復元。変更の検出、壊れたストアが答を変えないこと |
| [13-parallel](projects/13-parallel/) | `--test-jobs`。既定が逐次であること、表示順、失敗の扱い |
| [14-scale](projects/14-scale/) | 規模。増分の費用が木の大きさではなく変更の大きさに比例すること |
| [15-cpp](projects/15-cpp/) | C++。拡張子による選択、依存の閉包で決まるリンク、実行時が本当に繋がること |
| [16-migrate](projects/16-migrate/) | 既存のビルドからの移行。下書きに何が写るか、写した結果が同じ翻訳になるか |
| [17-deps](projects/17-deps/) | システムパッケージへの依存。pkg-config への委譲、版の下限、`dowel.lock` の漂流検出 |
| [18-tools](projects/18-tools/) | ツールチェーンの道具。宣言・語彙・実在確認・記録・トリプルごとの選択 |
| [19-artifacts](projects/19-artifacts/) | 成果物から別の成果物を作る。生イメージと HEX、命令の形、増分、クロス |

## アプリケーション

`projects/` が dowel の約束を1つずつ固定するのに対し、`apps/` が見るのは
**それらを組み合わせて本物を書けるか**である。分野ごとに実際に書くであろう
形のプログラムを置き、dowel で組んで走らせる。

| アプリ | 分野 | 外部依存 |
|---|---|---|
| [jsonfmt](apps/jsonfmt/) | 依存を持たない CLI。解析と整形 | 無し |

ここで見つかるものは、最小の構成では現れない。実際、
[F-023](docs/10-findings.md#f-023) はパッケージを跨いだ機能名を使って初めて、
[F-024](docs/10-findings.md#f-024) は `test` と `build` を交互に打って初めて出た。

プロジェクトのほかに `docs` の段がある。文書が引用する検査名が実在するか、
リンクが解決するか、索引が中身と一致するかを機械的に見る。文書の不整合は
スイートの実行に影響しないため、検査しない限り検出されない。

設計と規約は [docs/00-design.md](docs/00-design.md) にある。

## CI

`main` への押し込み、pull request、手動実行で走る。dowel は
`sabas0ba/dowel` から取り出してその場で組み立てる。公開リポジトリであるため
設定する秘密はひとつも無い。

検証に用いる版は [`dowel-ref`](dowel-ref) にコミットで固定してある。枝を指すと、
本リポジトリを何も変えていないのに結果が動き、赤がこちらの退行なのか本体の変更
なのかを区別できなくなる。追随はこの1行を書き換える pull request として現れる。

結果は3か所に出る。ジョブ要約（直近の実行）、成果物（30 日保持）、
そして掲示用の枝 `gh-pages` に積んだ表である。掲示には検査の全件と、
それぞれが置かれた実体へのリンク、そして過去 100 回分の履歴が並ぶ。手動実行では
`dowel_ref` を渡せるため、本体の修正が本スイートの検査を
どう動かすかを、固定値を書き換える前に確かめられる。

準備と設定は [docs/20-ci.md](docs/20-ci.md) にある。

## 文書

| 文書 | 内容 |
|---|---|
| [docs/00-design.md](docs/00-design.md) | スイートの設計。層の分け方、検査の置き場所、書き方の規約 |
| [docs/10-findings.md](docs/10-findings.md) | 本スイートが見つけたもの。報告状況と、対応する検査 |
| [docs/20-ci.md](docs/20-ci.md) | CI の準備と構成。掲示用の枝と表の読み方 |
