# 所見

本スイートが外側から見つけたもの。dowel `0.0.1`（`a8a59e7`）に対する観測である。

各項目は次の形で記録する。

- **観測** — 何をしたら何が起きたか
- **期待** — 何を期待したか。および、その期待の根拠（本体の文書）
- **なぜ内側から見つからないか** — 本体の既存の層では原理的に現れない理由
- **検査** — 本スイートのどの検査が対応するか（`known_issue` で登録してある）

`xfail` として登録してあるため、本体が直ると `XPASS` になってスイートが落ちる。
そのとき本文書の状態を更新し、`known_issue` の宣言を外す。

## 一覧

| # | 内容 | 種別 | 報告先 |
|---|---|---|---|
| [F-001](#f-001) | 宣言されていない機能名を `--features` に渡しても診断が出ない | 実装 | [#14](https://github.com/sabas0ba/dowel/issues/14) |
| [F-002](#f-002) | `dowel.build` の `feature.<未宣言>` が黙って偽になる | 実装 | [#13](https://github.com/sabas0ba/dowel/issues/13) |
| [F-003](#f-003) | 有効化されていない `optional` 依存が読み込まれる | 実装 | [#15](https://github.com/sabas0ba/dowel/issues/15) |
| [F-004](#f-004) | `check` が計画段の誤りを見つけない | 実装／文書 | [#19](https://github.com/sabas0ba/dowel/issues/19) |
| [F-005](#f-005) | `missing-manifest` に位置情報が無い | 実装 | [#18](https://github.com/sabas0ba/dowel/issues/18) |
| [F-006](#f-006) | 修正提案の範囲が誤っており、適用するとマニフェストが壊れる | 実装 | [#12](https://github.com/sabas0ba/dowel/issues/12) |
| [F-007](#f-007) | 併合衝突の人間向け描画が片側の位置しか出さない | 実装 | [#16](https://github.com/sabas0ba/dowel/issues/16) |
| [F-008](#f-008) | C++ のソースが黙って受理され、リンカの誤りになる | 実装／文書 | [#19](https://github.com/sabas0ba/dowel/issues/19) |
| [F-009](#f-009) | 宣言したツールチェーンの実在を確認しない | 実装 | [#19](https://github.com/sabas0ba/dowel/issues/19) |

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

### 検査

`projects/04-diagnostics` の`the manifest still passes check after applying the suggestion`。
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

### 検査

`projects/04-diagnostics` の
`building a C++ source produces a diagnostic of dowel's own`
`the C++ failure is not reported in the linker's words`。

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

### 検査

`projects/04-diagnostics` の
`declaring a toolchain that does not exist fails with a source location`
`the toolchain failure is not reported in the shell's words`。

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

### 検査

`projects/04-diagnostics` の
`merge-conflict renders the dependent side of the conflict too` ほか1件。

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

### 検査

`projects/04-diagnostics` の
`check finds invalid-source as well` ほか1件。

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

### 検査

`projects/04-diagnostics` の`missing-manifest points at the offending source`。

---

## 所見に至らなかったもの

報告しないが、記録しておく。

- **`CLAUDE.md` の現況** — 「設計検討段階。実装は未着手。本リポジトリは
  設計文書のみを含む」とあるが、実装は進んでおり `docs/91-implementation-status.md`
  と食い違う。本スイートの検査対象ではないため所見に含めないが、
  次に本体へ触れる際に併せて直すのがよい
- **`compile_commands.json` をパッケージ直下にも書く** — 言語サーバのための
  意図的な配置と読める。`.gitignore` への記載が要る点は利用者側の話であり、
  本体の欠陥ではない
