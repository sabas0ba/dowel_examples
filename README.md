# dowel_examples

[dowel](https://github.com/sabas0ba/dowel) で組む C/C++ プロジェクトを集めたもの。
利用例であると同時に、外側から dowel を検査するテストスイートである。

dowel 本体は自分自身を内側から検査している（`crates/*/tests/`、`tests/projects/`）。
本リポジトリが受け持つのは、そこから見えない側である。すなわち、
**本体のソースを一切参照せず、公開されたコマンドと診断コードだけを使って
利用者と同じ立場から確かめる**こと。実装の内部を知らないため、
仕様と実装の食い違いを仕様の側から見つけられる。

見つけたものは [docs/10-findings.md](docs/10-findings.md) に記録し、本体へ報告する。
これまでに 57 件を報告し、54 件が修正された。

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

層によっては、それ以上のものが要る。**足りなければ `run.sh` は始めない。**
環境によって走る検査が変わると、結果を過去の実行と比べられなくなる。

| 層 | 要るもの | なぜ |
|---|---|---|
| `10-toolchain` `15-cpp` | `g++` `clang` `clang++` | `cc` だけだと、実際に検査されるのはその機械の既定の1つになる |
| `11-cross` `15-cpp` | `aarch64-linux-gnu-gcc` / `-g++`、`qemu-aarch64-static` | 本物のクロスと、組んだものの実行 |
| `16-migrate` | `cmake`、`meson` | 移行元を実際に構成する。渡す情報の形が違うので両方要る |
| `17-deps` | `pkg-config` | システムパッケージの解決先 |
| `18-tools` `19-artifacts` | `gcc-ar`、`objcopy`、`readelf`（クロスの側も） | 道具の宣言が届くこと、変換が走ったこと |
| `apps/blink` | `arm-none-eabi-gcc`、`qemu-system-arm` | ベアメタルを組み、**それを実際に走らせる** |
| `apps/plot` | cairo / X11、`xvfb-run` | 描いて、**本当に窓を開く** |
| `apps/vision` | OSMesa、OpenCV | 表示の無い機械でも GL の文脈を作れるので、描いたものを読み返せる |
| `apps/winapp` | `x86_64-w64-mingw32-gcc`、`wine`、`file` | Windows 向けに組み、**それを走らせる** |
| `apps/dsp` | `riscv64-linux-gnu-gcc`、`qemu-riscv64-static` | 1つの算法を4つの三つ組で走らせ、**同じ答が出ること**を見る |

Debian と Ubuntu では、`run.sh` が足りないものを見つけたときに
`apt-get` の1行を出す。

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
本体側が直ると `XPASS` になって落ち、宣言を外すべきことが分かる。現在は 4 件で、
[F-011](docs/10-findings.md#f-011) の残っている側と、新機能を使ってみて出た
[F-056](docs/10-findings.md#f-056)（共有ライブラリ）と
[F-057](docs/10-findings.md#f-057)（Meson からの移行）である。

直前の回では 16 件あった。デバッグ機能について見つけた
[F-046](docs/10-findings.md#f-046) から [F-049](docs/10-findings.md#f-049)、
実践的なアプリケーションを書く過程で見つけた
[F-050](docs/10-findings.md#f-050) から [F-055](docs/10-findings.md#f-055) が
`9858932` でまとめて修正され、検査は**新しい機構を実際に使う形へ**書き換えた。

直った所見の検査は `known_issue` を外すだけでは足りない。**新しい機構を実際に
使う形へ書き換える**。書き換えないと、直ったことを確かめたことにならない。

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

apps/blink
  ok   and the firmware runs on emulated hardware and its test passes

apps/hashx
  ok   the archive exports exactly the names the header marks as the API
  xfail a dependency entry that names two sources is refused  [F-029]

apps/plot
  ok   the windowed build runs against a real X server
  ok   and the first pixel is exactly the background colour the header declares

20-cases
  ok   cases add no translation unit; five of them share one binary
  ok   the binary lists its own cases and each runs as its own test

21-debug
  ok   a breakpoint set through dowel stops the program where the source says
  ok   a cross debug session attaches to the declared stub address

total 1146 checks: 1141 passed, 0 failed, 5 known, 0 fixed
```

検査名は英語で書く。実装の中身ではなく、何が固定されているかを1行で読ませる
ためのものであり、CI の要約と掲示にもそのまま並ぶ（[docs/00-design.md](docs/00-design.md) 6節）。

## 育ち方

各回の結果は掲示用の枝に積んである。数の並びとしては読めるが、**どこで何が
伸びたか**は 100 行の数字を辿っても分からない。図はそのために描く。CI が
実行のたびに描き直し、掲示の頁の `Growth` にも同じものが出る。

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/sabas0ba/dowel_examples/gh-pages/history-dark.svg">
  <img alt="検査数の推移。上段は総数を projects/ と apps/ と docs に分けた積み上げ、中段は xfail と fail と xpass の推移、下段は層ごとの小さな面を縦軸を共有して並べたもの。" src="https://raw.githubusercontent.com/sabas0ba/dowel_examples/gh-pages/history.svg">
</picture>

上段が総数で、検査がどこに置かれているか（`projects/` `apps/` `docs`）で
分けてある。中段は `xfail` / `fail` / `xpass` の推移であり、
[docs/20-ci.md](docs/20-ci.md) 4節が「見たいのは列の動きである」と言うその列を
そのまま線にしたものである。下段は層ごとに1枚。縦軸を共有するため、**いつ
現れたか**と**どれだけの大きさか**の双方が同じ絵から読める。

層は 32 あり、色で見分けられる数を超えている。積み上げの色は系統3つにだけ
使い、層ごとの内訳は面を並べて示す。色数を増やして解こうとすると、どの色も
見分けられなくなる。

図が示す数はすべて掲示の `History` に表として並ぶ。図は読み方をひとつ足すだけ
であり、値へ辿る唯一の経路ではない。

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
| [20-cases](projects/20-cases/) | 1本の実行ファイルから複数のテストを登録する。宣言・選択・時間切れ・語彙 |
| [21-debug](projects/21-debug/) | 宣言されたデバッガとスタブ。本物の gdb で止め、--dap が同じ事実を書き出すこと |
| [22-bench](projects/22-bench/) | 測るための種別。速さに判定は無く、走り切れなければ数を出さないこと |
| [23-probe](projects/23-probe/) | 道具に訊いたことを利用者の cache へ。訊き直さず、道具を替えれば鍵が変わること |

## アプリケーション

`projects/` が dowel の約束を1つずつ固定するのに対し、`apps/` が見るのは
**それらを組み合わせて本物を書けるか**である。分野ごとに実際に書くであろう
形のプログラムを置き、dowel で組んで走らせる。

| アプリ | 分野 | 外部依存 |
|---|---|---|
| [jsonfmt](apps/jsonfmt/) | 依存を持たない CLI。解析と整形 | 無し |
| [httpd](apps/httpd/) | システムプログラミング。ソケット、シグナル、待ち方の選択 | 無し（libc のみ） |
| [blink](apps/blink/) | 組み込み。Cortex-M4F のベアメタル、ベクタ表、書き込み用の像、qemu 上での実行 | 無し（`arm-none-eabi`） |
| [hashx](apps/hashx/) | ライブラリ。配る側。面の可視性、C と C++ の双方の利用者、出所の切り替え | 無し |
| [plot](apps/plot/) | GUI。描画と窓の分離、任意の依存、Xvfb の上で本当に窓を開く | cairo / X11 |
| [vision](apps/vision/) | 大きい依存。1つの `.pc` が 55 個のリンク旗を出す。C++ の中身に C の面 | OSMesa / OpenCV |
| [winapp](apps/winapp/) | Windows。対象ごとの実装、`.exe` の綴り、wine で走らせる、MSVC の族 | 無し（`mingw` / `wine`） |
| [dsp](apps/dsp/) | 1つの算法を4つの三つ組で。x86_64 / ARM / RISC-V / ベアメタル、同じ期待値 | cairo（見せる側だけ） |

どれも**組めたことでは終わらせない**。整形結果は文字単位で見て、サーバには
本物のソケットで接続し、ファームウェアは qemu の上で走らせる。加えて、
計装（ASan / UBSan）を機能フラグとして宣言した版を組み、壊れた入力と壊れた
要求を実際に食わせて、落ちないことと未定義動作を踏まないことを見る。

**ここで見つかるものは、最小の構成では現れない。** 報告した 57 件のうち
17 件がこの層から出ており、どれも「最小の構成には置く理由が無い」形をして
いる——パッケージを跨いだ機能名、`test` と `build` を交互に打つ流れ、
実行ファイルに拡張子が付く対象、配るライブラリが自分の検査を持っていること。

条件が2つ重なって初めて現れるものもある。
[F-054](docs/10-findings.md#f-054) と [F-055](docs/10-findings.md#f-055) は
**パッケージが分かれていて、かつ三つ組が複数ある**ときにしか出ない。
一覧と、それぞれが最小の構成で現れない理由は
[docs/00-design.md](docs/00-design.md) 7節にある。

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
それぞれが置かれた実体へのリンク、過去 100 回分の履歴、そしてその図が並ぶ。手動実行では
`dowel_ref` を渡せるため、本体の修正が本スイートの検査を
どう動かすかを、固定値を書き換える前に確かめられる。

準備と設定は [docs/20-ci.md](docs/20-ci.md) にある。

## 文書

| 文書 | 内容 |
|---|---|
| [docs/00-design.md](docs/00-design.md) | スイートの設計。層の分け方、検査の置き場所、書き方の規約 |
| [docs/10-findings.md](docs/10-findings.md) | 本スイートが見つけたもの。報告状況と、対応する検査 |
| [docs/20-ci.md](docs/20-ci.md) | CI の準備と構成。掲示用の枝と表の読み方 |
