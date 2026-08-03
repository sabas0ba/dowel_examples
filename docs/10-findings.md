# 所見

本スイートが外側から見つけたもの。

F-001 から F-009 までの 9 件は `07f16ec` で、F-010 / F-012 / F-013 は
`95daf9f` で、F-014 / F-015 は `3e84cbd` で、F-016 / F-017 は `a9c1619` で
修正された。F-008 はさらに `9ed13f4` で二段目の決着を見ている。記録は残す。
何を見てどう報告したかが、次に同種のものを見つけるときの型になるためである。
対応する検査は `known_issue` を外し、通常の検査として残してある。直った
ものを消すと、退行したときに気づけない。

未修正は F-018 / F-019 / F-020 / F-021、および F-011 の残っている側である。対応する検査は
`known_issue` を付けてあり、本体が直すと `XPASS` になって落ちる。

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
| [F-018](#f-018) | `lib` の `private` な `link_flags` がリンクの閉包に乗らない | 実装 | [#56](https://github.com/sabas0ba/dowel/issues/56) | 未修正 |
| [F-019](#f-019) | `[toolchain]` の未知のキーが黙って受理され、道具が既定値へ後退する | 実装 | [#59](https://github.com/sabas0ba/dowel/issues/59) | 未修正 |
| [F-020](#f-020) | 生成物を変換・検査する道具を宣言できず、後処理の場所も無い | 要望 | [#60](https://github.com/sabas0ba/dowel/issues/60) | 未修正 |
| [F-021](#f-021) | 構成レベルのフラグが `link_flags` には残り、下書きの見出しと食い違う | 実装 | [#61](https://github.com/sabas0ba/dowel/issues/61) | 未修正 |

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

種別: 実装。未修正（`2e99fc7`）。ADR-0015 の `version` 依存を試していて
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

### 検査

`projects/17-deps` の以下 2 件。いずれも known_issue F-018 である。

- `the link flags of a private system dependency reach the final link`
- `a library that keeps a system dependency private still links its dependent`

対照として次の2件を通常の検査として置いてある。

- `the archive of a private system dependency reaches the final link`
  — 閉包を辿る機構が既にあることを示す
- `keeping a system dependency private does not leak its includes`
  — `private` が翻訳に対しては正しく働いていることを示す

2つ目は `xfail` の2件と**同時に**通ることが期待値である。片方だけを満たす
直し方（全部 public 扱いにする）を通さないための組である。

---

## F-019

報告先: [sabas0ba/dowel#59](https://github.com/sabas0ba/dowel/issues/59)

**`[toolchain]` の未知のキーが診断されず、道具の綴り間違いが既定値への無言の
後退になる。**

種別: 実装。未修正（`a9c1619`）。

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

### 検査

`projects/18-tools` の以下 3 件。いずれも known_issue F-019 である。

- `a misspelled toolchain key is refused`
- `the refusal suggests the tool that was meant`
- `a misspelled cross archiver does not silently fall back to the host tool`

対照として `spelling the key correctly does select the cross archiver` を通常の
検査として置いてある。3件が見ているのは「宣言が効かないこと」ではなく、
**効かないことが知らされないこと**である。

---

## F-020

報告先: [sabas0ba/dowel#60](https://github.com/sabas0ba/dowel/issues/60)

**生成物を変換・検査する道具（objcopy / size / objdump など）を宣言できず、
生成物に対して何かを走らせる場所も無い。**

種別: 要望。未修正（`a9c1619`）。F-016 と同じ形の要望である。

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

### 検査

`projects/18-tools` の以下 3 件。いずれも known_issue F-020 である。

- `a transform tool can be declared alongside the archiver`
- `an inspection tool can be declared alongside the archiver`
- `a bin target can produce a raw binary image`

前2件は `tc.objcopy` / `tc.size` が構成の語彙から引けるかどうかで見る。
実装がどの構文を採っても通る観測である。3件目だけは提案した形を書いており、
実装が別の形を採れば書き換わる。**変換がグラフに乗る**という期待そのものは
変わらない。

---

## F-021

報告先: [sabas0ba/dowel#61](https://github.com/sabas0ba/dowel/issues/61)

**構成レベルのフラグが `link_flags` には残っており、下書きの見出しが
「写していない」と述べる内容と食い違う。**

種別: 実装。未修正（`a9c1619`）。F-017 の続きである。

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

### 検査

`projects/16-migrate` の
`the draft carries no NDEBUG from a release CMake build type`。
known_issue F-021 である。

翻訳の側（`the draft carries no optimization flag from the CMake build type`
ほか）は通常の検査として通っており、F-017 の修正が効いていることを示している。

---

## 所見に至らなかったもの

報告しないが、記録しておく。

- **`CLAUDE.md` の現況** — `a8a59e7` の時点で「設計検討段階。実装は未着手。
  本リポジトリは設計文書のみを含む」とあり、`docs/91-implementation-status.md`
  と食い違っていた。本スイートの検査対象ではないため所見に含めていない
- **`compile_commands.json` をパッケージ直下にも書く** — 言語サーバのための
  意図的な配置と読める。`.gitignore` への記載が要る点は利用者側の話であり、
  本体の欠陥ではない
