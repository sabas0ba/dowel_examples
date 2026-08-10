# 所見

本スイートが外側から見つけたもの。

F-001 から F-009 までの 9 件は `07f16ec` で、F-010 / F-012 / F-013 は
`95daf9f` で、F-014 / F-015 は `3e84cbd` で、F-016 / F-017 は `a9c1619` で、
F-018 / F-019 / F-021 は `af7d391` で修正された。F-008 はさらに `9ed13f4` で
二段目の決着を見ている。記録は残す。
何を見てどう報告したかが、次に同種のものを見つけるときの型になるためである。
対応する検査は `known_issue` を外し、通常の検査として残してある。直った
ものを消すと、退行したときに気づけない。

F-020 の残っていた側（検査の道具）と F-022 から F-031 までは、`dowel-ref` を
`17bd54e` へ進めた回でまとめて修正が入った。対応する検査は `known_issue` を
外し、**新しい機構を実際に使う形へ書き換えて**通常の検査として残してある。
書き換えないと、直ったことを確かめたことにならない。

未修正は F-011 の残っている側だけである。対応する検査は `known_issue` を
付けてあり、本体が直すと `XPASS` になって落ちる。

各項目は次の形で記録する。

- **観測** — 何をしたら何が起きたか（`a8a59e7` 時点）
- **期待** — 何を期待したか。および、その期待の根拠（本体の文書）
- **なぜ内側から見つからないか** — 本体の既存の層では原理的に現れない理由
- **修正** — どう直ったか（`07f16ec` 時点）
- **検査** — 本スイートのどの検査が対応するか

## 一覧

| # | 内容 | 種別 | 報告先 | 状態 |
|---|---|---|---|---|
| [F-001](#f-001) | 宣言されていない機能名を `--features` に渡しても診断が出ない | 実装 | [#14](https://github.com/sabas0ba/dowel/issues/14) | 修正済み |
| [F-002](#f-002) | `dowel.build` の `feature.<未宣言>` が黙って偽になる | 実装 | [#13](https://github.com/sabas0ba/dowel/issues/13) | 修正済み |
| [F-003](#f-003) | 有効化されていない `optional` 依存が読み込まれる | 実装 | [#15](https://github.com/sabas0ba/dowel/issues/15) | 修正済み |
| [F-004](#f-004) | `check` が計画段の誤りを見つけない | 実装／文書 | [#19](https://github.com/sabas0ba/dowel/issues/19) | 修正済み |
| [F-005](#f-005) | `missing-manifest` に位置情報が無い | 実装 | [#18](https://github.com/sabas0ba/dowel/issues/18) | 修正済み |
| [F-006](#f-006) | 修正提案の範囲が誤っており、適用するとマニフェストが壊れる | 実装 | [#12](https://github.com/sabas0ba/dowel/issues/12) | 修正済み |
| [F-007](#f-007) | 併合衝突の人間向け描画が片側の位置しか出さない | 実装 | [#16](https://github.com/sabas0ba/dowel/issues/16) | 修正済み |
| [F-008](#f-008) | C++ のソースが黙って受理され、リンカの誤りになる | 実装／文書 | [#19](https://github.com/sabas0ba/dowel/issues/19) | 修正済み |
| [F-009](#f-009) | 宣言したツールチェーンの実在を確認しない | 実装 | [#19](https://github.com/sabas0ba/dowel/issues/19) | 修正済み |
| [F-010](#f-010) | 深い入れ子でスタックが溢れ、診断を出さずに abort する | 実装 | [#33](https://github.com/sabas0ba/dowel/issues/33) | 修正済み |
| [F-011](#f-011) | UTF-8 BOM 付きのマニフェストが拒まれる | 実装 | [#34](https://github.com/sabas0ba/dowel/issues/34) | 一部修正 |
| [F-012](#f-012) | 言語サーバが型検査の段の診断を出さず、`UNSUPPORTED` にも無い | 実装 | [#38](https://github.com/sabas0ba/dowel/issues/38) | 修正済み |
| [F-013](#f-013) | install に使った指定子で `dowel +<指定子>` が選べない | 実装 | [#39](https://github.com/sabas0ba/dowel/issues/39) | 修正済み |
| [F-014](#f-014) | ninja で組んだあと direct で組むと、ヘッダの変更が見落とされる | 実装 | [#41](https://github.com/sabas0ba/dowel/issues/41) | 修正済み |
| [F-015](#f-015) | `--target` がツールチェーンを選ばない | 実装 | [#42](https://github.com/sabas0ba/dowel/issues/42) | 修正済み |
| [F-016](#f-016) | `ar` を宣言できず、記録された入力にもなっていない | 要望 | [#50](https://github.com/sabas0ba/dowel/issues/50) | 修正済み |
| [F-017](#f-017) | `migrate import` が CMake の構成のフラグを無条件の `flags` へ写す | 実装 | [#54](https://github.com/sabas0ba/dowel/issues/54) | 一部修正 |
| [F-018](#f-018) | `lib` の `private` な `link_flags` がリンクの閉包に乗らない | 実装 | [#56](https://github.com/sabas0ba/dowel/issues/56) | 修正済み |
| [F-019](#f-019) | `[toolchain]` の未知のキーが黙って受理され、道具が既定値へ後退する | 実装 | [#59](https://github.com/sabas0ba/dowel/issues/59) | 修正済み |
| [F-020](#f-020) | 生成物を変換・検査する道具を宣言できず、後処理の場所も無い | 要望 | [#60](https://github.com/sabas0ba/dowel/issues/60) | 修正済み |
| [F-021](#f-021) | 構成レベルのフラグが `link_flags` には残り、下書きの見出しと食い違う | 実装 | [#61](https://github.com/sabas0ba/dowel/issues/61) | 修正済み |
| [F-022](#f-022) | `lib` の `artifacts` が、依存する `bin` を足すと作られなくなる | 実装 | [#64](https://github.com/sabas0ba/dowel/issues/64) | 修正済み |
| [F-023](#f-023) | 転送した機能名の `/` がビルドディレクトリを2階層に割る | 実装 | [#68](https://github.com/sabas0ba/dowel/issues/68) | 修正済み |
| [F-024](#f-024) | 狭い呼び出しが記録を上書きし、次の広い呼び出しがやり直す | 実装 | [#69](https://github.com/sabas0ba/dowel/issues/69) | 修正済み |
| [F-025](#f-025) | `link_flags` からパッケージ相対のファイルを指せない | 実装 | [#70](https://github.com/sabas0ba/dowel/issues/70) | 修正済み |
| [F-026](#f-026) | パッケージが対象とする triple を宣言できない | 要望 | [#71](https://github.com/sabas0ba/dowel/issues/71) | 修正済み |
| [F-027](#f-027) | `dowel.toml` に置いた `[runner.<triple>]` が黙って無視される | 実装 | [#74](https://github.com/sabas0ba/dowel/issues/74) | 修正済み |
| [F-028](#f-028) | `abi` の `must_equal` により、C のライブラリを C++ から使えない | 実装／設計 | [#78](https://github.com/sabas0ba/dowel/issues/78) | 修正済み |
| [F-029](#f-029) | 依存が出所を2つ名乗っても無診断で受理され、黙って `path` が勝つ | 実装 | [#79](https://github.com/sabas0ba/dowel/issues/79) | 修正済み |
| [F-030](#f-030) | パッケージの `version` を翻訳へ届ける手立てが無い | 要望 | [#80](https://github.com/sabas0ba/dowel/issues/80) | 修正済み |
| [F-031](#f-031) | 排他な機能を宣言できず、`lib` では黙って片方の実装が勝つ | 要望 | [#82](https://github.com/sabas0ba/dowel/issues/82) | 修正済み |

---

## F-006

報告先: [sabas0ba/dowel#12](https://github.com/sabas0ba/dowel/issues/12)

**修正提案の範囲が key-value 全体を覆っており、適用するとマニフェストが壊れる。**

種別: 実装。本一覧のうち最も影響が大きい。誤りを直そうとして別の誤りを作る。

### 観測

```
[bin.t.private]
include = [dir("src")]
```

```json
{"code":"unknown-property",
 "suggestions":[{"byte_start":141,"byte_end":163,
                 "replacement":"includes","message":"did you mean `includes`?"}]}
```

`141..163` は `include = [dir("src")]` の 22 バイト全体である。置換文字列は
`includes` だけであるため、適用すると次のようになる。

```
[bin.t.private]
includes
```

値が消え、構文としても成立しない。人間向けの描画に出る

```
   = help: did you mean `includes`? — `includes`
```

の重複した見え方も、同じ範囲指定に由来する。

### 期待

範囲は誤った鍵（`include`、7 バイト）だけを覆う。適用結果は
`includes = [dir("src")]` となり、もう一度 `check` を通る。

根拠: `docs/91-implementation-status.md` は診断の要素として
「機械適用可能な修正提案」を挙げている。適用できないものは
機械適用可能ではない。

### なぜ内側から見つからないか

`crates/dowel-cli/tests/diagnostics.rs` は診断コードの網羅を追跡しており、
提案の**存在**は検査できる。しかし提案を実際に適用して再検査する経路は無い。
範囲の誤りは、適用して初めて現れる。

### 修正

提案の範囲が誤った鍵だけを覆うようになった（`141..148` の 7 バイト）。

```json
{"byte_start":141,"byte_end":148,"replacement":"includes","message":"did you mean `includes`?"}
```

適用結果は `includes = [dir("src")]` となり、もう一度 `check` を通る。

### 検査

`projects/04-diagnostics` の `the manifest still passes check after applying the suggestion` と
`applying the suggestion keeps the value intact`。
`lib/apply_fix.py` が JSON の提案を書き戻し、もう一度 `check` を掛ける。

---

## F-002

報告先: [sabas0ba/dowel#13](https://github.com/sabas0ba/dowel/issues/13)

**`dowel.build` から宣言されていない機能を参照しても診断が出ず、黙って偽になる。**

種別: 実装。綴り間違いが無言で分岐を落とす。

### 観測

```toml
# dowel.toml
[features]
default = []
real    = []
```

```
# dowel.build
flags = ["-DALWAYS=1", "-DTYPO=1" when feature.raal]
```

`check passed`。`feature.raal` は偽と評価され、`-DTYPO=1` が落ちる。

同じ位置で `cfg.nosuchkey` を書くと `unknown-cfg-key` で落ちる。
語彙の閉じ方が名前空間ごとに非対称である。

### 期待

`unknown-feature` として落ちる。編集距離による候補（`real`）を添える。

根拠: `docs/99-open-questions.md` Q1 の「実装が用いている暫定語彙」の表は、
`feature.<name>` の値域を「真偽（`dowel.toml` の `[features]` で宣言された
もののみ）」と定めている。宣言されていない名前は値域の外である。
未知の名前に候補を出すことは `docs/91-implementation-status.md` の
診断の節に挙げられている。

### なぜ内側から見つからないか

単体テストは「宣言された機能が正しく解決される」ことを検査する。
宣言されていない名前は入力として想定されないため、検査の対象にならない。
外から見ると、これは利用者が最も踏みやすい入力である。

### 修正

`unknown-feature` として落ちるようになった。候補も出る。

```
error[unknown-feature]: unknown feature `raal`
 --> dowel.build:8:40
  |
8 | flags = ["-DALWAYS=1", "-DTYPO=1" when feature.raal]
  |                                        ^^^^^^^^^^^^ this feature is not declared in `dowel.toml`
   = note: `[features]` declares: real
   = help: did you mean `real`? — `feature.real`
```

### 検査

`projects/03-features` の
`an undeclared feature referenced from dowel.build is rejected`。

---

## F-001

報告先: [sabas0ba/dowel#14](https://github.com/sabas0ba/dowel/issues/14)

**宣言されていない機能名を `--features` に渡しても診断が出ない。**

種別: 実装。F-002 と同じ根、CLI 側の入口。

### 観測

```sh
dowel check --features=nosuchfeature      # check passed
```

さらに、渡した名前はビルドディレクトリの識別子に入る。綴り間違いのたびに
別の構成としてビルドディレクトリが増え、キャッシュが無効化される。

### 期待

`unknown-feature` として落ちる。候補を添える。

根拠: F-002 と同じ。加えて `docs/91-implementation-status.md` は
編集距離による候補提示の対象に「CLI のオプションとコマンド」を挙げており、
CLI 引数の検証は行われる建て付けになっている。

### 修正

同じく `unknown-feature` で落ちる。名前がどこから来たかも注記に出る。

```
error[unknown-feature]: unknown feature `nosuchfeature`
 --> dowel.toml:7:1
   = note: `[features]` declares: json, xml
   = note: `nosuchfeature` came from `--features`
```

CLI から来た名前をマニフェストの `[features]` の位置で示すのは、
直す先がそちらであるため妥当である。

### 検査

`projects/03-features` の
`an undeclared feature passed to --features is rejected`。

---

## F-008

報告先: [sabas0ba/dowel#19](https://github.com/sabas0ba/dowel/issues/19)

**C++ のソースが黙って受理され、リンカの `undefined reference` になる。**

種別: 実装、または文書。dowel が「C/C++ を主対象とする」と述べている以上、
どちらであるかの判断が要る。

### 観測

```
[bin.t]
sources = glob("src/*.cpp")
```

`.cpp` は `cc` に渡され、コンパイルは通る（gcc/clang の driver が拡張子で
判別するため）。リンクは `cc` のまま行われ、C++ 標準ライブラリが付かない。

```
undefined reference to `std::__cxx11::basic_string<...>::c_str() const'
```

`build` は 0 以外を返すが、返しているのは ninja であり、
`--message-format=json` に診断は1件も出ない。利用者が手にするのは
リンカの出力だけで、マニフェストのどこを直せばよいかを示すものが無い。

### 期待

いずれか。

1. C++ を組めるようにする（`tc.cxx`、拡張子によるコンパイラの選択、
   C++ を含むターゲットのリンカ選択）
2. 組めないなら、`invalid-source` と同種の診断で、
   `sources` の当該要素の位置とともに拒む

短期には 2 が妥当と考える。`docs/51-testing.md` が
`invalid-source` / `unresolved-path` を足した経緯として挙げているのは、
まさに「下流の道具の誤りになり、マニフェストの原因箇所を示さない」ことであった。
`.cpp` は同じ形の3例目である。

あわせて `docs/91-implementation-status.md` の
「未実装（意識的に後回しにしているもの）」に C++ の項目が無い。
現状では、読み手は C++ が組めると読める。

### なぜ内側から見つからないか

本体のフィクスチャと e2e は全て C で書かれている。C++ のソースは
入力として一度も現れない。

### 修正（2段階）

まず `unsupported-language` として `check` の段で落ちるようになった。
挙げた2案のうち短期の案（診断で拒む）であり、`build` を待たずに出る点は
期待より進んでいた。

```
error[unsupported-language]: `src/main.cpp` is a C++ source
 --> dowel.build:4:11
  |
4 | sources = glob("src/*.cpp")
  |           ^^^^^^^^^^^^^^^^^ C++ cannot be built yet
   = note: the C driver would compile it but link without the C++ runtime
   = note: C++ support is not implemented (docs/91-implementation-status.md)
```

注記が「C の driver なら通るが C++ 実行時が付かない」という失敗の形まで
説明している。同じ罠を別の経路で踏んだ利用者にも効いた。

その後 `9ed13f4` で**もう一方の案（C++ を組めるようにする）**が入り、
`unsupported-language` は出なくなった。拡張子ごとにコンパイラを選び、
`tc.cxx` を構成の語彙に加え、**依存の閉包に C++ の翻訳単位があれば
リンクも C++ の driver で行う**。最後の点が本件の失敗様式そのものへの
答であり、純 C の実行ファイルでも C++ の実行時が繋がる。

### 検査

`projects/15-cpp` が受け持つ。とくに
`but the link uses the C++ driver because a dependency is C++` と
`the link never fails the way F-008 did` が本件に対応する。

`projects/04-diagnostics` からは `unsupported-language` の事例を外した。
出なくなった診断を検査に残すと、実在しない約束を固定することになる。

---

## F-009

報告先: [sabas0ba/dowel#19](https://github.com/sabas0ba/dowel/issues/19)

**宣言したツールチェーンの実在を確認しない。**

種別: 実装。F-008 と同じ形。

### 観測

```toml
[toolchain]
c = "no-such-compiler-19"
```

`check passed`。`build` すると次のようになる。

```
/bin/sh: 1: no-such-compiler-19: not found
ninja: build stopped: subcommand failed.
```

`dowel.toml` の `[toolchain]` を指す診断は出ない。

### 期待

`check` の段で、`[toolchain] c` の位置を指して落ちる。

根拠: `docs/00-overview.md` 2節の目標に「再現性 — ツールチェーンを含めて
ロックし、記録されない入力を排除する」がある。固定した対象の実在は、
記録されない入力を排除する前提そのものである。

なお `plan.rs` には `toolchain-mismatch` の警告が既にあるが、これは
パッケージ間でツールチェーン指定が食い違う場合のものであり、
実在の確認とは別の検査である。

### 修正

`missing-toolchain` として、`check` の段で `[toolchain] c` の位置を指して落ちる。

```
error[missing-toolchain]: cannot find the C compiler `no-such-compiler-19`
  --> dowel.toml:10:1
   |
10 | c = "no-such-compiler-19"
   | ^^^^^^^^^^^^^^^^^^^^^^^^^ declared here
    = note: fetching toolchains is Phase 5 (docs/90-roadmap.md); until then it must be on PATH
```

注記が Phase 5 との関係を示しており、「いま取得されないのは未実装だからである」
ことが読み取れる。

### 検査

`projects/04-diagnostics` の `check reports missing-toolchain`、
`missing-toolchain points at the offending source`、
`a missing toolchain never reaches the shell`。

---

## F-007

報告先: [sabas0ba/dowel#16](https://github.com/sabas0ba/dowel/issues/16)

**併合の衝突で、人間向けの描画に片側の位置しか出ない。**

種別: 実装（描画層）。データは正しい。

### 観測

`defines` の衝突（`error_on_conflict`）に対する `--message-format=json`。

```json
{"code":"merge-conflict","labels":[
  {"primary":true, "file":".../lib/dowel.build","line":6,"message":"this one is 64"},
  {"primary":false,"file":".../app/dowel.build","line":8,"message":"the value that arrived first is 128"}]}
```

両方の来歴を持っている。ところが人間向けの描画は主ラベルのファイルしか出さない。

```
error[merge-conflict]: conflicting values reached `SHARED_LIMIT` of `defines`
 --> .../merge-conflict/lib/dowel.build:6:29
  |
6 | defines  = { SHARED_LIMIT = 64 }
  |                             ^^ this one is 64
   = note: the merge rule of `defines` is error_on_conflict
```

`app/dowel.build:8` は現れない。`abi-mismatch` も同じである。

### 期待

両方の位置を出す。併合の衝突では2つの値が必ず別のパッケージから来るため、
2つのラベルは必ず別のファイルにある。片側だけでは衝突の相手が分からず、
利用者は grep で探すことになる。

根拠: `docs/10-manifest.md` 3節。「`error_on_conflict` — 異なる値が
到達したら**両方の来歴を提示して**失敗する」。

rustc の描画は複数ファイルにまたがるラベルを出せる（`::: <path>` の形）。
書式を借りている以上、同じ形が取れるはずである。

### なぜ内側から見つからないか

単体テストは `Diagnostic` の構造を検査する。ラベルは2つあるので通る。
描画層の検査は、複数ファイルにまたがる診断を入力にしなければ現れない。

### 修正

rustc の `:::` の形で、別ファイルにある副ラベルも描かれるようになった。

```
error[merge-conflict]: conflicting values reached `SHARED_LIMIT` of `defines`
 --> .../merge-conflict/lib/dowel.build:6:29
  |
6 | defines  = { SHARED_LIMIT = 64 }
  |                             ^^ this one is 64
 ::: .../merge-conflict/app/dowel.build:8:28
  |
8 | defines = { SHARED_LIMIT = 128 }
  |                            --- the value that arrived first is 128
   = note: the merge rule of `defines` is error_on_conflict
```

### 検査

`projects/04-diagnostics` の `merge-conflict carries the location of both values` と
`merge-conflict renders the dependent side of the conflict too`。`abi-mismatch` も同じ形。

---

## F-004

報告先: [sabas0ba/dowel#19](https://github.com/sabas0ba/dowel/issues/19)

**`check` が計画段の誤りを見つけない。**

種別: 実装、または文書。どちらを直すかは設計の判断による。

### 観測

| 入力 | `check` | `build` |
|---|---|---|
| `sources = [dir("src")]` | `check passed` (0) | `invalid-source` (1) |
| `sources = [file("src/nope.c")]` | `check passed` (0) | `unresolved-path` (1) |
| `sources = glob("nosuchdir/*.c")` | `check passed` (0) | `empty-glob` + `no-sources` (1) |

### 期待

`check` は「評価と診断のみ。ビルドしない」と定められている
（`docs/60-cli.md`）。利用者はこれを、編集中や commit 前にマニフェストの
誤りを洗い出す入口として使う。ビルドできないマニフェストに対して
`check passed` と表示されるなら、その用途を満たさない。

一方で、glob 展開とパス解決を評価から外していることには明確な根拠がある
（`docs/10-manifest.md`。評価時に走査すると、その時点のファイルシステムという
記録されない入力が結果に混ざる）。したがって「評価の段で見つけろ」ではない。

取りうる形は2つ。

1. `check` が計画段まで走る（アクションは生成するが実行しない）。
   `dowel graph --kind=action` が既に同じことをしている
2. 文書に、`check` が覆う範囲と覆わない範囲を明記する。
   加えて `--no-run` に相当する入口を用意する

1 が利用者の期待に近い。`check` の所要時間は現状 1.5ms であり、
計画段を含めても起動予算（10ms）に収まると見込まれる。

### なぜ内側から見つからないか

`diagnostics.rs` の事例表は、各コードを発生させる最小の入力を
「どのコマンドで」発生させるかまでは固定していないと見られる。
`invalid-source` は `build` で発生することが確認されていれば網羅を満たす。
「`check` でも出るべきか」は、コードの一覧からは出てこない問いである。

### 修正

3件とも `check` で出るようになった。`build` でも同じコードが出る。

| 入力 | `check` | `build` |
|---|---|---|
| `sources = [dir("src")]` | `invalid-source` (1) | 同じ (1) |
| `sources = [file("src/nope.c")]` | `unresolved-path` (1) | 同じ (1) |
| `sources = glob("nosuchdir/*.c")` | `empty-glob` + `no-sources` (1) | 同じ (1) |

評価から glob 展開を外すという設計（記録されない入力を混ぜない）は保ったまま、
`check` が計画段まで進む形になったと見られる。両方の入口で同じコードが出ることは
検査で固定してある。

### 検査

`projects/04-diagnostics` の `check reports invalid-source` と
`build reports invalid-source as well`。`unresolved-path` と `empty-glob` も同じ形。

---

## F-003

報告先: [sabas0ba/dowel#15](https://github.com/sabas0ba/dowel/issues/15)

**有効化されていない `optional` 依存が読み込まれる。**

種別: 実装。現状の影響は小さいが、Phase 5 で影響が大きくなる。

### 観測

```toml
[features]
default = []
absent  = []

[[dependencies]]
name     = "absent"
path     = "../does-not-exist"
optional = true
```

```
# dowel.build
deps = [dep("absent") when feature.absent]
```

`feature.absent` は偽であり、アクショングラフに `absent` は現れない
（ここは正しい）。しかし `check` は失敗する。

```
error[missing-manifest]: cannot read .../does-not-exist/dowel.toml
```

また、機能を有効にしていない依存が `dowel graph` に孤立した節点として残る。

```
$ dowel graph --no-default-features
app:app [bin]
xml:xml [lib]
json:json [lib]
```

### 期待

選ばれなかった任意の依存は読み込まない。依存グラフにも現れない。

根拠: `docs/91-implementation-status.md` は「機能フラグによって依存グラフの
辺が現れ／消える」と述べる。辺だけが消えて節点が残る状態は、`dowel graph` を
見た利用者に「この構成に含まれる」と読ませる。

現状の影響は path 依存に限られるため小さい。ただし Phase 5 で
レジストリ / git / tarball からの取得が入ると、
「選ばれていない任意の依存を取得する」ことになる。`optional` の意味が
そこで失われる。あわせて、読み込んだ以上その `dowel.toml` は記録された
入力になり、無関係な編集で再評価が起きる。

### なぜ内側から見つからないか

合成プロジェクトの任意の依存は必ず実体を持ち、必ずどこかの構成で有効になる。
「実体が無くてもよいはずの依存」は、外から書いて初めて現れる入力である。

### 修正

選ばれなかった任意の依存は読み込まれなくなった。実体が無くても `check` が通る。

```console
$ dowel check          # feature.absent は偽、../does-not-exist は存在しない
check passed: 1 packages, 1 targets
```

依存グラフからも消えた。

```console
$ dowel graph --no-default-features
app:app [bin]
```

Phase 5 で取得を伴う依存が入っても、選ばれていないものを取りに行かない。

### 検査

`projects/03-features` の
`a disabled optional dependency need not exist on disk`
`a dependency behind a disabled feature is absent from the graph`。

---

## F-005

報告先: [sabas0ba/dowel#18](https://github.com/sabas0ba/dowel/issues/18)

**`missing-manifest` に位置情報が無い。**

種別: 実装。軽微。

### 観測

```json
{"severity":"error","code":"missing-manifest",
 "message":"cannot read .../does-not-exist/dowel.toml: No such file or directory",
 "labels":[],"notes":["a package root requires a `dowel.toml`"],"suggestions":[]}
```

`labels` が空である。本スイートが見た他の全ての診断は位置を持つ。

### 期待

原因となった `dowel.toml` の `[[dependencies]]` の `path` の位置を指す。
依存が多段になると、どのパッケージのどの宣言が原因かが分からなくなる。

根拠: `README.md` の差別化点「全ての値が型とソース位置と来歴を持つ」。

### 修正

原因となった `[[dependencies]]` の `path` を指すようになった。

```
error[missing-manifest]: cannot read .../does-not-exist/dowel.toml: No such file or directory
 --> dowel.toml:8:1
  |
8 | path = "../does-not-exist"
  | ^^^^^^^^^^^^^^^^^^^^^^^^^^ this dependency does not name a package root
   = note: a package root requires a `dowel.toml`
```

### 検査

`projects/04-diagnostics` の`missing-manifest points at the offending source`。

---

## F-010

報告先: [sabas0ba/dowel#33](https://github.com/sabas0ba/dowel/issues/33)

**入れ子の深い値でスタックが溢れ、診断を1件も出さずに abort する。**

種別: 実装。修正済み（`95daf9f`）。

### 観測

`sources` の値を深く入れ子にする。3つの形のいずれでも起きる。

```
[bin.subject]
sources = [[[[[ …（10 万段）… ]]]]]
sources = {a={a={a= …（10 万段）… }}}
sources = glob(glob(glob( …（5 万段）… )))
```

```console
$ dowel check

thread 'main' (18892) has overflowed its stack
fatal runtime error: stack overflow, aborting
$ echo $?
134
$ dowel check --message-format=json
$                                     # 標準出力は空
```

診断は1件も出ない。終了状態はシグナル（`SIGABRT`）である。

溢れる手前の深さでは abort しないが、応答が深さに対して超線形になる。
入力は 4KB しかない。

| 形 | 深さ | 応答 |
|---|---|---|
| 配列 | 1000 | 80ms |
| 配列 | 2000 | 487ms |
| 配列 | 4000 | 2180ms |
| 配列 | 6000 | 5460ms |
| 配列 | 8000 | abort |
| インラインテーブル | 1000 | 9212ms |
| インラインテーブル | 2000 | 60秒を超える |

**溢れる境目は機械による。** 上の 8000 は手元での値であり、CI の runner では
深さ 10000 でも通った。検査は境目の付近を避け、確実に足りる深さと確実に
溢れる深さだけを使う。境目に置いた検査は、dowel ではなく実行した機械を
記録することになる。

閉じていない入力（`[[[[[` のみ。型検査に到達しない）でも同じ形で伸びるため、
超線形なのは型検査だけではない。

### 期待

深さの上限を持ち、超えたら診断として拒む。位置を伴う。

根拠は3つある。

1. `docs/10-manifest.md` 2節が「式は**純粋かつ全域**とする。（…）これにより
   停止性を言語仕様として保証する」と述べている。停止性を仕様として保証する
   言語の処理系が、入力の深さで abort するのは主張と食い違う
2. `README.md` の差別化点は「全ての値が型とソース位置と来歴を持つ」。
   abort した実行はこのいずれも提示しない
3. 上限を持つと超線形の問題も同時に消える。上限を 64 なり 128 なりに置けば、
   越えた入力は即座に拒まれ、越えない入力は深さが定数で抑えられる

深さ 10 万を手で書く利用者はいない。この形が問題になるのは、
**マニフェストを生成する道具**（移行、コード生成）と、
**言語サーバ**である。`2ab1428` で `dowel-lsp` が入り、編集のたびに
未完成のマニフェストを解析するようになった。解析器の abort は
そこでは編集器の接続が切れる形で現れ、利用者は原因を知る手立てを持たない。

### なぜ内側から見つからないか

本体のフィクスチャと e2e の入力は、いずれも人が書いた正しい形の
マニフェストか、意図した1箇所の誤りを含むものである。深さは常に
2〜3 段であり、解析器の再帰段数が入力から決まるという性質そのものが
入力にならない。

網羅の追跡は診断コードの有無を見るため、「診断が組み立てられない入力」は
その枠の外にある。

### 修正

値の入れ子に深さの上限が入った（既定 64、`nesting-too-deep`）。

```
error[nesting-too-deep]: the value is nested more than 64 levels deep
 --> dowel.build:2:75
   = note: such depth usually comes from a generated manifest; flatten the value,
           or raise the limit with `--max-nesting`
```

超線形だった側も同時に消えた。深さ 2000 のインラインテーブルは
60 秒超から **14ms** になった。上限が呼び出し段数を定数で抑えるため、
2つの症状が1つの変更で直っている。

`--max-nesting` で上限を動かせる（1〜512）。生成された記述を扱う利用者に
逃げ道が要るという判断だと読める。上限そのものに上限があるため、
「上限を置いた意味が無くなる」ことは起きない。

### 検査

`projects/07-robustness` の以下 10 件。いずれも known_issue F-010 として登録した。

| 入力 | 検査 |
|---|---|
| 100k nested arrays | `100k nested arrays does not abort dowel` |
| 100k nested arrays | `100k nested arrays is refused` |
| 100k nested arrays | `100k nested arrays is refused with a source location` |
| 100k nested inline tables | `100k nested inline tables does not abort dowel` |
| 100k nested inline tables | `100k nested inline tables is refused` |
| 100k nested inline tables | `100k nested inline tables is refused with a source location` |
| 50k nested calls | `50k nested calls does not abort dowel` |
| 50k nested calls | `50k nested calls is refused` |
| 50k nested calls | `50k nested calls is refused with a source location` |
| 2k nested inline tables | `2k nested inline tables is answered within the budget` |

最後の1件が超線形の側である。abort する3件については
`100k nested arrays is answered within the budget` が通っているが、
これは溢れるのが速いためであり、直ったあとも同じ検査が同じ意味で通る。

---

## F-011

報告先: [sabas0ba/dowel#34](https://github.com/sabas0ba/dowel/issues/34)

**先頭に UTF-8 BOM が付いたマニフェストが拒まれる。しかも診断が
正しく見える行を指す。**

種別: 実装。**一部修正**（`95daf9f`）。軽微だが、失敗の様式が悪い。

### 観測

`dowel.build` と `dowel.toml` のどちらでも同じ形で起きる。

```console
$ printf '\xef\xbb\xbf[package]\nname = "p"\n…' > dowel.toml
$ dowel check
error[unknown-char]: unrecognized character
 --> dowel.toml:1:1
  |
1 | ﻿[package]
  | ^ this character cannot appear here
error[unexpected-token]: an unrecognized character cannot appear here
 --> dowel.toml:1:1
  |
1 | ﻿[package]
  | ^ expected a table header `[...]` or a key
error[missing-table]: missing `[package]`
 --> dowel.toml:1:1
  |
1 | ﻿[package]
  | ^ `dowel.toml` requires a `[package]` table
```

BOM は幅を持たないため、描画された行は正しい行にしか見えない。
3件目の `missing `[package]`` は、まさに `[package]` と書かれた行を指す。

### 期待

先頭の BOM を読み飛ばす。

BOM は利用者が書いた覚えの無い違いである。Windows のメモ帳、
PowerShell の `>` によるリダイレクト、Visual Studio の既定の保存形式が
いずれも付ける。利用者から見ると「画面上は正しいのに拒まれ、しかも
`[package]` が無いと言われる」という形になり、原因に辿り着く手掛かりが無い。

`dowel.toml` は厳密な TOML であると定めてある（`docs/10-manifest.md` 2節）。
TOML の仕様は BOM の扱いを規定していないが、広く使われている実装は
先頭の BOM を読み飛ばす側に倒しており、Cargo も BOM 付きの `Cargo.toml` を
受け付ける。既存の TOML から移行してくる利用者は、その挙動を前提にしている。

読み飛ばさないという判断もありうる。その場合に必要なのは、
`unknown-char` ではなく「先頭に BOM がある」と述べる診断である。
原因が名指しされれば、利用者は編集器の保存形式を直せる。

### なぜ内側から見つからないか

本体のフィクスチャはリポジトリの中でテキストとして書かれる。BOM 付きの
ファイルを git に置くと編集器が黙って落とすため、入力として作りにくい。
本スイートでも同じ理由でファイルに置かず、`expect.sh` が生成している。

CRLF は正しく扱えている（同じ経路で検査してある）。BOM だけが残っているのは、
改行の正規化はあるが先頭バイトの正規化が無い、という形と思われる。

### 修正（一部）

マニフェストの側は直った。先頭の BOM を些末部として読み飛ばす。行の途中に
現れた同じバイト列は従来どおり誤りとして残る。

**`dowelup` が `.dowel-version` を読む経路には届いていない。**

```console
$ printf '\xef\xbb\xbf95daf9ff8dac60310d2ff5c427a53804d2870890\n' > .dowel-version
$ dowel --version
error: .../.dowel-version contains `95daf9ff…`, which is not a full commit hash;
       run `dowelup pin 95daf9ff…` to resolve it and rewrite the file
```

促される `dowelup pin` の引数に BOM がそのまま入るため、**貼り付けても
同じ理由でまた拒まれる**。`dowelup` は `dowel-syntax` を通らないため、
そちらの修正が届かないのは自然である。

### 検査

`projects/07-robustness` の2件は通常の検査へ戻した。

- `a UTF-8 BOM on dowel.build is accepted`
- `a UTF-8 BOM on dowel.toml is accepted`
- `a BOM in the middle of a line is refused`（先頭だけが些末部であること）

残っている側は `projects/09-acquisition` の
`a pin file with a UTF-8 BOM is read` で、known_issue F-011 である。
対になる CRLF・空白・大文字の sha はいずれも通っており、
BOM だけが例外であることが検査の並びから読める。

---

## F-012

報告先: [sabas0ba/dowel#38](https://github.com/sabas0ba/dowel/issues/38)

**言語サーバが型検査の段の診断を出さない。しかも `dowel_lsp::UNSUPPORTED` に
載っていないため、出ないことが分からない。**

種別: 実装。修正済み（`95daf9f`）。

### 観測

同じ本文を、`didOpen` でエディタの緩衝として渡した場合と、ディスクに置いて
`dowel check --message-format=json` を掛けた場合の比較。

| 入力 | `dowel check` | `dowel lsp` |
|---|---|---|
| `include = [dir("src")]` | `unknown-property` | 出ない |
| `[binn.subject]` | `unknown-kind` | 出ない |
| `sources = 42` | `type-mismatch` | 出ない |
| 見出しの外の鍵 | `toplevel-entry` | 出ない |
| `command` の無い `[runner.<triple>]` | `missing-field` | 出ない |
| `[package]` の無い `dowel.toml` | `missing-table` | 出ない |

境目は段にある。字句・構文（`expected-token` ほか7件）と評価
（`unknown-cfg-key` / `non-exhaustive-match` / `unknown-function`）は出る。
型検査だけが出ない。

同じ位置でホバーすると `null` が返り、正しい `includes` に直すとホバーは
`Set<Path>` と併合規則を返す。**言語サーバはスキーマを持っており、その語が
未知であることも判定できている。** 判定した結果をホバーの不在としては使い、
診断としては使っていない。

### 期待

型検査の段を言語サーバでも走らせる。`UNSUPPORTED` に並ぶ理由はいずれも
「開いている1ファイルの外を要する」だが、上の6件はどれも開いている
ファイルだけで決まる。

走らせない判断を採るなら、6件を `UNSUPPORTED` に理由とともに足すことが要る。
`docs/30-devexp.md` 3.2 節は「出さないものは `dowel_lsp::UNSUPPORTED` に
理由とともに列挙してあり」と述べており、現状はこの記述が成り立っていない。

`unknown-property` はとりわけ効く。マニフェストで最も踏みやすい誤りであり、
編集距離による候補と機械適用可能な修正提案（F-006 で直した経路）が
用意されているのは、まさにこの診断である。

### なぜ内側から見つからないか

`dowel-lsp` の検査は「一覧の綴りが実在すること」と「一覧の項目が実は
出ていないこと」の2つを見ている。どちらも**一覧に載っているもの**を
起点にしており、「出ないのに一覧にも無い」ものはどちらの起点にも現れない。

一覧が漏れていることは、一覧の外から見ないと分からない。外から見るとは、
この場合「CLI が出す診断の全体と突き合わせる」ことである。

### 修正

開いている1ファイルだけで決まる型検査の診断が、言語サーバからも出るように
なった。6 件すべてが `dowel check` と一致する。

期待として挙げた2案のうち、`UNSUPPORTED` に足す側ではなく**型検査を走らせる**
側が採られている。`UNSUPPORTED` に残るのは、ワークスペースの模型と計画段を
要するものだけになった。

### 検査

`projects/08-lsp` の以下 6 件。いずれも known_issue F-012 として登録した。

- `the language server reports unknown-property as dowel check does`
- `the language server reports unknown-kind as dowel check does`
- `the language server reports type-mismatch as dowel check does`
- `the language server reports toplevel-entry as dowel check does`
- `the language server reports missing-field as dowel check does`
- `the language server reports missing-table in dowel.toml`

各件には CLI 側が同じ診断を出していることの確認が対になっている
（`dowel check still reports unknown-property` ほか）。CLI 側が出さなく
なった場合に、一致していないのか、そもそも誤りでなくなったのかを見分けられる。

---

## F-013

報告先: [sabas0ba/dowel#39](https://github.com/sabas0ba/dowel/issues/39)

**`dowelup install <指定子>` が成功した指定子で、`dowel +<指定子>` が
選べないことがある。**

種別: 実装。修正済み（`95daf9f`）。軽微だが、成功した操作の直後に
矛盾した応答が返っていた。

### 観測

上流でタグ `v0.9.0` と `stable` が同じコミットを指す状態から。

```console
$ dowelup install stable
2ab1428cf1e1
$ dowelup install tag:v0.9.0
2ab1428cf1e1 is already installed
2ab1428cf1e1

$ dowel +stable --version
dowel 0.0.1
$ dowel +tag:v0.9.0 --version
error: no installed version matches `tag:v0.9.0`; `dowelup list` shows what is installed
```

`versions/<sha>/origin` に記録されるのは、その sha を**最初に入れたときの
指定子1つだけ**である。`+<指定子>` はその文字列との完全一致で照合するため、
2つ目以降の指定子は install が成功しても選べない。順序を入れ替えると、
選べる指定子も入れ替わる。

`uninstall` にも同じ形が出る。sha による指定は接頭辞も含めて常に通る。

### 期待

`dowelup install <指定子>` が成功したなら、その指定子で選べる。

`origin` を複数持てるようにするのが素直だと考える。`+<指定子>` の照合を
解決に寄せる案は、`stable` や `branch:` の解決がネットワークを要するため
「shim はネットワークに触れない」（ADR-0013）と衝突する。

### なぜ内側から見つからないか

同じコミットを別の指定子で2度入れる、という操作が入力にならないため。
1つの指定子につき1つの sha を入れる形では、記録と照合は常に一致する。

タグとチャネルが同じコミットを指すのは通常の状態であり（`stable` は
最新の release タグそのもの）、利用者が両方を試すのは自然である。

### 修正

`origin` が複数の指定子を持てるようになり、`+<指定子>` と `uninstall` の
両方がそれらすべてと照合するようになった。期待として挙げた2案のうち、
記録を増やす側が採られている。shim の選択がネットワークに触れないという
性質は保たれている。

`dowelup list` にも、その版を入れるのに使った指定子が並ぶ。

### 検査

`projects/09-acquisition` の以下 2 件。いずれも known_issue F-013 である。

- `a specifier that installed successfully can select`
- `uninstalling by the specifier it was installed from succeeds`

直前に `installing the same commit under another specifier succeeds` を
置いてある。install が成功していることが、比較の前提として見える。

---

## F-014

報告先: [sabas0ba/dowel#41](https://github.com/sabas0ba/dowel/issues/41)

**ninja で組んだあと direct 実行器で組むと、ヘッダの変更が見落とされ、
古い成果物が黙って残る。**

種別: 実装。修正済み（`3e84cbd`）。本一覧のうち最も影響が大きかった。

### 観測

`include/h.h` の `V` を成果物の終了状態に載せ、新しいかどうかを外から見る。

```console
$ dowel build                       # 既定の ninja
$ printf '#define V 7\n' > include/h.h
$ dowel build --executor=direct --log-level=debug
... ran 0 actions, skipped 2 already up to date
$ ./.dowel/build/*/bin/m; echo $?
0                                   # 期待は 6。古い成果物のまま
```

| 最初 | 2回目 | ヘッダ変更の反映 |
|---|---|---|
| direct | direct | される |
| ninja | ninja | される |
| direct | ninja | される |
| **ninja** | **direct** | **されない** |

ソースの変更はどの組み合わせでも反映される。落ちるのは depfile 経由で
辿る依存に限られる。ninja に戻すと正しく組み直される。

ninja は `deps = gcc` で depfile を読むと `.d` を消して `.ninja_deps` へ畳む。
direct は `.d` を読むため、ninja のあとは**依存情報が1件も無い状態**で
最新性を判定し、無いことを検出せずに「最新である」と結論する。

### 期待

依存の記録を実行器の実装詳細から切り離す。`direct-log.tsv` が既にコマンドの
記録を持っているので、依存もそこへ寄せる形になる。少なくとも、依存情報を
持たない目的物に対して「最新である」と結論しないこと。

根拠は `docs/00-overview.md` 7節。実行層を ninja に委ねると述べているのは
**実行**の話であり、最新性の判定は dowel の側にある。

### なぜ内側から見つからないか

増分の検査は「何を計算しなかったか」を見るために実行回数を数える必要があり、
そのために direct の debug ログを使う（`docs/51-testing.md`）。つまり
**増分を見る検査は最初から最後まで direct で走る**。既定の経路である ninja と、
その間の行き来は、数えられないため入力にならない。

本スイートの `projects/05-incremental` も同じ形になっていた。`10-toolchain` を
書いていて、既定どおり `build` してから計数のために direct へ渡したところ、
数が合わずに気づいた。

コマンドの記録は共有されているため、目的物は実行器をまたいで再利用される。
**部分的に共有されていること**が原因であり、全部が共有されていなければ
全部組み直すのでこの形は現れなかった。

### 修正

実行器を跨いでも依存の記録を失わなくなった。4通りの組み合わせすべてで
ヘッダの変更が反映される。

### 検査

`projects/05-incremental` の実行器の組み合わせ4通り。いずれも通常の検査である。

- `a header edit is seen after building with ninja then direct`
- `a header edit is seen after building with direct then ninja`
- `a header edit is seen after building with ninja then ninja`
- `a header edit is seen after building with direct then direct`

`crossing/` は専用のパッケージである。

`crossing/` は専用のパッケージである。`core` の検査は両側が同じ定数を使う形で
あり、双方が古いままなら食い違いが打ち消し合ってテストが通ってしまう。

---

## F-015

報告先: [sabas0ba/dowel#42](https://github.com/sabas0ba/dowel/issues/42)

**`--target` が構成識別子を変えるだけで、ツールチェーンを選ばない。**

種別: 実装。修正済み（`3e84cbd`）。

### 観測

```console
$ dowel build --target=aarch64-unknown-linux-gnu
built: .../.dowel/build/aarch64-unknown-linux-gnu-debug/bin/t
$ readelf -h .../aarch64-unknown-linux-gnu-debug/bin/t | grep Machine
  Machine:                           Advanced Micro Devices X86-64
```

コンパイル行にもトリプルは現れない。`--target` の有無で変わるのはパスだけである。

`[runner.<triple>]` を宣言してあると、ホスト向けの成果物が qemu へ渡る。

```
qemu-aarch64-static: .../bin/smoke: Invalid ELF image for this architecture
test result: FAILED. 0 passed; 1 failed
```

`missing-runner` を足した理由として本体が挙げているのは、まさにこの形である。

> 起動してから `Exec format error` になるのでは、構成の誤りがテストの失敗として
> 報告される。起動の前に拒むのが約束である。

宣言が**無い**場合は約束どおり起動前に拒む。宣言が**あって成果物の
アーキテクチャが違う**場合は、同じ誤りが1段あとに戻ってきている。

### 期待

`[toolchain]` をトリプルごとに書けるようにする（`[runner.<triple>]` と同じ形）。
そのうえで、宣言の無いトリプルへ `--target` を渡したら拒む。

`schema dump` は `toolchain` を `implemented: false` としており、未実装で
あること自体は宣言されている。所見にしたのはそこではなく、**未実装の
現れ方が「黙って別のものを作る」になっている**点である。

### なぜ内側から見つからないか

本体のフィクスチャと CI は単一のホスト向けにしか組まない。クロス用の
ツールチェーンを置いた環境が入力にならないため、「ビルドディレクトリの名前と
成果物のアーキテクチャが食い違う」状態が作れない。

`[runner.<triple>]` の検査も、記録だけを行うラッパで組める。
その形ではアーキテクチャの不一致は現れない。

### 修正

`[toolchain.<triple>]` が入り、`[runner.<triple>]` と同じ形になった。
提案どおり、**宣言の無いトリプルへ `--target` を渡すと組む前に拒まれる**。

```
error[missing-toolchain]: no toolchain is declared for target `aarch64-unknown-linux-gnu`
  = note: building with the host toolchain would produce artifacts for the
          wrong architecture under this target's name
  = note: declare one, for example `[toolchain.aarch64-unknown-linux-gnu]`
          with `c = "..."` in dowel.toml
```

素の `[toolchain]` は host 向けの宣言であり、他のトリプルには決して
適用されない。C++ を含む場合はそのトリプルの `cxx` も要る。

### 検査

`projects/11-cross` の以下。いずれも通常の検査である。

- `building for a triple with no toolchain declared is refused`
- `the refusal carries the missing-toolchain code`
- `the mismatch is caught before anything is built`
- `declaring the host compiler for another triple is allowed`
- `and it produces a host artifact, which readelf shows plainly`

最後の2件は、宣言の中身までは止められないことの記録である。利用者が
ホストのコンパイラをトリプルの宣言として書くことは止まらないが、
そのとき成果物がホスト向けになることは `readelf` で観測できる。

逆向き（クロスのツールチェーンでホスト向けの構成を組む場合）は検査にしていない。起動できるかどうかが機械の設定で決まるためである。
`qemu-user-static` を入れた環境では binfmt_misc に登録され、別アーキテクチャの
実行ファイルがそのまま起動する。拒まなかった結果が機械によって変わるなら、
その検査が記録するのは dowel ではなく実行した機械である。

通る側（宣言したクロスツールチェーンで組み、qemu で走らせる）が同じ
プロジェクトにあるため、**機構は揃っていて結び付けが無いだけ**であることが
検査の並びから読める。

---

## F-016

報告先: [sabas0ba/dowel#50](https://github.com/sabas0ba/dowel/issues/50)

**書庫の作成に使う `ar` を `[toolchain]` で宣言できない。しかもどの `ar` を
使ったかが記録された入力になっていない。**

種別: 要望。修正済み（`a9c1619`）。

### 観測

クロスの構成でも、書庫の作成だけがホストの道具に落ちる。

```console
$ dowel graph --kind=action --format=json --target=aarch64-unknown-linux-gnu \
  | jq -r '.actions[]|"\(.kind)  \(.command[0])"'
cc    aarch64-linux-gnu-g++
ar    ar                        ← ここだけ接頭辞が無い
cc    aarch64-linux-gnu-gcc
link  aarch64-linux-gnu-g++
```

このホストの `ar` は対応する目標に aarch64 を持たない。通っているのは
総称の `elf64-little` に当たっているからである。`aarch64-linux-gnu-ar` は
同じ機械にあるのに使われない。

さらに、`ar` は記録された入力になっていない。

```console
$ PATH=/path/to/other-ar:$PATH dowel build --target=... --executor=direct --log-level=debug
... ran 0 actions
```

`[toolchain] c` は記録された入力である（gcc から clang へ変えると組み直される。
`projects/10-toolchain` が見ている）。`ar` にはそれが無く、記録されているのは
`ar` という名前だけで、それがどの実体を指すかは記録の外にある。

### 期待

`[toolchain]` に `ar` を足す。既定は `ar`。`c` / `cxx` と同じく、PATH に
無ければ `missing-toolchain` で拒み、変えたら組み直す。

根拠は `docs/00-overview.md` 2節の目標「再現性 — ツールチェーンを含めて
ロックし、**記録されない入力を排除する**」。`ar` はちょうどその
「記録されない入力」になっている。

組み込みでは、ベンダが配る toolchain がコンパイラ・リンカ・書庫の道具を
一組で配り、混ぜることを想定していない。現状はその混成を**利用者が
避けられない**。macOS をホストに ELF へクロスする場合は、Apple の `ar` が
GNU 形式の ELF 書庫を作れないため、より直接に効く。

### なぜ内側から見つからないか

本体のフィクスチャと CI は単一のホスト向けにしか組まない。ホストの `ar` が
ホストの目的物を扱うのは当然通るため、「書庫の道具だけがホストのものである」
状態が入力として現れない。

`missing-toolchain` の検査も `c` と `cxx` を対象にしており、宣言できない
ものは網羅の対象にならない。**宣言できない道具は、宣言の検査から漏れる。**

### 修正

`[toolchain] ar`（既定 `ar`、`[toolchain.<triple>]` にも書ける、構成キーは
`tc.ar`）が入った。実在は書庫を作るときだけ確かめられ、名前がアクションの
コマンド行に載るため、差し替えると書庫が作り直される。

同時に、道具の集合が表（`dowel_eval::config::TOOLS`）へ集約された。
`[toolchain]` のキー・`tc.*` の語彙・既定値・宣言の写し・`toolchain-mismatch`
の比較は全てこの表から回る。以後、道具を増やすのは表1行と、それを使う計画の
箇所だけになる。

なお、記録されているのは**道具の名前**であって、その名前が指す実体ではない。
同じ `ar` の裏で別の実体に差し替えても組み直されない。報告では「それがどの
実体を指すかは記録の外にある」と書いたが、これは `c` も `cxx` も同じであり、
道具ごとの差ではなく記録の粒度である。粒度そのものを上げる話は別件と考え、
現状を1件の検査として固定するに留めた。

### 検査

`projects/18-tools`。表に載ることで得られる5つの性質を1つずつ見る。

- `a declared archiver is the one that runs`
- `match on tc.ar follows the declaration`
- `an archiver that is not on PATH is refused`
- `a target that produces no archive ignores a broken archiver`
- `changing the declared archiver rebuilds`
- `a cross build uses the archiver declared for that triple`
- `the objects inside the cross archive are for the target architecture`

記録の粒度は
`the record is the tool's name, so swapping what the name resolves to does not rebuild`。

---

## F-017

報告先: [sabas0ba/dowel#54](https://github.com/sabas0ba/dowel/issues/54)

**`migrate import` が CMake の構成（`CMAKE_BUILD_TYPE`）のフラグを、下書きの
無条件の `flags` へ写す。dowel の構成が加えるものの後ろに並ぶため、後勝ちで
`--config` の指定が効かなくなる。**

種別: 実装。**一部修正**（`a9c1619`）。翻訳の側は直り、リンクの側
（`link_flags`）に残っている。追加の報告先は
[#61](https://github.com/sabas0ba/dowel/issues/61)。

### 観測

`CMAKE_BUILD_TYPE=Release` で構成した木を取り込むと、下書きはこうなる。

```toml
[lib.greet.private]
includes = [dir("include")]
defines  = { GREET_SCALE = 3 }
flags    = ["-O2", "-DNDEBUG"]      # 構成のフラグが無条件で入る
```

`flags` は構成に依らない。したがってこの下書きを `--config=debug` で組むと、
dowel の `-g -O0` の後ろに `-O2 -DNDEBUG` が並ぶ。

| 取り込み元 | 組んだ構成 | 実際の引数 | 成果物が名乗るもの |
|---|---|---|---|
| Debug | debug | `-g -O0 -g -O0` | assertions / unoptimized |
| Debug | **release** | `-O2 -DNDEBUG -g -O0` | ndebug / **unoptimized** |
| Release | **debug** | `-g -O0 -O2 -DNDEBUG` | **ndebug** / optimized |

構成ごとの `CMAKE_C_FLAGS_<TYPE>` は次のとおり写る（CMake 3.28 の既定）。

| `CMAKE_BUILD_TYPE` | 下書きの `flags` |
|---|---|
| 未設定 | 無し |
| `Debug` | `["-g"]` |
| `Release` | `["-O3", "-DNDEBUG"]` |
| `RelWithDebInfo` | `["-O2", "-g", "-DNDEBUG"]` |
| `MinSizeRel` | `["-Os", "-DNDEBUG"]` |

同じ理由で、`import` が自分で指している `verify` の手順も通らない。移行元の
構成フラグを dowel と同じ（`-g -O0` / `-O2 -DNDEBUG`）に揃えてもなお、
写されたぶんが重複として残る。

```console
$ dowel migrate import ../bd-debug
$ dowel migrate verify ../bd-debug/compile_commands.json
0 equivalent, 4 differing, 0 not ported, 0 only in dowel

  .../src/greet.c
    + -O0   (in dowel, not in the reference)
    + -g    (in dowel, not in the reference)
```

構成を揃えない場合は、`CMAKE_BUILD_TYPE`（未設定 / Debug / Release /
RelWithDebInfo / MinSizeRel）と `--config`（debug / release）の 10 通り
すべてで `0 equivalent` になる。

一方、`flags` を持たない下書き（構成未設定の木から取り込んだもの）を、
揃えた Debug の参照に掛けると `4 equivalent, rc=0` になる。正規化そのものは
正しく働いており、原因は写されたフラグの側にある。

### 期待

構成が決めるものを無条件の `flags` へ入れない。採りうる形は3つある。

1. dowel の構成の語彙が既に覆うもの（`-g` `-O0` `-O1` `-O2` `-O3` `-Os`
   `-DNDEBUG`）を落とす
2. `match cfg.opt { ... }` の腕へ振り分ける
3. 少なくとも下書きの冒頭で「どの構成から写したか」「`flags` は構成に
   依らない」ことを名指しする

根拠は本体の `docs/30-model.md`。`--config` は debug と release で異なる
翻訳を与えることを約束しており、下書きがそれを無効化するなら、それは
移行の結果ではなく移行の欠陥である。

`import` の出力が `verify` を指している以上、「`import` の出力をそのまま
`verify` に掛けると何も報せない」ことがこの機能の外側の期待値になる。

### なぜ内側から見つからないか

`import` を単体で見ると、CMake が言ったフラグを写すのは正しい動作に見える。
誤りが現れるのは **`import` の出力を `build --config` に食わせたとき**で
あり、2つのコマンドを跨ぐ。本体の層は片方ずつを受け持っている。

`verify` を `import` の出力に掛けるという結び付けも、本体の側では
「移行の手順」であって検査の対象になっていない。

### 修正

構成レベルのフラグは `flags` へ写されなくなり、`migrate verify` の比較でも
**両側から**落とされるようになった。dowel の `cfg.opt` と参照の build type が
同じことを別々に決めるため、その差は移行の忠実さについて何も語らない。

移行元の `CMakeLists.txt` から構成フラグを dowel に揃える細工を外した。
揃っていない木でも `4 equivalent, rc=0` になり、CMake の build type と
`--config` のどの組み合わせでも clean になる。

### 残っているもの（[#61](https://github.com/sabas0ba/dowel/issues/61)）

同じ集合が `link_flags` には残っている。下書きの見出しは

```
# Configuration-level flags (-O / -g / -DNDEBUG from the CMake build type)
# were NOT copied: dowel's own debug/release configuration supplies them.
```

と述べているが、同じファイルの下に `link_flags = ["-O3", "-DNDEBUG"]` が並ぶ。
**下書きが自分自身について嘘をつく。**

`lib` に出ないのは書庫の作成がリンクを伴わないためで、`bin` と `test` にだけ
現れる。`-DNDEBUG` はリンク行では意味を持たないが、`-flto` を使う構成では
`-O3` が効く。`migrate verify` は翻訳の引数だけを比べるため、**verify が
clean でも残る**。

### 検査

`projects/16-migrate`。翻訳の側は通常の検査。

- `the draft carries no optimization flag from the CMake build type`
- `the drafted release build is actually optimized`
- `the drafted debug build keeps assertions`
- `the workflow that import prints verifies clean`
- `verify ignores the build type on both sides, so any pairing is clean`

リンクの側は known_issue F-021 として
`the draft carries no NDEBUG from a release CMake build type`。

---

## F-018

報告先: [sabas0ba/dowel#56](https://github.com/sabas0ba/dowel/issues/56)

**`lib` が `private` ブロックで持つ `link_flags`（および `private` な依存が
持ち込む `--libs`）が、依存元の最終リンクに乗らない。静的な書庫は自分の
リンク要件を運べないため、依存元が `undefined reference` で落ちる。**

種別: 実装。修正済み（`af7d391`）。ADR-0015 の `version` 依存を試していて
見つけた。

### 観測

`mid`（`lib`）が `demokit` を `private` で使い、`top`（`bin`）が `mid` に
依存する形。`demokit.pc` の `Libs:` は `-lm`。

```
# mid/dowel.build
[lib.mid]
sources = [file("src/mid.c")]

[lib.mid.private]
deps = [dep("demokit")]
```

```console
$ dowel build            # top で
cc .../src_main.c.o .../libmid.a .../libdemokit.a -o .../bin/top
/usr/bin/ld: libmid.a(src_mid.c.o): in function `mid_value':
mid/src/mid.c:5: undefined reference to `sqrt'
```

リンク行に `-lm` が無い。`libdemokit.a`（要素0の合成書庫）は乗っている。

`public` に変えると通るが、今度は `-I.../include` と `-DDEMOKIT=1` が
`top` の翻訳にも届く。

| `mid` の宣言 | `top` のリンク | `top` の翻訳に届くもの |
|---|---|---|
| `private` | **失敗** | 何も届かない（正しい） |
| `public` | 成功 | `-I.../include` `-DDEMOKIT=1`（漏れている） |

**「ヘッダを漏らさない」と「リンクできる」を同時に選べない。**

pkg-config とは無関係でも同じである。`[lib.mid.private] link_flags = ["-lm"]`
と直に書いても `top` のリンクに現れず、診断も出ない。`lib` に対する
`private link_flags` は現状**黙って無視される**プロパティになっている
（書庫の作成は `ar` であり、リンクは行われないため）。

さらに、`top` → `mid` → `leaf` と繋ぎ `mid` が `leaf` を `private` で持つと、
`libleaf.a` は `private` を2段跨いで最終リンクに乗る。**閉包を辿る機構は
既にあり、`link_flags` がそこに載っていないだけ**である。

### 期待

`private` な `link_flags` も、リンクの閉包に沿って最終リンクへ届く。翻訳の
プロパティ（`includes` / `defines` / `flags`）は従来どおり伝播しない。

根拠は本体の文書。`docs/13-semantics.md` は「**The linker follows the
closure**」と述べ、リンクを「own objects, dependency archives in graph
order, `link_flags`」と定義している。書庫が閉包を辿るなら、その書庫が要求
するリンクフラグも同じ閉包を辿らなければ、書庫だけがあってシンボルが解けない
状態になる。

`docs/12-build-reference.md` の例は、まさにこの形を載せている。

```toml
[lib.foo.private]
includes = [dir("src")]
deps     = [dep("zlib") when feature.zlib]
```

ADR-0015 以前は `zlib` が解決されなかったため露見しなかった。解決される
ようになった今、この例のとおりに書くと `libfoo.a` を使う側がリンクできない。

静的リンクでは書庫が自分の依存を運べないため、CMake が `$<LINK_ONLY:...>`
で扱っている領域にあたる（`target_link_libraries(mid PRIVATE m)` は STATIC
ライブラリでも最終実行ファイルの行に `m` を残す）。

「`lib` の `private link_flags` は意図的に無意味である」という設計であれば、
少なくとも黙って落とさず診断を出すべきである。現状は書けてしまい、`check`
も `build` も何も言わないまま、リンカの出力だけが利用者に届く。F-008 で
`invalid-source` / `unresolved-path` を足したときと同じ形である。

### なぜ内側から見つからないか

- 本体のフィクスチャに、`private` ブロックへ `link_flags` を置き、かつ
  **その記号が実際に必要**な例が無い。`-lm` のような「無くても書庫は作れるが
  リンクで初めて落ちる」形が要る
- `version` 依存は入ったばかりで、`--libs` が空でないモジュールを `private`
  で使う例がまだ無い。`Libs:` が空なら差は出ない
- 2パッケージ以上（`bin` → `lib`）でないと現れない。単一パッケージの `bin`
  では `private link_flags` は自分自身のリンクに乗るため正しく動く

### 修正

`link_flags` がリンクの閉包を辿るようになった。`docs/13-semantics.md` に
「**`link_flags` ride the link closure**, `private` included」として、
public/private が制御するのは**翻訳**の伝播でありリンクの到達可能性では
ない、と明記された。

### 検査

`projects/17-deps` の以下 4 件。同時に通ることが期待値であり、片方だけを
満たす直し方（全部 public 扱いにする）は通らない。

- `the archive of a private system dependency reaches the final link`
- `the link flags of a private system dependency reach the final link`
- `a library that keeps a system dependency private still links its dependent`
- `and its includes are still not leaked to the dependent`

---

## F-019

報告先: [sabas0ba/dowel#59](https://github.com/sabas0ba/dowel/issues/59)

**`[toolchain]` の未知のキーが診断されず、道具の綴り間違いが既定値への無言の
後退になる。**

種別: 実装。修正済み（`af7d391`）。

### 観測

```toml
[toolchain]
cx = "clang++"          # cxx の綴り間違い
```

```console
$ dowel check
check passed: 1 packages, 1 targets
```

C++ のソースは既定の `c++` で翻訳される。`--message-format=json` にも1件も
出ない。試した綴り（`cx` / `C` / `ar_` / `archiver` / `objcopy` / `nosuchkey`）
は全て同じであった。

同じ「未知のキー」が、目標の非公開ブロックと `[runner.<triple>]` では
`unknown-property` として候補つきで拒まれる。構成の語彙も閉じており、
`tc.objcopy` は `unknown-cfg-key` になる。**同じ `objcopy` という名前が、
`tc.objcopy` としては拒まれ、`[toolchain] objcopy` としては受理される。**

実害が出るのはクロスの構成である。

```toml
[toolchain.aarch64-unknown-linux-gnu]
c   = "aarch64-linux-gnu-gcc"
ar_ = "aarch64-linux-gnu-ar"      # ar の綴り間違い
```

`check passed` となり、aarch64 向けの書庫がホストの `ar` で作られる。
F-016 で報告した状態そのものであり、`[toolchain] ar` はまさにそれを防ぐために
入った。宣言できるようになった一方で、**宣言が効いているかどうかは利用者に
見えない。**

`c` が同じ経路で消えれば翻訳が動かないのですぐ分かる。archiver は既定の `ar`
が ELF に対して総称的に動いてしまうため、**壊れるのはホストと目標で書庫形式が
違うときだけ**である。llvm-ar と GNU ar、macOS をホストに ELF へクロスする
場合、ベンダ配布の toolchain。いずれも手元では通り、別の環境で壊れる。

### 期待

`[toolchain]` および `[toolchain.<triple>]` の未知のキーを `unknown-property`
で拒む。候補は `TOOLS` の表から編集距離で出す。

根拠は3点。

- `docs/91-implementation-status.md` は編集距離による候補提示を診断の性質として
  挙げており、`[runner.*]` と目標のブロックでは実際にそう働いている。
  `[toolchain]` だけが外れている
- `docs/00-overview.md` 2節「再現性 — ツールチェーンを含めてロックし、
  **記録されない入力を排除する**」。綴り間違いで既定値へ後退した道具は、
  宣言したつもりの利用者から見て記録されていない入力である
- `9d16a44` が `TOOLS` を単一の表にしたことで、受理すべきキーの集合は既に
  1か所にある。`tc.*` の語彙との一致は単体テストで強制されているため、
  `[toolchain]` の側だけが表を参照していない

`[package]` の未知のキーも同じく無診断であった。こちらは既定値への後退という
害が無いため、優先度は下と考える。

### なぜ内側から見つからないか

道具ごとの検査は「宣言したキーが効くこと」を確かめる。**宣言していないキー**は
入力として現れない。表駆動化で「表にある名前が全て回ること」は強制されたが、
「表に無い名前が拒まれること」は表の反対側であり、同じ検査からは出てこない。

`tc.*` の側だけが閉じているのも、語彙の検査が構成キーの解決経路にあり、
マニフェストの読み取り経路には無いためと思われる。

### 修正

`unknown-property` で拒まれるようになった。`docs/11-toml-reference.md` にも
「a misspelled tool would otherwise silently fall back to its default, which
for a cross archiver means the host's `ar` quietly builds the archives」と
理由が書かれた。

### 検査

`projects/18-tools` の以下 3 件。

- `a misspelled toolchain key is refused`
- `the refusal suggests the tool that was meant`
- `the misspelled declaration is caught before anything is built`

3件目は、書庫がホストの道具で作られてから気づくのでは遅いためである。

---

## F-020

報告先: [sabas0ba/dowel#60](https://github.com/sabas0ba/dowel/issues/60)

**生成物を変換・検査する道具（objcopy / size / objdump など）を宣言できず、
生成物に対して何かを走らせる場所も無い。**

種別: 要望。**一部修正**（`af7d391`）。変換の側は入り、検査の側は残っている。

### 観測

`[toolchain]` が受け付けるのは `c` / `cxx` / `ar` の3つ。目標の種類は
`lib` / `bin` / `test`（`bench` は未実装）で、リンク後に何かを走らせる場所は
無い。

`[runner.<triple>]` は**実行**の側の抽象であり、`dowel test` が組み上がった
実行ファイルを起動するときに通る。生成物から別の形を作る側に対応するものが無い。

### 組み込みで実際に要るもの

性質の違う2種類がある。

| | 例 | 何のため |
|---|---|---|
| 変換 | `objcopy -O binary` / `-O ihex` | 書き込み用のイメージ |
| 変換 | `strip` した別の ELF | 配布用。デバッグ情報つきは手元に残す |
| 検査 | `size` | flash / RAM の予算。**超えたら落ちてほしい** |
| 検査 | `objdump -d` / `readelf -S` / `nm` | 配置と記号を読む |

変換は**ビルドの成果物**であるためグラフに乗る必要がある。検査は成果物を
作らないが、`size` だけは判定になりうる。手元では通り実機に載らないという
失敗は、ビルドの時点で落とせるはずのものである。

### 期待

満たされてほしい性質は4つ。取り込みの構文は問わない。

1. 変換の出力が `dowel build` の成果物であること（作り忘れない）
2. 元の成果物が変わらなければ再実行しないこと（増分に乗る）
3. 道具がトリプルごとに選べること（ホストの objcopy が走らない）
4. 道具の名前が記録された入力であること（差し替えたら作り直す）

根拠。

- `docs/30-devexp.md` は `[runner.<triple>]` の想定される実体として
  「シリアルポート経由の書き込みと実行」を挙げ、実機を宣言可能にすることが
  組み込みの用途を覆うとしている。**書き込む対象のイメージを作る側**が同じ
  文書に無く、実行の側だけが揃っている
- `docs/00-overview.md` 2節「記録されない入力を排除する」。dowel の外で
  objcopy を叩く限り、その道具は記録の外である。F-016 と同じ理屈がそのまま
  当てはまる
- `9d16a44` のコミットメッセージが `objcopy` を名指しで将来の追加先として
  挙げている。表の側は既に用意されており、要望はその使い道の方である

### なぜ内側から見つからないか

本体の検査は「宣言できる道具が正しく回ること」を確かめる。**まだ無い道具**は
入力として現れない。用途の側から見て初めて「無い」ことが分かる種類の欠落で
あり、実装の内側からは形が見えない。

### 修正

`objcopy` が表に入り、`[<kind>.<name>.artifacts]` が足された。挙げた4つの
性質はいずれも満たされている。構文は提案した案 A がほぼそのまま採られた。

```toml
[bin.firmware.artifacts]
bin = { tool = "objcopy", args = ["-O", "binary"] }
```

`tool` はコマンドではなく**道具の名前**であり、具体的なコマンドは
`[toolchain.<triple>]` から来る。入力と出力は実装が末尾に付ける
（ADR-0008 と同じ規約）。

### 残っているもの

ファイルを作らない道具（`size` / `nm` / `objdump`）は宣言できない。
`docs/12-build-reference.md` も「they need a place that reports rather than
builds」として保留を明記している。`size` は flash / RAM の予算を超えたら
ビルドを落とすという使い方があり、「作る」のではなく「判定する」側の機構に
なる。

### 検査

変換の側は `projects/19-artifacts` が全面的に見る（35 件）。
道具として宣言できることは `projects/18-tools` の
`a transform tool can be declared alongside the archiver`。

検査の側も `projects/18-tools` の
`an inspection tool can be declared alongside the archiver`。`17bd54e` で
`[<kind>.<name>.inspect]` が入り、報せる場所ができた。

---

## F-021

報告先: [sabas0ba/dowel#61](https://github.com/sabas0ba/dowel/issues/61)

**構成レベルのフラグが `link_flags` には残っており、下書きの見出しが
「写していない」と述べる内容と食い違う。**

種別: 実装。修正済み（`af7d391`）。F-017 の続きである。

### 観測

`CMAKE_BUILD_TYPE=Release` から取り込んだ下書き。

```
# Configuration-level flags (-O / -g / -DNDEBUG from the CMake build type)
# were NOT copied: dowel's own debug/release configuration supplies them.
#

[bin.demo.private]
includes = [dir("include")]
defines  = { DEMO_MODE = 1 }
link_flags = ["-O3", "-DNDEBUG"]      ← 残っている
```

`lib` に出ないのは書庫の作成がリンクを伴わないためで、`bin` と `test` にだけ
現れる。build type ごとの内容は F-017 の表と同じである。

### 期待

`link_flags` からも同じ集合を落とす。`flags` に適用している判定をリンクの側にも
通せば済むと思われる。現在の見出しの文言はそのままで正しくなる。

問題は3点。

1. **下書きが自分自身について嘘をつく。** 見出しを読んだ利用者は「構成の
   フラグは無い」と判断してそのまま使う。F-017 で直したのは静かな失敗であり、
   見出しと中身の食い違いは同じ種類の静かさである
2. **LTO を使う構成では効く。** `-flto` は構成レベルではないため `flags` に
   写る。その状態でリンク行に `-O3` が無条件で載ると、`--config=debug` でも
   リンク時最適化が `-O3` で回る
3. `-DNDEBUG` はリンク行では意味を持たない

### なぜ内側から見つからないか

`flags` と `link_flags` は File API の別のフィールド（`compileGroups` と
`link.commandFragments`）から来るため、写す経路も別である。F-017 の修正が
翻訳側の経路に入り、リンク側は通らなかったと思われる。

検査の側から見ると、「構成のフラグが `flags` に無いこと」を確かめる検査は
`link_flags` を見ない。**同じ性質を2か所で確かめる必要がある**ことは、片方を
直した時点では見えない。

`migrate verify` は翻訳の引数だけを比べるため、この差は報告されない。
**verify が clean でも残っている**という点も、見つけにくさに寄与している。

### 修正

`link_flags` からも落とされるようになった。下書きの見出しの文言はそのままで
正しくなった。

### 検査

`projects/16-migrate` の
`the draft carries no NDEBUG from a release CMake build type`。

見出しのコメントは NDEBUG に言及するため、注釈の行を数えない形にしてある。
「写していないと述べる文」と「写したもの」を取り違えないための細工である。

---

## F-022

報告先: [sabas0ba/dowel#64](https://github.com/sabas0ba/dowel/issues/64)

**`[lib.<name>.artifacts]` が作る派生ファイルは、そのライブラリに依存する
`bin` を1つ足すと作られなくなる。** マニフェストの当該部分は何も変えて
いない。

種別: 実装。未修正（`af7d391`）。F-020 で入った `artifacts` を試していて
見つけた。

### 観測

同じ `[lib.part.artifacts]` を持つ木で、`bin` の有無だけを変えた。
いずれも `dowel build`（引数なし）である。

| 構成 | 作られるもの |
|---|---|
| **A.** ライブラリだけ | `libpart.a` `libpart.stripped` |
| **B.** A に依存する `bin` を足す | **`libpart.a` のみ** |
| **C.** B で `dowel build part` と名指し | `libpart.a` `libpart.stripped` |
| **D.** 依存しない `bin` を足す | ライブラリごと作られない |

B が問題である。`libpart.a` は作られるのに `libpart.stripped` は作られない。
どちらも同じターゲットの宣言された出力である。

D は `docs/60-cli.md` の「With no targets named, builds every `bin` and
`test`」どおりであり、仕様と読める。A は `bin` が1つも無いためライブラリが
根として組まれたものと思われる。

### 期待

**派生が作られるかどうかは、そのターゲット自身の宣言で決まる。** 別の
ターゲットが自分に依存しているかどうかで変わってはならない。

利用者から見た経路はこうなる。

1. ライブラリを書き、`[lib.foo.artifacts]` で配布用の派生を宣言する。出る
2. あとで同じパッケージに、そのライブラリを使う実行ファイルを足す
3. 派生ファイルが出なくなる。**診断も警告も無い**

2 は `[lib.foo.artifacts]` とは無関係な追加である。組み込みでは、ライブラリ
側の objcopy 済みの形が納品物になることがあり、それが黙って消える。

根拠は `docs/12-build-reference.md`。

> Declaring it here puts that step **inside** the build graph, so it is
> produced by `dowel build`

条件を付けていない。A と C で作られることからも、意図はこちら側だったと
読める。

「要求されたターゲットの `artifacts` だけを作る」と決めるなら A も作らない
ようにして揃える必要があり、その場合でも**同じターゲットの `libpart.a` は
作られて `libpart.stripped` は作られない**という食い違いは残る。

### なぜ内側から見つからないか

`artifacts` の検査は、宣言した派生が作られることを確かめれば足りる。その際に
置くフィクスチャは `bin` に付けるか、ライブラリ単体（A の形）になりやすい。
**ライブラリに `artifacts` を付け、かつ同じパッケージにそれを使う `bin` が
ある**という組み合わせが、両方を1つのフィクスチャに入れないと現れない。

B と C の差が「名指ししたかどうか」であることも、内側からは正常な最適化に
見える。外から見ると、同じ宣言が別の結果を出しているだけである。

### 検査

`projects/19-artifacts` の
`a library keeps producing its derived file when a binary depends on it`。
`17bd54e` で修正された。

対照として A と C にあたる場合も通常の検査として置いてある。

- `a standalone library produces its derived file`
- `the library archive is still produced as a dependency`
- `and then the derived file appears`（名指しした場合）

---

## F-023

報告先: [sabas0ba/dowel#68](https://github.com/sabas0ba/dowel/issues/68)

**転送した機能名 `<パッケージ>/<機能>` が構成の識別子に入り、`/` がパス
区切りとして展開される。1つの構成が2階層のディレクトリになる。**

種別: 実装。未修正（`af7d391`）。`apps/jsonfmt` を組んでいて踏んだ。

### 観測

```toml
# cli/dowel.toml
[features]
deep = ["jsonfmt-core/deep"]
```

```console
$ dowel build --features=deep
built: .../.dowel/build/x86_64-unknown-linux-gnu-debug-deep+jsonfmt-core/deep/bin/jsonfmt

$ find .dowel/build -mindepth 1 -maxdepth 1
.dowel/build/x86_64-unknown-linux-gnu-debug
.dowel/build/x86_64-unknown-linux-gnu-debug-deep+jsonfmt-core   ← 名前が切れている
```

機能の**転送そのものは正しく働く**。組んだ実行ファイルは下位の機能が効いた
値を返す（上限が 256 → 4096）。壊れているのは置き場所の名前だけである。

### 期待

構成の識別子に入れる前に、パスとして使えない文字を潰す。同じ機能集合が同じ
識別子になり、違う機能集合が違う識別子になることだけが要件であり、可逆で
ある必要は無い。ただし潰し方が衝突を生まないことは要る。

根拠は `docs/13-semantics.md` の「one build directory per configuration」。
`.dowel/build/<構成>` が1ディレクトリであるという前提の上に、掃除・成果物の
収集・CI の成果物アップロードが乗っている。

### なぜ内側から見つからないか

機能の転送を使い、**かつ組み上がった置き場所を見る**必要がある。転送の検査は
「依存先で機能が有効になったか」を見れば足り、そのときビルドディレクトリの
名前は関心の外である。単一パッケージの機能名に `/` は現れない。

### 検査

`apps/jsonfmt` の `a forwarded feature does not split the build directory in two`。
`17bd54e` で構成の識別子が1階層に畳まれ、`<パッケージ>--<機能>` になった。

転送そのものが働くことは `a feature forwarded to a dependency reaches it` として
通常の検査に置いてある。

---

## F-024

報告先: [sabas0ba/dowel#69](https://github.com/sabas0ba/dowel/issues/69)

**記録したコマンドが今回計画した分だけで上書きされる。`dowel test` や
`dowel build <target>` のような狭い呼び出しのあとに全体を組むと、何も編集して
いないのにやり直しが走る。**

種別: 実装。未修正（`af7d391`）。`apps/jsonfmt` を組んでいて踏んだ。

### 観測

パッケージ2つ、目標4つ、全体で 10 アクション。

```console
$ dowel build --log-level=debug     # planned 10, ran 10
$ dowel build --log-level=debug     # planned 10, loaded 10, ran 0
$ dowel test  --log-level=debug     # planned  8, loaded 10, ran 0
$ dowel build --log-level=debug     # planned 10, loaded  8, ran 2   ← 減っている
$ dowel build --log-level=debug     # planned 10, loaded 10, ran 0
```

`test` に限らない。`dowel build <target>` でも同じで、こちらは**交互にする
限り永久に繰り返す**。

```
  build jsonfmt    loaded 10, ran 0 actions (skipped 6)
  build 全部       loaded 6,  ran 4 actions (skipped 6)
  build jsonfmt    loaded 10, ran 0 actions (skipped 6)
  build 全部       loaded 6,  ran 4 actions (skipped 6)
```

一方向は無害である。全体を組んだあとの `test` は 0 件で済む。広い方が狭い方を
含むためで、**壊れるのは狭い→広いの向きだけ**である。

### 期待

記録を**併合**する。今回計画しなかったアクションの記録は残す。記録の役目は
「この成果物が今もそのコマンドの産物か」を言うことであり、計画に無かったものの
記録を捨てる理由は無い。

根拠は `docs/00-overview.md` 2節の「増分の費用は変更の大きさに比例する」。
ここで比例しているのは変更の大きさではなく、**直前の呼び出しが何を計画したか**
である。

### なぜ内側から見つからないか

増分の検査は、たいてい同じ呼び出しを2回繰り返して「2回目は 0 件」を見る。
その形では現れない。現れるのは**呼び出しの形を変えたとき**であり、しかも
狭い→広いの順でだけである。`build` → `test` の順で検査すると通る。

本スイートの `05-incremental` と `14-scale` も同じ形（同じ呼び出しの反復）で
あり、この見落としを共有していた。実アプリの層を足して初めて出た。

### 検査

`apps/jsonfmt` の以下 2 件。いずれも `17bd54e` で修正された。

- `running the tests does not make the next build redo work`
- `building one target does not make the next full build redo work`

対照として `and a full build leaves nothing for the tests to redo` を通常の
検査として置いてある。壊れているのが向きであることを示す。

---

## F-025

報告先: [sabas0ba/dowel#70](https://github.com/sabas0ba/dowel/issues/70)

**`link_flags` は `List<Str>` であり `file()` を受けない。フラグの中の相対
パスはビルドディレクトリ基準で解決されるため、パッケージの中のリンカ
スクリプトを指す方法が無い。**

種別: 実装。未修正（`af7d391`）。`apps/blink` を組もうとして踏んだ。

### 観測

`ld/app.ld` を木の中に置き、3通り試した。いずれも `cannot open linker script
file` になる。

```
link_flags = ["-T", "ld/app.ld"]
link_flags = ["-Wl,-T,ld/app.ld"]
link_flags = ["-Lld", "-Tapp.ld"]        # -L も同じ基準で解決される
```

`file()` は型で拒まれる。

```console
error[type-mismatch]: `link_flags` is List<Str> but List<Path> was given
```

絶対パスなら通り、配置も効く（FLASH の先頭 `0x00000000` に載る）。リンクの作業
ディレクトリはビルドディレクトリである（`-Wl,-Map=where.map` がそこに出る）。

同じ木で `includes = [dir("ld")]` と書くと引数は**絶対パス**になる。パッケージ
相対の道を絶対へ直す機構は既にあり、`link_flags` からそこへ届かないだけである。

### 期待

`link_flags` の中でパッケージ相対のファイルを指せるようにする。`List<Str |
Path>` にするのが既存の形に一番近い。

```
link_flags = ["-nostdlib", "-T", file("ld/app.ld")]
```

根拠は `docs/12-build-reference.md`。

> `Path` is a distinct type from `Str`: ... the language has no string
> concatenation with which to build one.

文字列の連結が無いことは意図された設計である。そのぶん、**道を要する場所には
`Path` を渡せる必要がある**。今は「道を要するのに `Str` しか受けない場所」が
1つ残っている。

ベアメタルではリンカスクリプトを省略できないため、この1点で組み込みの構成が
マニフェストに書けない。

### 実害の大きさ

配置を決めないと、既定のリンカスクリプトが選んだ番地に載る。

| | 最初の LOAD |
|---|---|
| スクリプトあり | `0x00000000`（flash の先頭。ベクタ表はここに要る） |
| スクリプトなし | `0x00008000`（何も割り当てられていない番地） |

実害は像の大きさでも配置の見た目でもなく、**立ち上がらないこと**に出る。
この木は `qemu-system-arm -M mps2-an386 -semihosting` で実際に走るため、
そこまで確かめられる。

```console
$ dowel test --target=thumbv7em-none-eabihf     # スクリプトなし
qemu: fatal: Lockup: can't escalate 3 to HardFault (current priority -1)
test blink:onhw ... FAILED

$ dowel test --target=thumbv7em-none-eabihf     # 絶対パスで -T を渡した
blink: ok
test blink:onhw ... ok (55ms)
```

リセット時、CPU は `0x00000000` から2語を読む。そこに何も無ければ、スタック
ポインタも入口も不定のまま実行が始まり、最初の例外で lockup する。書き込み器に
食わせる前の段階で、像は既に起動しない。

### なぜ内側から見つからないか

本体のフィクスチャはホスト向けにリンクする。ホストの既定のリンカスクリプトで
足りるため、スクリプトを指す必要が一度も生じない。`link_flags` の検査も `-lm`
や `-pthread` のような**道を含まないフラグ**で足りる。道を含むフラグを渡す例が
無ければ、解決の基準がどこかという問いも立たない。

### 検査

`apps/blink` の
`a linker script inside the package can be named from the manifest`。
known_issue F-025 である。

`17bd54e` で `link_flags` が `List<Str | Path>` になり、`file()` の要素が
絶対パスへ展開されるようになった。木の中のスクリプトをそのまま指せる。

指せることの帰結を、次の通常の検査で見ている。

- `and the image lands at the start of flash, where it can be programmed`
- `and the firmware runs on emulated hardware and its test passes`
- `the firmware reports through semihosting, so the result comes from the device`

指さなかったときに何が起きるかは、外して確かめる。

- `without the script the image is placed where the vector table cannot be`
- `and then the processor locks up at reset, having read no vector table`

スクリプトが効いたときは、生イメージの先頭2語を直に読んで確かめている。
`the first word of the image is the initial stack pointer` と
`and the second is a reset handler inside flash`。リセット時に CPU が読むのは
その2語であり、配置が正しいかどうかはそこに現れる。

---

## F-026

報告先: [sabas0ba/dowel#71](https://github.com/sabas0ba/dowel/issues/71)

**パッケージが対象とする triple を宣言できない。`[toolchain.<triple>]` だけを
宣言した木でも、`--target` を付けなければホスト向けの計画が立つ。**

種別: 要望。未修正（`af7d391`）。F-025 と同じ層で踏んだ。

### 観測

そこから先は、フラグがホストのコンパイラに通るかどうかで結果が変わる。
どちらの形でも dowel は何も言わない。

**その1 — 通らない場合（`apps/blink` はこちら）。**

```console
$ dowel build                      # --target を付け忘れた
cc: error: unrecognized command-line option '-mthumb'

$ dowel build --message-format=json | jq -r '.code'
                                   # 何も出ない
```

落ちること自体は良いが、利用者が見るのは**フラグについての苦情**である。
「この木はホスト向けではない」とはどこにも書かれていない。

**その2 — 通る場合（対象が `aarch64-unknown-linux-gnu` など）。**

```console
$ dowel build
built: .../x86_64-unknown-linux-gnu-debug/bin/firmware
built: .../x86_64-unknown-linux-gnu-debug/bin/firmware.bin
```

x86-64 の「ファームウェア像」が出る。`artifacts` の派生まで、ホストの
`objcopy` で作られる。

これは `docs/11-toml-reference.md` の記述どおりの動作である（`c` はホストでは
`cc` を既定とする）。F-015 で入った拒否は**ホスト以外の** triple に対するもの
であった。

### 期待

パッケージが対象とする triple を宣言できるようにする。

```toml
[package]
targets = ["aarch64-unknown-linux-gnu"]
```

宣言が無ければ現状どおり。宣言があって求められた triple がそこに無ければ拒む。

`[toolchain.<triple>]` の宣言そのものを対象の一覧とみなす手もあるが、その
読み方だと「ホスト向けにも組めるが、クロスのときだけ道具を替えたい」という
普通の木（`apps/httpd` はそちら）が書けなくなる。**対象の宣言と道具の宣言は
別の事柄**である。

根拠は `docs/00-overview.md` 2節の「記録されない入力を排除する」。どの triple
向けの木なのかという前提が記録の外にある。

### なぜ内側から見つからないか

本体のフィクスチャはホストで組めるものばかりである。ホスト向けに組んで意味の
無い木——libc を持たず、入口が `_reset` である木——が入力として現れない。

F-015 の検査も「宣言の無い triple を求めたら拒む」向きであり、その逆
（**ホストを求められたが、この木にホストの構成は無い**）は形が違う。

### 検査

`apps/blink` の `a package can say which targets it is for`。`17bd54e` で
`[package] targets` が入り、宣言外の triple は `unsupported-target` で断られる。

- `and leaving out --target is refused`
- `by the package itself, with a diagnostic of its own`
- `the message is about the package's targets, not about a flag`
- `and the host compiler is never reached`

宣言を外すと以前の形に戻ることも見ている
（`without the declaration the host compiler is what complains`）。
断っているのが `targets` であることは、外して初めて言える。

---

## F-027

報告先: [sabas0ba/dowel#74](https://github.com/sabas0ba/dowel/issues/74)

**`[runner.<triple>]` を `dowel.toml` に書くと診断が1件も出ずに無視される。
そのうえで `dowel test` が `missing-runner`（宣言が無い）と言う。宣言はして
ある。置き場所が違うだけである。**

種別: 実装。未修正（`af7d391`）。`apps/blink` を qemu で走らせようとして踏んだ。

### 観測

```toml
# dowel.toml  ← 置き場所を間違えた
[toolchain.thumbv7em-none-eabihf]
c       = "arm-none-eabi-gcc"
objcopy = "arm-none-eabi-objcopy"

[runner.thumbv7em-none-eabihf]
command = "qemu-system-arm"
args    = ["-M", "mps2-an386", "-nographic", "-semihosting", "-kernel"]
```

```console
$ dowel check --target=thumbv7em-none-eabihf
check passed: 1 packages, 3 targets

$ dowel check --message-format=json | jq -r '.code'
                                   # 何も出ない

$ dowel test --target=thumbv7em-none-eabihf
error[missing-runner]: no runner is declared for `thumbv7em-none-eabihf`
  = help: declare one, for example `[runner.<triple>]` with `command = "qemu-..."`
```

`dowel.build` へ移すとそのまま動く。

### 期待

`dowel.toml` の未知の最上位テーブルを拒む。名前が `dowel.build` 側の語彙に
あるなら、置き場所を指摘する。

```
error[unknown-table]: `[runner.thumbv7em-none-eabihf]` does not belong in dowel.toml
  = note: runners are declared in dowel.build
```

根拠は `docs/00-overview.md` 2節の「記録されない入力を排除する」。書いたつもりの
宣言が読まれていない状態は、記録の外にある入力そのものである。F-019（#59）で
`[toolchain]` の未知の**キー**は拒まれるようになった。未知の**テーブル**は
まだ素通りする。同じ理屈が一段上にも要る、という形である。

### なぜ踏みやすいか

**`[toolchain.<triple>]` は `dowel.toml`、`[runner.<triple>]` は `dowel.build`**
である。組み込みの構成では、この2つを続けて書く。同じ triple を鍵に持ち、名前も
対になっているため、片方の隣にもう片方を書くのは自然な間違いである。

そのうえ診断が、**まさに書いたはずのもの**が無いと言い、書けと勧める。利用者は
自分の `dowel.toml` を見て、書いてあることを確かめ、途方に暮れる。

### なぜ内側から見つからないか

本体のフィクスチャは、正しい置き場所に書いたものを入力にする。**誤った場所に
書いたマニフェスト**は入力として現れない。`missing-runner` の検査も「宣言が
無いときに出ること」を確かめれば足り、「宣言はあるが読まれていないとき」は
同じ入力にならないため、両者の区別が問われない。

### 検査

`apps/blink` の `a runner written into dowel.toml is not silently ignored`。
`17bd54e` で `dowel.toml` の未知の最上位テーブルが `unknown-table` で拒まれる
ようになった。

- `and the failure is about the misplaced table, not about a missing declaration`
- `putting the runner back where it belongs makes the tests run again`
- `the runner ends its args with -kernel, and dowel appends the artifact`

---

## F-028

報告先: [sabas0ba/dowel#78](https://github.com/sabas0ba/dowel/issues/78)

**`abi` の併合規則は `must_equal` である。C のライブラリと C++ の利用者は
正しく書けば違う札になるが、違う札は拒まれる。C++ の利用者は自分の言語では
なくライブラリの札を書き写すしかない。**

種別: 実装／設計。未修正（`af7d391`）。`apps/hashx` を配ろうとして踏んだ。

### 観測

C のライブラリ（見出しは `extern "C"`）と、それを使う C++ の実行ファイル。

```
[lib.hashx.public]   abi = "gnu11"
[bin.hashcxx.private] abi = "gnu++17"     # 本当の言語
```

```console
$ dowel -C cxxtool build
error[abi-mismatch]: `abi` does not match: "gnu++17" vs "gnu11"
    = note: the merge rule of `abi` is must_equal. a mismatch fails instead of propagating
```

`abi = "gnu11"` と書き写せば通り、走る。C の利用者と C++ の利用者は同じ書庫
から同じ答を得る。

### 期待

`extern "C"` の面しか持たないライブラリを、どの言語の利用者とも繋げられる
ようにする。境界を指す札（`abi = "c"`）か、札に両立の規則を持たせるか。

根拠は `docs/13-semantics.md`。

> This is the whole ABI check today: `abi` labels are compared before
> linking, turning a would-be runtime ODR breakage into a build failure

ODR 違反は C++ の同じ実体が違う定義で現れることであり、**`extern "C"` の
境界を跨いだ呼び出しには起きない**。多重定義もテンプレートも名前の飾りも
無いためである。

回避策が「利用者が札を書き写す」ことなので、**札が意味を失う**点が重い。
`gnu11` と書いた C++ の目標が増えると、札は「本当の ABI」ではなく「この
ライブラリを使う組」を表す名前に変わる。ABI 検査を中心に据える設計にとって
それは看板の毀損である。

配る側の視点ではもう一段厄介で、ライブラリの作者は利用者を知らない。札を
1つ決めることは、**すべての利用者にその札を強制する**ことである。

`docs/90-roadmap.md` 第6段の「ABI ラベルの計算」が入ったとき、C のライブラリと
C++ の利用者が非互換と判定されないことが要る。今回の形はその最小の例である。

### なぜ内側から見つからないか

本体のフィクスチャで C と C++ が混ざるのは、同じパッケージの中か、札を
揃えて書いた木である。揃えるのが自然な書き方なので、揃えない理由が生じない。

揃えない理由は**ライブラリを配ること**から来る。作者は利用者の言語を知らず、
利用者は自分の言語を書きたい。この非対称が入力に現れて初めて見える。

### 検査

`apps/hashx` の
`a C++ consumer can declare its own abi label and still use a C library`。
`17bd54e` で境界を指す札 `abi = "c"` が入った。

- `the library names the C ABI boundary rather than its own language`
- `and the C++ consumer declares its own language`
- `and the C++ consumer gets the same answer from the same archive`

札の緩さが境界に限ることも見ている。C ABI を名乗っていない目標どうしが
食い違えば、これまでどおり落ちる。

- `two labels that are not the boundary are still compared`
- `and the refusal comes with a diagnostic code and both provenances`

---

## F-029

報告先: [sabas0ba/dowel#79](https://github.com/sabas0ba/dowel/issues/79)

**`[[dependencies]]` の1つの項目が `path` と `git`（や `version`）の両方を
名乗っても、診断が1件も出ない。実際には `path` が使われ、もう一方は読まれも
しない。**

種別: 実装。未修正（`af7d391`）。ライブラリの出所を切り替えていて踏んだ。

### 観測

```toml
[[dependencies]]
name = "hashx"
path = "../lib"
git  = "https://example.invalid/hashx"
rev  = "<40 桁の sha>"
```

```console
$ dowel check
check passed: 2 packages, 3 targets     # 無診断
$ dowel build
built: .../bin/hashsum                  # ../lib から組まれている
```

`git` の宛先は解決できない TLD だが、取りに行かないため何も起きない。
`path` + `version` も同じで、pkg-config は引かれず版の下限も見られない。

`git` を単独で書いて `rev` を欠かすと `unpinned-dependency` で拒まれる。
出所キーの検査そのものは在って、**組み合わせだけが見られていない**。

### 期待

2つ以上の出所を名乗る項目を拒む。`incomplete-dependency` の対である。
`docs/11-toml-reference.md` は反対側にだけ規則を置いている。

> An entry with none of `path` / `git` / `version` is `incomplete-dependency`.

0個は拒み、2個は黙って受ける、という非対称になっている。

根拠は `docs/00-overview.md` 2節の「記録されない入力を排除する」。書いた宣言
のうち片方が読まれておらず、どちらが使われたのかがマニフェストから読めない。

### なぜ踏みやすいか

ライブラリの出所は開発の途中で変わる。手元で直しながら使う（`path`）から、
固まって配る（`git` + `rev`）への切り替えは「片方を消してもう片方を書く」
操作であり、消し忘れは普通に起きる。とくに path → git の向きでは、手元に
その木があるので組めてしまう。**気づくのは、その木を持たない誰かが組んだとき**
である。

### なぜ内側から見つからないか

本体のフィクスチャは出所を1つ書いたものを入力にする。0個が検査されているのは
それが「書き忘れ」という自然な失敗だからで、2個は「切り替えの途中」という
**時間のかかる失敗**である。単一の木を1回組む検査では、その途中が現れない。

### 検査

`apps/hashx` の `a dependency entry that names two sources is refused` と
`the same holds when the two sources are a path and a version`。
`17bd54e` で修正され、規則が両側に揃った。

- `and the build does not fall back to the local path`
- `a dependency entry that names no source at all is refused`

---

## F-030

報告先: [sabas0ba/dowel#80](https://github.com/sabas0ba/dowel/issues/80)

**パッケージの `version` を翻訳へ届ける手立てが無い。ライブラリの版は
`dowel.toml` と公開する見出しに別々に書かれ、一致は誰も見ていない。**

種別: 要望。未修正（`af7d391`）。F-028 / F-029 と同じ層で踏んだ。

### 観測

```console
$ sed -i 's/version = "0.4.0"/version = "9.9.9"/' dowel.toml
$ dowel build --message-format=json | jq -r '.code'
                                   # 何も出ない
$ ./hashsum --version
hashsum (hashx 0.4.0)              # 見出しの値のまま
```

利用者が `dowel.toml` を見て 9.9.9 だと判断し、実行時には 0.4.0 が返る、
という食い違いが黙って成立する。

`defines` に書こうにも参照できる語彙が無い（`docs/12-build-reference.md`
3節）。`cfg.opt` / `cfg.target` / `host.*` / `feature.*` / `tc.*` のどれも
パッケージの情報を持たない。文字列の連結が無いのは意図された設計
（ADR-0004）なので、組み立てる回避もできない。

### 期待

パッケージの情報を `cfg` と同じ形で参照できるようにする。

```toml
defines = { HASHX_VERSION = pkg.version }
```

`version` は `dowel.toml` に既にあり、評価の前に確定している値である。
根拠は `docs/00-overview.md` 2節の「記録されない入力を排除する」。今は同じ
事実が2か所に別々に記録されていて、一致は誰も見ていない。

### なぜ内側から見つからないか

`[package] version` は依存の解決（pkg-config の下限、`dowel.lock`）で使われる
が、**自分自身の版を自分の成果物へ埋める**用途は、ライブラリを配る側になって
初めて生じる。利用する側の検査では、版はいつも「相手の版」である。

### 検査

`17bd54e` で `pkg.name` / `pkg.version` が入った。版は1か所にしか無くなり、
突き合わせる相手そのものが消えた。`apps/hashx` の

- `the library takes its version from the manifest instead of repeating it`
- `so the public header holds no copy of it`
- `and the artifact reports the version the manifest declares`
- `moving the manifest version moves what the artifact answers`

最後の1件が要点である。写しが無いのだから、ずれようがない。

---

## F-031

報告先: [sabas0ba/dowel#82](https://github.com/sabas0ba/dowel/issues/82)

**排他な機能を宣言できない。`when` を並べて実装を選ぶ木は、両方の機能が
立つと両方を翻訳する。そこから先は目標の種別で分かれ、`bin` ではリンカが
落とし、`lib` では黙って片方が勝つ。**

種別: 要望。未修正（`af7d391`）。`apps/plot` で描画のバックエンドを選ぼうと
して踏んだ。

正しい書き方はある。`match feature.x { true => a, false => b }` なら選ばれる
のは常に1つである。所見にしたのは、**間違えたときに何も言われない**ことと、
その結果が目標の種別で2通りに分かれることについてである。

### 観測

```toml
# B: when を2つ並べる（排他にならない）
sources = [
    file("src/shell_x11.c")      when feature.x11,
    file("src/shell_headless.c") when feature.headless,
]
```

機能は加算である。`--features=x11` は `default = ["headless"]` を落とさない
ため、両方が立ち、両方が翻訳される。

**`bin` に直に並べた場合** — `check` は通り、リンカが落とす。

```console
$ dowel check --features=x11
check passed: 4 packages, 5 targets
$ dowel build --features=x11
/usr/bin/ld: multiple definition of `shell_show'
```

利用者が見るのはリンカの苦情であり、dowel からの診断は1件も出ない。

**`lib` に入れた場合** — 組み上がる。

```console
$ dowel build --features=epoll        # default = ["poll"] を落とし忘れた
built: .../debug-epoll+poll/bin/httpd
$ ./httpd --waiter
epoll sequential                      # poll の側は死んだ翻訳単位になった
```

両方の目的ファイルが同じ書庫に入り、リンカは記号を最初に満たした部材だけを
引く。`sources` の並び順を入れ替えても結果は変わらないので、**どちらが
生き残るかをマニフェスト側から決める手立ても無い。**

組み上がり、テストも通り（片方しか走っていないだけである）、成果物だけが
頼んだのと違うものになる。こちらの方が危ない。

### 期待

排他を宣言できるようにする。

```toml
[features]
exclusive = [["headless", "x11"]]     # この2つは同時に立てない
```

あるいは最低限、`docs/12-build-reference.md` の `when` の説明に「実装の択一
には `match` を使う。`when` を並べても排他にはならない」と書く。

根拠は `docs/00-overview.md` 2節の「記録されない入力を排除する」。`lib` の
場合、**どちらの実装が成果物に入ったかが記録のどこにも無い**。リンカの解決順
という、マニフェストからは見えないものが決めている。

### なぜ内側から見つからないか

条件付きソースの検査は、その機能だけを立てて確かめる（`--no-default-features
--features=x` の形）。それは正しい使い方であり、正しく動く。問題は正しくない
使い方をしたときで、しかも `lib` の場合は**失敗として現れない**ため、検査
項目として立てにくい。「組めたが中身が違う」を捕まえるには、成果物に実装を
名乗らせる仕掛け（`--waiter` のような）が要る。

### 検査

`17bd54e` で `[features] exclusive` が入った。両方立てた木は
`conflicting-features` で拒まれる。`bin` の側は `apps/plot`、`lib` の側は
`apps/httpd` に置いてある。

- `a package can declare which of its features are exclusive`
- `and asking for both at once is refused`
- `the diagnostic says the other one came from default, which is the usual cause`
- `a package can declare that its two waiters are exclusive`
- `and a package that would end up with two implementations of one interface says so`
- `the build does not proceed to pick one silently`

診断が `default` を名指しすることが効く。両方立つ原因はほぼ常にそれであり、
`--no-default-features` が落とし方だからである。

---

## 所見に至らなかったもの

報告しないが、記録しておく。

- **`CLAUDE.md` の現況** — `a8a59e7` の時点で「設計検討段階。実装は未着手。
  本リポジトリは設計文書のみを含む」とあり、`docs/91-implementation-status.md`
  と食い違っていた。本スイートの検査対象ではないため所見に含めていない
- **`compile_commands.json` をパッケージ直下にも書く** — 言語サーバのための
  意図的な配置と読める。`.gitignore` への記載が要る点は利用者側の話であり、
  本体の欠陥ではない
- **共有オブジェクトを作れず、dowel を使わない相手へ渡す形も出ない** —
  `apps/hashx` で踏んだ。`lib` は静的な書庫だけであり、`.so` も `.pc` も
  CMake の設定も出ない。ただし `docs/90-roadmap.md` は第3段に「CMake の
  `find_package` 設定を出す」、第6段に「書き出し対象（C ABI / CPython
  拡張ほか）」を既に載せている。報告しても重なるだけなので、現状の記録に
  留めた（`what a build produces today is one static archive and nothing a
  foreign consumer could read`）
