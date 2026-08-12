# 所見

本スイートが外側から見つけたもの。

報告した 58 件のうち 56 件が修正されている。直ったものの記録も検査も残す。
**何を見てどう報告したか**が、次に同種のものを見つけるときの型になるためで
あり、消してしまうと退行したときに気づけない。

## 直った波

修正はまとまって入る。どの版で何が直ったかを追えるように並べておく。

| 所見 | 直った版 | まとまりの中身 |
|---|---|---|
| F-001 〜 F-009 | `07f16ec` | 最初の9件 |
| F-010 / F-012 / F-013 | `95daf9f` | |
| F-014 / F-015 | `3e84cbd` | |
| F-016 / F-017 | `a9c1619` | |
| F-018 / F-019 / F-021 | `af7d391` | |
| F-008（二段目） | `9ed13f4` | 一度目の決着では残っていた側 |
| F-020（残り）、F-022 〜 F-031 | `17bd54e` | 検査の道具と、実アプリの層が最初に出した群 |
| F-032 〜 F-045 | `e12bac7` | テストフレームワーク（`cases` / `harness`） |
| F-046 〜 F-055 | `9858932` | デバッグ機能（ADR-0023 / ADR-0024）と、実践的なアプリが出した群 |
| F-056 / F-057 | `c154097` | 入ったばかりの機構（共有ライブラリ、Meson 移行）を使って出た2件 |

直った検査の扱いには2段階ある。**`known_issue` を外すだけでは足りない。**
新しい機構が入った場合は、その機構を実際に使う形へ書き換える。書き換えない
と、直ったことを確かめたことにならない——古い形のままの検査は、直る前の世界
について主張し続ける。

F-047 はその逆側の例である。**直ったのに検査が落ち続けた。** 元の検査は
「壊れたラベルが出力に現れないこと」を見ていたが、修正後の診断は拒んでいる
ラベルを引用して説明する。出力に現れることが正しい状態になったので、その
見方では偽の失敗になる。`XPASS` ではなく `FAIL` として出るため、修正が届いて
いないようにも見えた。**xfail が「壊れている証拠」に依存していると、直り方に
よっては検査の側が誤りになる。**

## 残っているもの

| 所見 | 内容 |
|---|---|
| [F-011](#f-011)（残り） | |
| [F-058](#f-058) | `template` を宣言したパッケージが `check` を通らない |

F-058 も、**入ったばかりの機構を実際のアプリに当てて**出た。`template`
（ADR-0035）を `apps/blink` に使った最初の `dowel check` で落ちている。
同じ形が続いている——機構そのものは動くが、それを使った木を**普段の入口から
触った**ときに初めて欠けが見える。

## 実アプリの層が出したもの

F-050 から F-058 は `apps/vision`（大きい依存）、`apps/winapp`（Windows）、
`apps/dsp`（1つの算法を4つの三つ組で）、`apps/hashx`（配る側のライブラリ）、
`apps/blink`（ベアメタル）を書く・書き換える過程で出た。**アプリケーションを書かないと現れない層**であり、性質を1つ
ずつ固定する `projects/` の側からは要求として立ち上がらなかったものである。

条件が2つ重なって初めて現れるものもある。F-054 と F-055 は**パッケージが
分かれていて、かつ三つ組が複数ある**ときにしか出ない——どちらか一方だけの木
では無害か、そもそも起きない。F-056 は**配るライブラリが自分の検査を持って
いる**ときにしか出ない。共有ライブラリのフィクスチャを書けば面は確かめられ
るが、そこに内側を見る検査を置く理由が無い。

## 記録の形

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
| [F-032](#f-032) | `should_fail` がシグナルによる異常終了を通す | 実装 | [#88](https://github.com/sabas0ba/dowel/issues/88) | 修正済み |
| [F-033](#f-033) | `timeout = 0` と負値が受理され、黙って無視される | 実装 | [#96](https://github.com/sabas0ba/dowel/issues/96) | 修正済み |
| [F-034](#f-034) | `--label` の空振りが終了状態 0 で終わる | 実装／文書 | [#89](https://github.com/sabas0ba/dowel/issues/89) | 修正済み |
| [F-035](#f-035) | 印字された事例のラベルをコマンドラインに渡せない | 要望 | [#93](https://github.com/sabas0ba/dowel/issues/93) | 修正済み |
| [F-036](#f-036) | `--failed` が、覚えている事例の消失を黙って緑にする | 実装 | [#91](https://github.com/sabas0ba/dowel/issues/91) | 修正済み |
| [F-037](#f-037) | 事例の型診断が、誤っている鍵ではなく事例全体を指す | 診断 | [#101](https://github.com/sabas0ba/dowel/issues/101) | 修正済み |
| [F-038](#f-038) | 事例の名前が検証されず、ラベルの文法を壊す | 実装 | [#97](https://github.com/sabas0ba/dowel/issues/97) | 修正済み |
| [F-039](#f-039) | 事例を表見出しで書いた診断が直し方を示さない | 診断 | [#98](https://github.com/sabas0ba/dowel/issues/98) | 修正済み |
| [F-040](#f-040) | 空の `cases` 表が黙って素の1件に落ちる | 実装 | [#99](https://github.com/sabas0ba/dowel/issues/99) | 修正済み |
| [F-041](#f-041) | 事例そのものを条件付きにできない | 要望／文書 | [#92](https://github.com/sabas0ba/dowel/issues/92) | 修正済み |
| [F-042](#f-042) | `schema dump` と LSP が `cases` を知らない | 実装／文書 | [#90](https://github.com/sabas0ba/dowel/issues/90) | 修正済み |
| [F-043](#f-043) | 事例を走らせずに一覧する方法が無い | 要望 | [#94](https://github.com/sabas0ba/dowel/issues/94) | 修正済み |
| [F-044](#f-044) | 結果の JSON が目標と事例を分けず、事例の属性を出さない | 実装 | [#100](https://github.com/sabas0ba/dowel/issues/100) | 修正済み |
| [F-045](#f-045) | 事例の作業ディレクトリが未文書・指定不可 | 文書／要望 | [#95](https://github.com/sabas0ba/dowel/issues/95) | 修正済み |
| [F-046](#f-046) | `debug_args` の挿し込み位置が `-kernel` で終わる runner を壊す | 実装 | [#107](https://github.com/sabas0ba/dowel/issues/107) | 修正済み |
| [F-047](#f-047) | ハーネスの列挙が返した事例名が検証されない | 実装 | [#108](https://github.com/sabas0ba/dowel/issues/108) | 修正済み |
| [F-048](#f-048) | 半分だけ宣言したスタブに「宣言が無い」と言う | 診断 | [#109](https://github.com/sabas0ba/dowel/issues/109) | 修正済み |
| [F-049](#f-049) | 落ちていない事例をデバッガの下で開けない | 要望 | [#110](https://github.com/sabas0ba/dowel/issues/110) | 修正済み |
| [F-050](#f-050) | Windows 対象の成果物名が `.exe` を知らない | 実装 | [#112](https://github.com/sabas0ba/dowel/issues/112) | 修正済み |
| [F-051](#f-051) | MSVC は名指しできるが宣言できない（引数が GNU の形） | 実装 | [#113](https://github.com/sabas0ba/dowel/issues/113) | 修正済み |
| [F-052](#f-052) | 同名のターゲットを2つ書け、伝播とオブジェクト経路が壊れる | 実装 | [#114](https://github.com/sabas0ba/dowel/issues/114) | 修正済み |
| [F-053](#f-053) | 対象の OS を指す語が無く、三つ組を数え上げるしかない | 要望 | [#115](https://github.com/sabas0ba/dowel/issues/115) | 修正済み |
| [F-054](#f-054) | 依存の `[toolchain]` が効かず、使う側すべてが写す | 診断／要望 | [#125](https://github.com/sabas0ba/dowel/issues/125) | 修正済み |
| [F-055](#f-055) | 目標を三つ組で絞れず、依存の `test` が使う側の build で組まれる | 要望 | [#126](https://github.com/sabas0ba/dowel/issues/126) | 修正済み |
| [F-056](#f-056) | 共有にするとライブラリ自身の検査が組めない | 要望 | [#134](https://github.com/sabas0ba/dowel/issues/134) | 修正済み |
| [F-057](#f-057) | Meson の移行が書庫とリンクの引数を翻訳の flags に混ぜる | 実装 | [#135](https://github.com/sabas0ba/dowel/issues/135) | 修正済み |
| [F-058](#f-058) | `template` を宣言したパッケージが `check` を通らない | 実装 | [#141](https://github.com/sabas0ba/dowel/issues/141) | 未修正 |

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

## F-032

報告先: [sabas0ba/dowel#88](https://github.com/sabas0ba/dowel/issues/88)

**`should_fail` はシグナルによる異常終了を「期待どおりの失敗」として通す。
JSON でも普通の非零終了と区別できない。**

種別: 実装。`e12bac7` で修正（`17bd54e` で観測）。`[test.<name>.cases]` を使って踏んだ。

### 観測

`rejects = { args = ["bad"], should_fail = true }` の処理を SIGSEGV に
差し替える。

```console
$ dowel test
test c:suite/rejects ... ok (7ms)
```
```json
{"target":"c:suite/rejects","passed":true,"timed_out":false,"exit_status":null,"launch_error":null}
```

`exit_status` が `null` になるのは**時間切れと同じ**で、`timed_out` でしか
区別できない。人間向けの行にもシグナルの話は出ない。

### 期待

シグナルによる終了は `should_fail` を満たさない。少なくとも報告する。

`should_fail` を書く場所は「壊れた入力を食わせる事例」であり、それは
**クラッシュが最も起きやすい事例**でもある。この2つが同じ場所に来ることが、
外側の用途から見て初めて分かる。

**時間切れが `should_fail` に優先することは既にそうなっている**（確認した）。
「異常な終わり方は期待された失敗ではない」という判断は一度下されており、
シグナルも同じ側に置くのが一貫する。

### なぜ内側から見つからないか

`should_fail` の検査は「非零で終了するプログラム」で足りる。**シグナルで
死ぬプログラム**を `should_fail` の事例として置く理由が、内側からは生じない。

### 検査

`projects/20-cases` の `a case killed by a signal does not satisfy should_fail`
と `and the report distinguishes a crash from a nonzero exit`。
どちらも修正され、通常の検査になっている。

対照として `a timeout wins over should_fail, so a hang is never an expected failure`
を通常の検査に置いてある。これがこの所見の論拠である。

---

## F-033

報告先: [sabas0ba/dowel#96](https://github.com/sabas0ba/dowel/issues/96)

**`timeout = 0` と負値が受理され、実行時には無視される。**

種別: 実装。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

```console
$ dowel check          # timeout = 0
check passed: 1 packages, 1 targets
$ dowel test
test c:suite/parse ... ok (1ms)          # 時間切れにならない
```

型が違えば拒まれる（`timeout = "10"` は `type-mismatch`）。値の範囲だけが
見られていない。

### 期待

0 以下を拒む。note に「省略すると待つ」を添える。`timeout = 0` を書く人の
意図は「制限を設けない」と「時間を与えない」に割れ、現状の挙動は偶然にも
前者と一致しているが、それは書かれていない。

`match` で組み立てると自然に混入する。

```toml
slow = { args = ["big"], timeout = match cfg.opt { debug => 60, release => 0 } }
```

### なぜ内側から見つからないか

時間切れの機構が働くことを見るには正の値を渡せば足りる。型が `Int` である
以上、型検査は通ってしまうので、値の範囲は誰も問わない。

### 検査

`projects/20-cases` の `a timeout of zero or less is refused`。
修正され、通常の検査になっている。対照として
`a case past its timeout is killed and reported as timed out` を置いてある。

---

## F-034

報告先: [sabas0ba/dowel#89](https://github.com/sabas0ba/dowel/issues/89)

**`--label` に誰も持たない名前を渡すと、報告はするが終了状態は 0 になる。
`docs/60-cli.md` の記述と食い違う。**

種別: 実装／文書。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

文書はこう書いている。

> Naming a label nobody carries **reports that, rather than passing with zero
> tests**

前半は実装されている。後半が実装されていない。

```console
$ dowel test --label nosuch
no test carries `nosuch`. labels are declared in `[test.<name>.cases]`

$ dowel test --label nosuch >/dev/null 2>/dev/null; echo $?
0
```

正常に1件通った場合と区別が付かない。報告は stderr に出るため、CI のログでは
埋もれる。`--label smoke` を `smok` と打ち間違えた段は、0 件走って緑になる。

### 期待

ラベルが誰にも一致しなかったとき、終了状態を非零にする。文書が既に
「zero tests で通すのではない」と述べている以上、それが期待値である。

[F-043](#f-043)（事例を走らせずに一覧できない）と組で効く。**利用者は正しい
ラベルを引き当てる手段を持たない。**

### なぜ内側から見つからないか

内側の検査が渡すラベルは、同じフィクスチャに書いてある正しい名前である。
外から見ると、これは打ち間違いではなく**時間の経過**で起きる。ラベルを改名
した、事例を消した、`--label` を書いた CI の設定だけが残った。

### 検査

`projects/20-cases` の `naming a label nobody carries does not pass with zero tests`。
修正され、通常の検査になっている。報告そのものは出るので
`and it does say which label found nothing` を通常の検査に置いてある。

---

## F-035

報告先: [sabas0ba/dowel#93](https://github.com/sabas0ba/dowel/issues/93)

**出力が印字する `<package>:<target>/<case>` を、そのまま渡し返せない。**

種別: 要望。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

```console
$ dowel test
test c:suite/rejects ... FAILED (1ms)

$ dowel test c:suite/rejects
error: no target named `c:suite/rejects`
```

`docs/60-cli.md` は「以降の選択肢はすべて**事例**に対して働く」と述べており、
`--label` も `--failed` も事例の単位で働く。位置引数だけが目標の単位である。

### 期待

位置引数が事例のラベルを受け付ける。目標の名前を渡したときは従来どおり
その目標の全事例が走る。

テストが落ちたとき最初にやることは「その1件だけ再実行」である。今できるのは
`--label`（あらかじめラベルを振っていた場合のみ）か `--failed`（落ちた全部）
だけで、どちらも噛み合わない。落ちた事例が重いとき（時間切れを起こす事例、
エミュレータ上の事例）、他を巻き込まずに1件だけ回したい要求はそのまま残る。

### なぜ内側から見つからないか

内側の検査は結果を**プログラムとして**読む。人間が出力を読んで、そこから
次のコマンドを組み立てる、という往復が現れない。

### 検査

`projects/20-cases` の
`the label a case is reported under selects that case on the command line`。
修正され、通常の検査になっている。対照として `naming the target runs all of its cases`
を置いてある。

---

## F-036

報告先: [sabas0ba/dowel#91](https://github.com/sabas0ba/dowel/issues/91)

**`--failed` は、覚えている事例がマニフェストから消えていると 0 件走って
状態 0 で終わる。**

種別: 実装。`e12bac7` で修正（`17bd54e` で観測）。[F-034](#f-034) と同じ家族である。

### 観測

```console
$ dowel test
test c:suite/hang ... FAILED (2007ms)
```

`hang` を改名する。

```console
$ dowel test --failed
running 0 tests
test result: ok. 0 passed; 0 failed         # rc=0
```

「前回落ちたものを直したので確認したい」と打った利用者は `ok` を見る。実際に
は確認していない。

### 期待

覚えている事例が現在の計画に無いとき、そのことを述べる。終了状態の扱いは
[F-034](#f-034) と揃えるのが自然である。

記録そのものは正しく働いている。ラベルで絞った実行のあとでも、走らせなかった
事例の判定は保持された（`60-cli.md` の "verdicts of targets not run are kept"
のとおり）。問題は**記録が現実と合わなくなったときに何も言わない**ことだけ。

### なぜ内側から見つからないか

内側の検査は「落ちる → 直す → `--failed` が走る」で足り、そこでは事例の名前
は変わらない。外では、落ちたテストを直すついでに事例を分割する・改名する・
`args` を変えるのはどれも普通の作業である。**「直す」という行為そのものが、
記録と現実を食い違わせる契機**になっている。

### 検査

`projects/20-cases` の `rerunning failures says so when the remembered case is gone`。
修正され、通常の検査になっている。対照として
`--failed reruns the case that failed, not its whole target` を置いてある。

---

## F-037

報告先: [sabas0ba/dowel#101](https://github.com/sabas0ba/dowel/issues/101)

**事例の型診断が、誤っている鍵ではなく事例全体に下線を引く。**

種別: 診断。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

```console
error[type-mismatch]: `timeout` is Int but Str was given
 --> dowel.build:9:1
  |
9 | parse   = { args = ["parse"], timeout = "10" }
  | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ this value has type Str
```

短い事例なら困らない。鍵が4つ5つ並ぶと、下線が行全体に引かれたまま
「`this value has type Str`」と言われる。

### 期待

範囲を、誤っている鍵とその値に絞る。`docs/12-build-reference.md` は診断の
性質として「Source locations (multiple labels) and notes」を挙げており、
`abi-mismatch` は実際に両側の来歴を別々に指している。

### なぜ内側から見つからないか

内側の検査は診断**コード**が出ることを見れば通る。位置の粒度は、鍵が1つか
2つの最小の入力では区別が付かない。読みにくくなるのは実際の事例の大きさで
あり、それは最小のフィクスチャには現れない。

### 検査

`projects/20-cases` の `a type error inside a case points at the key that is wrong`。
修正され、通常の検査になっている。診断そのものが出ることは
`a value of the wrong type in a case is refused` として置いてある。

---

## F-038

報告先: [sabas0ba/dowel#97](https://github.com/sabas0ba/dowel/issues/97)

**事例の名前が検証されない。`a/b`・空名・空白入りがラベルの文法を壊す。**

種別: 実装。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

```console
$ dowel test
test c:suite/a/b ... ok (1ms)
test c:suite/ ... ok (1ms)
test c:suite/x y ... ok (1ms)
```

| 名前 | ラベル | 何が壊れるか |
|---|---|---|
| `a/b` | `c:suite/a/b` | 目標がどこで終わるか読めない |
| `""` | `c:suite/` | 事例名が無い。目標の綴りと1文字しか違わない |
| `x y` | `c:suite/x y` | 空白で区切って読む消費者が壊れる |

重複した名前は正しく拒まれる。名前の**形**だけが見られていない。

### 期待

事例の名前を識別子として検証する。少なくとも `/` と空白と空名を拒む。
目標の名前は表見出しの文法が拒むので、事例だけが素通りしている形である。

### なぜ内側から見つからないか

内側のフィクスチャは普通の名前を付ける。外では、事例の名前は「何を試すか」の
説明になりがちで、`parse/nested`、`utf-8/bom` のような名前が自然に出る。
とくに `/` は分類の意図で使われる——ラベルの文法がそれを区切りに使っていると
知らなければ。

### 検査

`projects/20-cases` の `a case name that breaks the label grammar is refused`。
修正され、通常の検査になっている。対照として `two cases with the same name are refused`
を置いてある。

---

## F-039

報告先: [sabas0ba/dowel#98](https://github.com/sabas0ba/dowel/issues/98)

**`[test.x.cases.<名前>]` と書くと `too-deep-table` になり、事例がインライン
表であることに触れない。**

種別: 診断。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

```console
$ dowel check
error[too-deep-table]: `[test.suite.cases.parse]` is nested too deeply
   | ^^^^^^^^^^^^^^^^^^^^^^^^ expected `[kind.name]` or `[kind.name.block]`
```

対照的に `[bin.app.cases]` の診断はとても良い。

```console
error[unknown-block]: `cases` has no meaning on a `bin` target
   | ^^^^^^^^^^^^^^^ only `test` targets register cases
    = note: a case is another invocation of the same test binary; `dowel test` is what runs them
```

**片方だけがそうなっている**のがもったいない。

### 期待

診断が正しい書き方を述べる。`cases` という名前が見えている以上、そこまで
踏み込めるはずである。

この書き方をするのには理由がある。`cases` は複数の項目を持つ集まりであり、
TOML でそれを書く既定の形は項目ごとの表見出しである。しかも `dowel.build` は
既に3段を許しているので、4段目が許されないことは書いてみるまで分からない。
鍵が増えるほどインライン表は長くなり、表見出しに逃げたくなる圧力もある。

### なぜ内側から見つからないか

`too-deep-table` の検査は「深すぎる表が拒まれること」を見れば通り、拒んだ
あとに利用者が何をすればよいかは問われない。**診断が次の一手を示すか**は、
その診断を初めて見る人にしか判定できない。

### 検査

`projects/20-cases` の `writing a case as a table header says how to write it as an entry`。
修正され、通常の検査になっている。対照として
`a cases block on a bin target is refused` と `with what to do instead` を
置いてある。

---

## F-040

報告先: [sabas0ba/dowel#99](https://github.com/sabas0ba/dowel/issues/99)

**空の `[cases]` 表が黙って「素の実行ファイル1件」に落ちる。**

種別: 実装。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

```console
$ dowel check          # [test.empty.cases] を中身なしで書いた
check passed: 1 packages, 2 targets
$ dowel test
test c:empty ... ok (1ms)
```

実行ファイルが**引数なしで**1回走る。

### 期待

空の `cases` を拒む。あるいは0件として扱い、その目標は走らないと述べる。

「事例を書かない」と「事例を書いたが1つも残らなかった」は別の意図である。
後者は編集の途中、生成されたマニフェスト、そして [F-041](#f-041) が入った
場合の「条件が全部偽」として起きる。いずれでも利用者が期待するのは「この
目標は走らない」であり、実際に起きるのは意図しない起動が1件成功することで
ある。事例を宣言した木では、素の起動は普通なにもしないように書かれている。

### なぜ内側から見つからないか

`cases` を書くときは中身を書く。ADR が定めた「無い場合」の規則は検査される
はずだが、「空の場合」はその規則の対象ではないため、どちらの検査からも漏れる。

### 検査

`projects/20-cases` の `a cases block with no case in it is not silently one bare run`。
修正され、通常の検査になっている。対照として
`a target with no cases block is one test named after the target` を置いてある。

---

## F-041

報告先: [sabas0ba/dowel#92](https://github.com/sabas0ba/dowel/issues/92)

**事例そのものを条件付きにできない。ADR-0022 と reference の
「`match` / `when` apply」が誘う書き方が型エラーになる。**

種別: 要望／文書。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

中の値は通る。

```toml
parse = { args = ["parse"], timeout = match cfg.opt { debug => 30, release => 5 } }
```

事例そのものは通らない。

```console
$ # emit = { ... } when cfg.opt == "debug"
error[type-mismatch]: `emit` is an inline table but Cfg<Map<Ident, List<Str>>> was given

$ # parse = match cfg.opt { debug => { ... }, release => { ... } }
error[type-mismatch]: `parse` is an inline table but Cfg<?> was given
```

### 期待

事例を構成ごとに現れたり消えたりさせられるようにする。`sources` が既にその
形を持っている。

ADR は `timeout` を「実際に要る例」として挙げるが、その隣にもっと強い必要が
ある。**その対象では走らせられない事例**である。組み込み（実機でしか意味を
持たない事例）、GUI（表示が要る事例）、機能フラグ、クロス（エミュレータの下
では現実的な時間で終わらない事例——`timeout` を伸ばすのではなく落としたい）。

回避しようとすると `[test.<name>]` を分けることになり、**翻訳単位が増える**。
ADR-0022 が「事例は翻訳単位を増やさない」と述べた利点を捨てる形になる。

現状の挙動を保つとしても、文書の書き方は直したほうがよい。「Case values are
ordinary manifest values」は、事例そのものが値だと読める。

### なぜ内側から見つからないか

内側の検査は文書の例をなぞる。通る側は確かめられ、**効かない側**を書く理由が
生じない。外では、事例を条件付きにしたい理由は具体的な対象——実機、表示、
エミュレータ——から来る。

### 検査

`projects/20-cases` の `a case can be registered only for some configurations`。
`e12bac7` で修正された。通常の検査として
`a value inside a case can branch on the configuration` と
`the case exists in the configuration its condition names` と
`and is absent from the one it does not` を置いてある。

---

## F-042

報告先: [sabas0ba/dowel#90](https://github.com/sabas0ba/dowel/issues/90)

**`schema dump` が `cases` を記述せず、LSP のホバーが `cases` の中を何も
答えない。`12-build-reference.md` が宣言する不変条件が破れている。**

種別: 実装／文書。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

その頁の冒頭はこう述べている。

> The machine-readable form of everything on this page is `dowel schema dump`
> — the language server's hover and the type checker read the same tables, so
> **this page, the editor, and the diagnostics cannot disagree silently.**

同じ頁が `[test.<name>.cases]` を5行の鍵表つきで記述している。

```console
$ dowel schema dump | jq 'keys'
["artifact_properties","blocks","cfg","functions","inspection_properties",
 "pkg_constants","table_kinds","tools"]
```

`artifacts` には `artifact_properties`、`inspect` には `inspection_properties`
がある。**`case_properties` に相当するものが無い。** 兄弟のうち `cases` だけが
抜けている。

エディタ側でも答が割れる。

| 位置 | ホバー |
|---|---|
| `sources` | `**sources** — List<Path>` / merge: `append` … |
| `cases` / `args` / `timeout` / `should_fail` / `labels` | **（空）** |

一方、型検査器は語彙を持っている（`a case accepts: args, env, timeout,
should_fail, labels`）。**鍵表が実装の中に3か所ある**ことになる。文書、
型検査器、（無い）スキーマ。文書の主張はこれを1つに保つことだった。

### 期待

`schema dump` に `case_properties` を足す。`artifact_properties` /
`inspection_properties` と同じ形で足りるはずである。

併せて `[runner.<triple>]` の性質もダンプに無い。`table_kinds` に `runner` は
出るが、その鍵表は出ていない。

### なぜ内側から見つからないか

`schema dump` の内側の検査は、ダンプが自分自身と整合していることを見れば
通る。抜けているものは、抜けたまま整合する。「文書に書いてあるがダンプに
無い」を捕まえるには**文書とダンプを突き合わせる**必要があり、それは実装の
外側にある比較である。

### 検査

`projects/20-cases` の `the schema dump describes the properties a case accepts`。
`e12bac7` で修正された。`case_properties` に加えて `runner_properties` も
入り（#90 で併せて指摘した側）、
`and the runner's, which was the other block missing from it` と
`and the case keys it lists are exactly the ones the type checker accepts`
を通常の検査として置いてある。

---

## F-043

報告先: [sabas0ba/dowel#94](https://github.com/sabas0ba/dowel/issues/94)

**事例を走らせずに一覧する方法が無い。`--no-run` も `graph` も `schema dump`
も事例を出さない。**

種別: 要望。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

```console
$ dowel test --no-run
built: .../bin/suite

$ dowel graph --kind=target --format=json | jq '.targets'
[{"label": "c:suite", "kind": "test", "package": "c", "deps": []}]
```

`--message-format=json` は事例を1件ずつ出すが、**走らせた後**である。

### 期待

`--no-run` が、組んだうえで走るはずのものを並べる。選択（`--label` /
位置引数）が効いた後の一覧であることが重要である。

3つの用途がふさがっている。**ラベルの語彙を確かめる**（[F-034](#f-034) と
組み合わさると、綴りを間違えた利用者には確かめる術も気づく術も無い）、
時間のかかる事例を選ぶ前に見当をつける、外の道具から呼ぶ（一覧のために
全部走らせることになる。事例が時間切れを含むなら猶更）。

### なぜ内側から見つからないか

内側からは、どんな事例が宣言されているかはマニフェストを読めば分かる。
フィクスチャを書いた者が中身を知っているので、尋ねる必要が生じない。
外では、事例を宣言した人と `dowel test` を打つ人は別人である。

### 検査

`projects/20-cases` の `the cases that would run can be listed without running them`。
`e12bac7` で `--no-run` が一覧を出すようになった。
`with the properties that change how a case is judged` と
`and the listing honours the selection that was asked for` も通常の検査である。

---

## F-044

報告先: [sabas0ba/dowel#100](https://github.com/sabas0ba/dowel/issues/100)

**`test-result` の JSON が `target` に事例ラベルを入れ、事例の属性を1つも
出さない。**

種別: 実装。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

```json
{"kind":"test-result","target":"c:suite/parse","binary":"…","passed":true,
 "timed_out":false,"exit_status":0,"duration_ms":1,"stdout":"…","launch_error":null}
```

`target` という名前の欄に `<target>/<case>` が入る。下流が目標ごとに集計する
には最後の `/` で割るしかなく、その推測は安全でない（[F-038](#f-038)）。

`labels` / `should_fail` / `timeout` のどれも出ない。ラベルごとの集計が
できず、**期待された失敗と普通の成功が区別できない**。`exit_status: null` が
時間切れとシグナル（[F-032](#f-032)）の2つを意味することも効いている。

### 期待

事例を第一級の欄にする。`target` は目標のまま置き、`case` / `label` /
`labels` / `should_fail` / `signal` / `args` を足す。

### なぜ内側から見つからないか

内側の検査は、JSON が自分が生成した値を持っていることを見れば通る。**別の
道具がそれをどう使うか**は入力に現れない。本スイートは実際に結果を表へ積んで
おり、そこで具体的な要求が立つ。

### 検査

`projects/20-cases` の
`the machine-readable result names the target and the case separately` と
`and says whether the case was expected to fail`。
どちらも修正され、通常の検査になっている。対照として
`the machine-readable results go to stdout while the progress goes to stderr`
を置いてある（こちらは正しく分かれている）。

---

## F-045

報告先: [sabas0ba/dowel#95](https://github.com/sabas0ba/dowel/issues/95)

**事例の作業ディレクトリが文書化されておらず、指定する手立ても無い。**

種別: 文書／要望。`e12bac7` で修正（`17bd54e` で観測）。

### 観測

実測ではパッケージの根である。ADR-0022 にも reference の鍵表にも
`docs/60-cli.md` にも記述が無い。つまり**約束されていない**。実測に頼って
`fopen("tests/data/x.json")` と書いた木は、実装が変われば黙って壊れる。

そして `docs/60-cli.md` は、逐次実行が既定である理由をこう書いている。

> The default is sequential because C tests may use shared resources
> (**working directory**, fixed ports, output files)

**共有資源として認識されているのに、その値が規定されていない。**

### 期待

2つ、独立に。文書化すること。そして ctest の `WORKING_DIRECTORY` に相当する
鍵を足すこと（型は `Path` が素直で、`dir()` を受ける）。

要る場面は具体的である。相対パスで資料を読むテスト。出力ファイルを書く
テスト——同じ実行ファイルの複数の事例が同じ場所へ書くと `--test-jobs` で
衝突する。**事例ごとに別のディレクトリを与えられれば、`--test-jobs` の既定が
逐次である理由の一つが消える。**

### なぜ内側から見つからないか

内側のフィクスチャは、テストが読む資料を引数で渡すか埋め込むかで書ける。
**相対パスでファイルを開くテスト**を書く理由が生じない。外ではそう書く理由が
いくらでもあり、そのとき最初に尋ねるのが「どこから走るのか」である。

### 検査

`projects/20-cases` の `a case can be given the directory it runs in`。
修正され、通常の検査になっている。実測は
`a case runs in the root of the package that declares it` として固定してある
が、文書に無い以上これは**約束ではなく観測**である。

---

## F-046

報告先: [sabas0ba/dowel#107](https://github.com/sabas0ba/dowel/issues/107)

**スタブの起動コマンドは `command + args + debug_args + <成果物>` の順で
組まれる。`args` の末尾に成果物を取るフラグを置く runner——ADR-0008 が勧める
形——では、そのフラグが `debug_args` の先頭を食い、壊れたコマンドができる。**

種別: 実装。`9858932` で修正（`e12bac7` で観測）。`apps/blink` へデバッグを足そうとして踏んだ。

### 観測

`dowel test` で動いている組み込みの runner に、スタブの宣言を足す。

```toml
[runner.thumbv7em-none-eabihf]
command       = "qemu-system-arm"
args          = ["-M", "mps2-an386", "-nographic", "-semihosting", "-kernel"]
debug_args    = ["-gdb", "tcp::13579", "-S"]
debug_connect = "localhost:13579"
```

```console
$ dowel debug firmware --target=... --dap | jq -r '.debugServerArgs | join(" ")'
-M mps2-an386 -nographic -semihosting -kernel -gdb tcp::13579 -S /.../bin/firmware
```

`-kernel` の直後が `-gdb` である。qemu は `-gdb` という名前のファイルを
カーネルとして読もうとし、スタブは立たず、gdb は
`could not connect: Connection timed out` で終わる。

qemu-user（`-g` が位置に依存しない）ではたまたま通るため、qemu-system で
初めて現れる。`docs/30-devexp.md` 2.2 の「クロス実行では gdbstub を立てて
繋ぐ」という筋書きの、組み込み側の半分が宣言できない。

### 期待

挿し込む位置を `args` の前にする（`command + debug_args + args + <成果物>`）。
qemu-system は正しく動き、qemu-user も動き続ける。「成果物を取るフラグは
末尾」という既存の規約と衝突しない位置は先頭側しかない。あわせて挿し込み
位置を文書に明記する——現状どこにも書かれていない。

### なぜ内側から見つからないか

スタブの検査を qemu-user で書くと、どの挿し込み位置でも通る。位置が意味を
持つ runner は qemu-system で初めて現れ、それは実機の代わりのエミュレータを
相手にする木でしか書かれない。

### 修正

`debug_args` は `args` の**前**に挿し込まれるようになった。`args` は成果物を取るフラグで終わりうる（ADR-0008 が勧める形）ので、後ろには置けない——間に挟まったものはそのフラグの被演算子として食われる。`docs/12-build-reference.md` がその理由ごと書いている。

### 検査

`apps/blink` の
`the stub arguments do not break a runner that ends with the flag taking the artifact`、
および挿し込みの順序そのものを固定する
`because they are inserted before the runner's own arguments, not after them`。
qemu-user 側が動くことは `projects/21-debug` が見ている。


## F-047

報告先: [sabas0ba/dowel#108](https://github.com/sabas0ba/dowel/issues/108)

**マニフェストに書いた事例名は `invalid-name` で検証される（F-038 の修正）が、
ハーネスの列挙が返した名前は素通りし、同じラベルの文法を壊す。**

種別: 実装。`9858932` で修正（`e12bac7` で観測）。ADR-0023 を使ってみて踏んだ。

### 観測

`--list` が `a/b` や `be ta` を印字すると、そのまま登録される。

```console
$ dowel test h
test d:h/a/b ... FAILED (1ms)
test d:h/be ta ... FAILED (1ms)
```

`d:h/a/b` は目標がどこで終わるか読めず、位置引数での再実行（#93）が
曖昧さなしに受けられない。規則が片方の入口にしか無い。

### 期待

列挙が返した名前にも同じ検証を通し、違反は**その目標の失敗**として報告する。
列挙の失敗（非零・時間切れ・空）が既に目標の失敗として扱われているので、
その並びに入る。

ハーネスの列挙は既存の試験フレームワークの出力をそのまま流す場所であり、
名前に空白や `/` を含む枠組みは普通にある。マニフェストの名前は書き手が
選べるが、**列挙が返す名前は選べない**。

### なぜ内側から見つからないか

列挙の検査は行儀の良いハーネスで書かれる。壊れた名前を返すハーネスは、
既存のフレームワークの出力形式を思い浮かべて初めて「普通に来る入力」だと
分かる。

### 修正

列挙が返した名前も、マニフェスト側の `invalid-name` と同じ規則で検証されるようになった。診断はどの名前が悪いのか、どの文法を壊すのかを言い、直す先——列挙する側の印字——を指す。規則が両方の入口に揃った。

### 検査

`projects/20-cases` の
`a discovered name that breaks the label grammar is not silently accepted`、
`naming the offending name and the grammar it would break`、
`and pointing at the harness, which is where such a name has to be fixed`。

最初の1つは、以前は「ラベルが出力に現れないこと」で見ていた。直った診断は
**壊れるはずだったラベルを説明の中で引用する**ので、その見方では偽の失敗に
なる。終了状態で見る形へ書き換えた。


## F-048

報告先: [sabas0ba/dowel#109](https://github.com/sabas0ba/dowel/issues/109)

**`debug_args` と `debug_connect` の片方だけを書いた場合の診断が、何も
書かなかった場合と同じ「declares no stub」になる。**

種別: 診断。`9858932` で修正（`e12bac7` で観測）。#74（宣言してあるのに missing-runner）と
同族の、規模の小さい版である。

### 観測

```console
$ dowel debug app --target=...      # debug_args は書いた
error[missing-debug-stub]: no debug stub is declared for `...`
   | ^^^^ this runner declares no stub
```

半分は宣言してある。利用者は自分の `debug_args` を見て、書いてあることを
確かめることになる。

### 期待

書いてある側を認め、欠けている側の鍵を指す。

### なぜ内側から見つからないか

「両方無い」と「片方だけ」は同じ経路に落ちるため、内側の検査は前者で足りる。
文言が実態と合っているかは、片方だけ書いた利用者の視点でしか問われない。

### 修正

欠けている側を名指しするようになった。`the debug stub for <triple> has no attach address` と言い、在る側（`debug_args`）を指し、足すべき鍵（`debug_connect`）を名指しする。

### 検査

`projects/21-debug` の
`a half-declared stub is told which half is missing`、
`naming the missing half rather than reporting the pair as absent`、
`pointing at the half that is there, and naming the key that completes it`。
両方無い場合の `missing-debug-stub` は別に置いてある。


## F-049

報告先: [sabas0ba/dowel#110](https://github.com/sabas0ba/dowel/issues/110)

**落ちていない事例をデバッガの下で開けない。`dowel debug` は事例ラベルを
受けず、`--debug-failed` は失敗の記録を経由する道しか無い。**

種別: 要望。`9858932` で修正（`e12bac7` で観測）。

### 観測

```console
$ dowel debug d:suite/plain
error: no target named `d:suite/plain`
```

`dowel test` の位置引数は事例ラベルを受ける（#93）。`dowel debug` は目標だけ。

### 期待

`dowel debug` の位置引数が事例ラベルも受け、事例の宣言（args / env / cwd、
ハーネスなら `run` + 名前）を Launch に写す。写す機構は `--debug-failed` に
既にあり、選択の入口を1つ足すだけに見える。

デバッガを開きたいのは失敗のときだけではない。通っているが遅い事例、
これから書く事例の初回実行、別の構成で落ちた事例。回避策は「わざと落として
記録を作る」で、道具に嘘をつく形である。

### なぜ内側から見つからないか

`--debug-failed` の検査は「落ちる → 開く」の流れで書かれ、その流れの中では
記録が常に在る。記録が無い状態で開きたいのは日常の開発の側から来る要求である。

### 修正

`dowel debug <target>[/<case>]` が事例ラベルを受けるようになった。開いた先には事例の宣言（args / env / cwd）が写る。存在しない事例は、素の目標へ黙って落ちずに断られる。

### 検査

`projects/21-debug` の
`a case that has not failed can be opened under the debugger`、
`carrying that case's own arguments, not a bare run of the binary`、
`while a case that does not exist is refused rather than opened as the bare target`。

最初の1つは本物の gdb が起きるので、命令を流して閉じている。流さないと
待ち続ける——デバッグの起動は対話であり、そこが `--dap` との違いである。


## F-050

報告先: [sabas0ba/dowel#112](https://github.com/sabas0ba/dowel/issues/112)

**Windows 対象は組めるが、dowel が名指しする成果物が存在しない。ドライバは
`bin/<名前>.exe` を書き、dowel は `bin/<名前>` として扱う。**

種別: 実装。`9858932` で修正（`e12bac7` で観測）。

### 観測

```console
$ dowel build --target=x86_64-pc-windows-gnu
built: .../x86_64-pc-windows-gnu-debug/bin/wt

$ ls .../x86_64-pc-windows-gnu-debug/bin/
wt.exe
```

ずれは4か所に出る。

| 面 | 現れ方 |
|---|---|
| 印字 | `built:` が実在しない道を出す |
| 実行 | runner に `.exe` の無い道が渡り、wine が `c0000135` を返す |
| 派生 | `artifacts` の `objcopy` に存在しない入力が渡り、ビルドが落ちる |
| **増分** | **宣言した出力が永久に無いので、リンクが毎回やり直される** |

最後の1つは報告後に見つけて追記した。何も触らずに繰り返し組むと、
`ran 2 steps` が何度でも出る。同じ木を手元へ組めば `ran 0 steps` に収束する。

```console
$ for i in 1 2 3; do dowel build --target=x86_64-pc-windows-gnu --backend=direct --log-level=debug; done
run 1: ran 2 steps, skipped 5 already up to date
run 2: ran 2 steps, skipped 5 already up to date
run 3: ran 2 steps, skipped 5 already up to date
```

成功として終わる（終了状態 0、`built:` も出る）ので、手がかりは所要時間しか
無い。リンクが重い木——大きい依存、LTO、静的リンク——で初めて体感に出る。

### 期待

対象の三つ組が実行ファイルの綴りを決める、という規則を1か所に置く。
`*-windows-*` では `bin/<名前>.exe`。runner・`artifacts`・`inspect`・`debug`・
`built:` の印字・指紋の照合が、すべて同じ値を読む形になる。

`docs/12-build-reference.md` の種別の表は `bin` の成果物を `bin/<名前>` と
書いており、Windows ではこれが成り立たない。

### なぜ内側から見つからないか

本体のフィクスチャが組む対象は、ホストとベアメタルだと思われる。どちらも
実行ファイルに拡張子が付かない。**拡張子が付く対象**を入力にして初めて、
名指しする道と書かれたファイルがずれる。

ずれは組む段では現れない。ninja はリンクの成功を終了状態で判断し、出力
ファイルの実在を確かめないためである。次の段で初めて出る。増分の面だけは
組む段に出るが、そちらは「成功して速い」ように見える。

### 修正

成果物の綴りが `target.os` に従うようになった。`built:` の印字・runner へ渡す道・`artifacts` の入力・指紋の照合が、すべて同じ値を読む。増分が収束しなかった4つ目の面も同時に消えた——宣言された出力が実在するようになったためである。

### 検査

`apps/winapp` の
`the artifact dowel names is the file that was written`、
`and the suffix follows the target, so the host build keeps none`、
`and a Windows target can be tested through its runner`、
`with each declared case launched in its own right`、
`a second Windows build runs nothing`。

最後のものが増分の面である。対照として、同じ木の手元向けビルドが 0 件に
収束することも置いてあり、差が対象だけであることが読める。


## F-051

報告先: [sabas0ba/dowel#113](https://github.com/sabas0ba/dowel/issues/113)

**MSVC は名指しできるが宣言できない。`[toolchain.<triple>] c = "cl"` は
受理され、計画も立つが、出てくる引数は GNU の形である。**

種別: 実装。`9858932` で修正（`e12bac7` で観測）。

### 観測

`cl` と `lib` を PATH に置いて計画を読む。

```console
$ dowel graph --kind=action --target=x86_64-pc-windows-msvc --format=json
cl   -g -O0 -MD -MF …/src_main.c.o.d -c …/src/main.c -o …/src_main.c.o
lib  rcs …/lib/libapp.a …/src_main.c.o
cl   …/src_main.c.o …/lib/libapp.a -o …/bin/app
```

すべての綴りが GNU である。`-c` `-o` `-g` `-O0` は `cl` の綴りではなく、
`-MD` に至っては MSVC では**動的 CRT の指定**であり、意味が衝突する
（`docs/00-overview.md` 自身が CRT を ABI の軸として挙げている）。書庫の
綴り `lib<名前>.a` も MSVC では `<名前>.lib` である。ツール表に `link` が
無いため、リンクを別の実行ファイルに割り当てることもできない。

### 期待

族（GNU 風 / MSVC 風）が引数の組み立てを選ぶ形。ツールの名前だけでなく、
その名前が**どの綴りで話すか**を宣言できること。あわせて成果物の綴り
（`lib<名前>.a` / `<名前>.lib`、`<名前>` / `<名前>.exe`）も族から決まる形。

短期には、対応していない族を名指ししたときに `unsupported-toolchain` の
ような診断で拒む方が、GNU の引数を `cl` に渡して下流で落ちるより良い。

### なぜ内側から見つからないか

引数の組み立ては、本体から見ると1つしかない。「族が2つある」という前提が
入っていないので、それが破れる入力を作る動機が無い。`cl` を PATH に置いて
計画だけ読むという形は、**MSVC を実際に使おうとした側**からしか出てこない。

### 修正

引数の様式を `style`（`gnu` / `msvc`）として宣言できるようになった（ADR-0027）。三つ組からも導かれる（`*-msvc` → msvc）。**dowel が組み立てる引数だけ**が様式ごとに綴られ、利用者の書いた `flags` はそのまま渡る。`-MD` の衝突は `/showIncludes` を出すことで解かれ、`link` が道具の表に入り、成果物の綴り（`.obj` / `<name>.lib` / `.exe`）も様式に従う。

### 検査

`apps/winapp` の
`an MSVC toolchain can be declared, not just named`、
`without asking for a dependency record in a spelling that means the dynamic CRT there`、
`using the spelling that does mean it under this style`、
`and the link runs through a separate program, as that toolchain has it`、
`with the object and output spellings that toolchain writes`。

本物の MSVC は要らない。偽の `cl` / `lib` / `link` を PATH に置いて、組まずに
計画だけを読む。確かめたいのは「MSVC が使えるか」ではなく**引数の形が族に
合っているか**であり、それは計画から読める。対照として、GNU の族へ向けたとき
同じ引数が GNU の綴りであることも置いてある。


## F-052

報告先: [sabas0ba/dowel#114](https://github.com/sabas0ba/dowel/issues/114)

**1つのパッケージに同名のターゲットを2つ書ける。`check` は通り、`public` は
どこへも伝播せず、同じソースを持つとオブジェクトの経路が衝突して ninja が
落ちる。**

種別: 実装。`9858932` で修正（`e12bac7` で観測）。

### 観測

```toml
[lib.foo]
sources = [file("src/lib.c")]

[lib.foo.public]
includes = [dir("include")]

[bin.foo]
sources = [file("src/main.c")]

[bin.foo.private]
deps = [target("foo")]
```

```console
$ dowel check
check passed: 1 packages, 2 targets
```

現れ方は4つ。

1. **グラフのラベルが同じ。** 4つの手順がすべて `pkg:foo` になり、どの `cc`
   が書庫のためのものかをラベルから決められない。`--failed` や
   `--message-format=json` を読む側は、この名前を鍵にしている
2. **`public` が伝播しない。** 依存する `bin.foo` にも、`lib.foo` 自身の
   ソースにも `-I include` が届かず、翻訳が落ちる。名前を割るだけで通る
3. **オブジェクトの経路が衝突する。** 経路は `obj/<パッケージ>/<名前>/` で
   あり種別が入らない。同じソースを両方が持つと、同じ経路を2つの規則が作る
4. **助言が同じ綴りを2つ挙げる。**
   `` error: `foo` exists in several packages: pkg:foo, pkg:foo ``
   パッケージは1つであり、言われたとおり書いても区別できない

3 の落ち方が悪い。

```console
$ dowel build
ninja: error: …/build.ninja:39: multiple rules generate …/obj/pkg/foo/src_shared.c.o
```

`docs/00-overview.md` 1節が「既存システムの失敗様式」として挙げている形で
ある。マニフェストの誤りが、下流の道具の語彙で、利用者が書いていない行番号を
指して出る。`dowel check` は通っているので、commit 前に洗い出す用途も
満たさない。

### 期待

1つのパッケージの中でターゲット名は一意である、として2つ目の宣言を
`duplicate-target` で拒む。成果物の綴り（`libfoo.a` と `foo`）が衝突しない
以上、同居させたい書き手はいる。それでも `target()` とラベルと `obj/` の
3か所すべてを種別で修飾するのは、得られるものに対して面が広い。名前が
一意であることは `dowel build <名前>` の文法が前提にしているものでもある。

### なぜ内側から見つからないか

ターゲットの検査は種別ごとに1つずつ書くのが自然である。`lib` の伝播を見る
フィクスチャ、`bin` のリンクを見るフィクスチャ、という具合に。**同じ
パッケージに同じ名前で2つ**という組み合わせは、どちらの検査からも要らない。

そしてこれは「壊れた入力」に見えない。`unknown-property` のように明らかに
誤った綴りではなく、**両方とも単独では正しい宣言**である。

### 報告の訂正

最初の報告では「ソースを共有すると `ar` が計画から消え、`build` が 0 を
返す」と書いた。**これは誤りだった。** 依存の辺を書いていなかったためで、
辺が無ければ名前が同じでも違っても同じ結果になる（到達されない `lib` が
組まれないだけで、`docs/60-cli.md` のとおりである）。対照を取らずに報告して
しまった。#114 に訂正を出し、正しい症状（3）に置き換えてある。

対照を並べる前に報告した点が、こちら側の反省である。検査を書く段で対照が
必要になり、そこで初めて気づいた。**検査を書く前に報告しない**方が良い。

### 修正

同名の目標が `duplicate-target` で拒まれるようになった（期待の 1 の側）。診断は両方の宣言を指し、どちらが先かを言い、**なぜ一意でなければならないか**——名前が `target()`・ラベル・`obj/` の3か所で鍵として使われていること——を述べ、別の綴りを助言する。

### 検査

`projects/04-diagnostics` の `cases/duplicate-target`。診断コードの一覧に
入れてあるので、報告されること・非零で終わること・位置を指すことはそちらで
見ている。名前の衝突に固有のものとして、次を置いた。

- `duplicate-target carries the location of both declarations`
- `naming which of the two came first, so the later one is the one to rename`
- `and why the name has to be unique, naming the object directory that keys on it`
- `and the suggestion offers a spelling that differs from both`

最後の1つは、かつて目標を名指ししたときの助言が同じ綴りを2つ挙げていた
（`pkg:foo` を2度）ことへの対である。対照として、名前を割れば同じ木が通り `public`
が届くことも置いてある。

ソースを共有する形のフィクスチャ（`duplicate-target-shared`）は消した。
名前の段で拒まれる以上、オブジェクトの経路が衝突するところまで進まない。


## F-053

報告先: [sabas0ba/dowel#115](https://github.com/sabas0ba/dowel/issues/115)

**対象の OS を指す語が無い。条件つきソースは三つ組を数え上げるしかなく、
`match host.os` は組む側を指すため書き手の意図と逆に効く。**

種別: 要望（`docs/99-open-questions.md` Q1 への材料）。`9858932` で修正（`e12bac7` で観測）。

### 観測

語彙にあるのは `host.os` / `host.arch`（組む側）と `cfg.target`（三つ組その
もの）だけである。対象の OS を指す語は無い。

素直に書くとこうなる。

```toml
match host.os {
    windows => file("src/plat_win.c"),
    _       => file("src/plat_posix.c"),
}
```

Linux から Windows 向けに組む。

```console
$ dowel graph --target=x86_64-pc-windows-gnu --format=json | jq '…plat…'
…/src/plat_posix.c
```

`--target` に windows と書き、`match` にも `windows` と書いてあるのに、
POSIX の実装が選ばれる。`plat_posix.c` が `<unistd.h>` を含んでいれば翻訳で
落ちるが、含んでいなければ**組み上がって答だけが違う**。

正しい綴りは三つ組の数え上げになる。

```toml
match cfg.target {
    "x86_64-pc-windows-gnu"  => file("src/plat_win.c"),
    "x86_64-pc-windows-msvc" => file("src/plat_win.c"),
    _                        => file("src/plat_posix.c"),
}
```

Windows の三つ組は複数あり、「Windows のどれか」と言う手段が無い。`_` が
既定なので、**書き忘れた三つ組は静かに POSIX 側へ落ちる**。`cfg.target` は
開いた領域なので網羅性の検査も掛からない。

### 期待

Q1 で `target.os` / `target.arch` を語彙に入れる。`host.*` は残す——組む側を
見たい場面は実在する。

`target.os` は `host.os` と同じ有限領域にできるので、`match` の網羅性検査が
効く。`_` を書かずに済み、対象が増えたときに**マニフェストが落ちて教えて
くれる**。三つ組を数え上げる形の一番の弱点がここである。三つ組から導ける
値なので、新しい入力は要らない。

### なぜ内側から見つからないか

`projects/11-cross` も `apps/blink` も、対象は1つずつだった。**対象ごとに
実装が分かれる**形で初めて出る。語彙が足りないことは、足りない語を使いたく
なる木を書くまで現れない。

### 修正

`target.os` / `target.arch` が語彙に入った。`host.*` は組む側を指したまま残っている。`target.os` は有限領域（`linux` / `macos` / `windows` / `none` / `other`）なので `match` の網羅性が検査され、三つ組を数え上げる形の一番の弱点——書き忘れが静かに `_` の腕へ落ちること——が消えた。

### 検査

`apps/winapp` の
`a manifest can select sources by the target's operating system`、
`and that key has a finite domain, so a match on it is checked for exhaustiveness`、
`which is how this application actually spells the choice`、
`and it selects the Windows implementation when the target is Windows`、
`while host.os still means the build machine, so the pair is complete`。

マニフェスト側も、`cfg.target` を数え上げる形から `target.os` で分岐する形へ
書き換えてある。`apps/dsp` も同様で、そちらは腕が「OS が無い側かどうか」に
なった。


## F-054

報告先: [sabas0ba/dowel#125](https://github.com/sabas0ba/dowel/issues/125)

**依存パッケージが宣言した `[toolchain.<triple>]` は使う側の build に効かない。
dowel はその宣言を読み上げたうえで「宣言が無い」と言って止まる。**

種別: 診断／要望。`9858932` で修正（`e12bac7` で観測）。

### 観測

```
lib/dowel.toml      [toolchain.aarch64-unknown-linux-gnu] を宣言する
app/dowel.toml      lib に依存する。道具立ては書かない
```

```console
$ dowel -C app build --target=aarch64-unknown-linux-gnu
error[missing-toolchain]: no toolchain is declared for target `aarch64-unknown-linux-gnu`
  = note: declare one, for example `[toolchain.aarch64-unknown-linux-gnu]` with `c = "..."` in dowel.toml
warning[toolchain-mismatch]: package `mylib` asks for `c = "aarch64-linux-gnu-gcc"` but the build uses `cc`
warning[toolchain-mismatch]: package `mylib` asks for `ar = "aarch64-linux-gnu-ar"` but the build uses `ar`
1 errors, 2 warnings
```

同じ出力の中で、dowel は「宣言が無い」と言って止まり、その2行下で
「`c = "aarch64-linux-gnu-gcc"` と書いてある」と読み上げている。
**探しているものを見つけていて、それでも無いと言う。** 助言が挙げる例は、
2行下で読み上げている値そのものである。

`docs/11-toml-reference.md` は「依存の道具立てが違えば `toolchain-mismatch`
で警告する」と述べているので、**警告が出ること自体は文書どおり**である。
所見にしたのは、そこから出てくる書き味の方である。

### なぜ問題か

複数の三つ組を支えるライブラリを書くと、**支える三つ組の数 × 使う側の数**
だけ表の写しができる。`apps/dsp` では `core` が4つの三つ組の表を持って
いても、`cli` は2つ、`fw` は1つを自分で書き直している。

- **食い違っても止まらない。** 片方を `aarch64-linux-gnu-gcc-12` に変えて
  他方を直し忘れると、`toolchain-mismatch` は出るが警告であり、組み上がる
- **ライブラリの作者が「対応する三つ組」を配れない。** どのコンパイラで
  組むかはライブラリの知識だが、置き場所は使う側にしかない
- 三つ組を1つ増やす作業が、1行ではなく**使う側の数だけ**になる

### 期待

1. **少なくとも、診断が読んだものを言う。** 設計を変えずに済む。

   ```
   error[missing-toolchain]: no toolchain is declared for target `…`
     = note: dependency `mylib` declares one for this triple (c = "aarch64-linux-gnu-gcc").
             a dependency's toolchain does not apply to the build; declare it here to use it.
   ```

2. できれば、根が宣言していないときに依存の宣言を採る。「single pinned
   toolchain per build」は保てる——採るのは1つだけで、複数の依存が食い違う
   値を出したら拒めばよい。

2 に踏み込まない判断もある。道具立ては build 全体の性質であって依存の性質
ではない、という立場は一貫している（Cargo でも toolchain はパッケージでは
なく環境の側にある）。その場合でも 1 は要る。**いまの出力はその立場を
説明していない。**

### なぜ内側から見つからないか

クロスを見るフィクスチャは、1つのパッケージに `[toolchain.<triple>]` を
書いて `--target` を渡すのが最短であり、それで挙動は十分見える。写しの
費用は、パッケージが分かれていて**かつ複数の三つ組がある**ときにしか出ない。

`toolchain-mismatch` の検査も、おそらく食い違いを警告することを見るもので、
そのとき根は必ず宣言を持っている。**根が持っていない**場合が、警告と
error が同時に出る唯一の形である。

### 修正

期待の 1 の側で決着した。診断が依存の宣言を読み上げ、値まで出し、**なぜ効かないか**を言う（`it is a property of the build, not of the package`、ADR-0031）。効かないこと自体は設計として残り、それが説明されるようになった。

### 検査

`apps/dsp` の5節。

- `the error for a missing toolchain mentions the declaration a dependency already carries`
- `quoting the value, so the line to write is in front of the reader`
- `and why it does not apply, which is what makes the refusal read as a design`

診断そのもの（error の行と続く `= note:`）だけを取り出して見ている——直後の
`toolchain-mismatch` にも依存の名前があるので、そこまで含めると「言及して
いる」と誤って読める。利用者が最初に読む塊が答を指しているかが問題である。

依存の宣言だけでは組めないこと自体は、設計として通常の検査に残してある。


## F-055

報告先: [sabas0ba/dowel#126](https://github.com/sabas0ba/dowel/issues/126)

**目標を三つ組で絞れないため、複数の三つ組を支えるライブラリが自分の検査を
持てない。使う側の `build` が依存の `test` を組み、組めない三つ組では落ちる。**

種別: 要望。`9858932` で修正（`e12bac7` で観測）。

### 観測

```console
$ dowel -C app build --target=aarch64-unknown-linux-gnu
built: …/bin/app
built: …/bin/libcheck        ← 依存の検査

$ dowel -C app build app --target=aarch64-unknown-linux-gnu
built: …/bin/app             ← 名指しすれば組まれない
```

ホスト付きの三つ組では余計なだけだが、**OS の無い三つ組では落ちる**。

```console
$ dowel -C fw test --target=thumbv7em-none-eabihf
… ld: libc.a(libc_a-lseekr.o): undefined reference to `_lseek'
ninja: build stopped: subcommand failed.

$ dowel -C fw test onhw --target=thumbv7em-none-eabihf
test dsp-fw:onhw ... ok (5009ms)
```

`fw` は `-nostdlib` で正しく組まれている。落ちているのは**依存側の
`test.vectors`** で、こちらはホスト用に書かれており `-nostdlib` を持たない。

`docs/60-cli.md` は「With no targets named, builds every `bin` and `test`」と
述べ、パッケージの範囲に触れていないので**挙動は文書どおり**である。

### 根にあるもの

ライブラリの側で「この検査はホストの載っている三つ組でだけ」と書けない。

- `[package] targets` はパッケージ全体に掛かる。`core` は4つすべてへ組む
  必要があるので使えない
- 目標ごとの `targets` は無い
- `sources` を `match cfg.target` で振り替えることはできるが、**空にする
  書き方が無い**

残るのはパッケージを割ることだけである。検査がライブラリと同じパッケージに
居られないのは、置き場所として不自然である。

### 期待

1. **使う側の `build` / `test` は依存の `test` を組まない。** `cargo build`
   が依存のテストを組まないのと同じ立場。いまも名指しすれば避けられるので、
   既定がどちらかという話である
2. **目標ごとに三つ組を絞れる。** `[package] targets` と同じ綴りを目標にも
   許す形。語彙は増えない

1 を推す。小さく、既定の変更だけで済む。ただし 1 だけでは、ライブラリ自身の
ディレクトリで `dowel build --target=thumbv7em-none-eabihf` と打った場合は
落ちたままであり、そこは 2 が要る。

### なぜ内側から見つからないか

依存を持つフィクスチャは「使う側が依存の成果物を引けること」を見る。その
とき**依存の側に `test` を置く理由が無い**。逆にライブラリの検査を見る
フィクスチャは単独のパッケージになる。**依存されているライブラリが自分の
検査を持っている**という組み合わせが、どちらの側からも要らない。

そして三つ組が1つなら、これは余計なものが組まれるだけで無害である。
**組めない三つ組が混じって初めて**落ちる。

### 修正

期待の両方が入った。使う側の `build` / `test` は依存の `test` を組まなくなり、目標ごとに `targets` で三つ組を絞れるようになった。圏外の三つ組では計画に**現れず**、それでも名指しは `unsupported-target` で断られる——名指しは要求であり、黙って何も作らない build は成功に読めるためである。

### 検査

`apps/dsp` の6節。`targets` を実際に使う形へ書き換えてある。

- `a consumer builds for a triple its dependency's tests cannot be built for`
- `a consumer never builds the dependency's own tests, on a hosted triple either`
- `a target outside its triples does not appear in that triple's plan`
- `while naming it there is refused, because a build that quietly produces nothing reads as success`
- `and on a triple it does declare, the same target builds and runs`

`core` の `test.vectors` は `targets` でホストの載っている3つに絞ってあり、
`fw` は目標を名指しせずに検査を打てる。書き換える前は `onhw` と名指しして
避けていた。

なお `projects/05-incremental` の計数もこの修正で変わった（依存の検査が
含まれなくなり 9 件から 5 件へ）。公開ヘッダが検査まで波及することは、それが
組まれる側——ライブラリ自身のパッケージ——へ移してある。`apps/jsonfmt` も
同様で、検査はパッケージごとに走る形へ書き換えた。


## F-056

報告先: [sabas0ba/dowel#134](https://github.com/sabas0ba/dowel/issues/134)

**ライブラリを共有にすると、そのライブラリ自身の検査が組めなくなる。
内部の名前が `exports` に無いためで、実装と繋ぐ手立てが無い。**

種別: 要望。`c154097` で修正（`9858932` で観測）。ADR-0030 の共有ライブラリを `apps/hashx`
（配ることを前提にしたライブラリ）で使ってみて踏んだ。

### 観測

```console
$ dowel test
test wb:unit ... ok (1ms)

$ dowel test --features=shared
… ld: tests/unit.c:3: undefined reference to `core_step'
error: ninja failed
```

`tests/unit.c` は公開の面と内部の名前の両方を呼ぶ。共有にすると後者が
届かなくなる——共有ライブラリとしては正しい振る舞いである。

### なぜ問題か

内側を見る検査は、ライブラリの検査として普通の形である。`apps/hashx` の
ものは実際に `hx_crc_step` を直に呼んでおり、公開の面だけを叩く検査では
面の後ろにある表の構築を覆えない。

利用者に残る道は3つで、どれも良くない。

| 道 | 何が悪いか |
|---|---|
| 内部の名前を `exports` に足す | 面が壊れる。隠すために書いた宣言に、隠したくないものを書く |
| 検査にライブラリのソースを直に並べる | 一覧が2か所になる。足し忘れると古い実装を測り続ける |
| 共有では検査を諦める | いちばん検査したい構成で走らない |

CMake の `OBJECT` ライブラリ、Meson の `objects:`、Cargo の同一クレート内
`#[cfg(test)]` が、他の道具でこの役を果たしている。

### 期待

**同じパッケージの目標は、共有の面ではなく実装に繋ぐ。** `target("core")`
がパッケージ内から参照されたときは `.so` ではなくオブジェクトを渡し、
外（`dep("core")`）は今までどおり `.so` を見る。「パッケージの中は同じ作者」
という前提は `private` が既に置いている。

目標の側で `link = "objects"` と言える形も考えられるが、利用者が何も書かずに
静的と共有で同じ検査が走る前者を推す。既に静的で書かれている木が、
`linkage` を1行足しただけで壊れないことにも意味がある。

いずれにせよ `docs/12-build-reference.md` の共有ライブラリの節に一言要る。
いまの記述は面の決め方を丁寧に述べているが、**自分の検査がその面の外に出る
こと**には触れていない。

### なぜ内側から見つからないか

共有ライブラリのフィクスチャは「`.so` が出る」「`exports` が効く」「使う側が
走る」を見れば足りる。そのとき置く使う側は、面の検査なのだから**公開の面
だけを呼ぶ**のが自然である。

内側を見る検査は**ライブラリを配る側の木**にしか現れず、その木は普通、
静的で書き始める。`linkage` を足す日まで、2つは出会わない。

### 修正

パッケージの中では共有ライブラリも静的に繋がれるようになった（ADR-0038、期待の側）。`exports` は「一緒に書かれなかったコードへの境界」であり、パッケージが配布の単位である以上、同じパッケージの兄弟は書庫の側を見る。外向きの境界は変わらない——別のパッケージの使う側は `exports` だけを見る。

あわせて、`exports` に挙げた名前が実在するかを、リンクの後に `nm` で確かめるようになった（ADR-0039、`unexported-symbol`）。`apps/hashx` で `hashx_crc`（型名であって記号ではない）を挙げても黙っていた件が、これで拒まれる。

### 検査

`apps/hashx` の
`the library's own tests still link when it is built shared`、
`and what they reach is an internal name, not something on the public surface`、
`which still sees only what exports lists, because the boundary faces outward`。

境界が**外向き**であることを、内と外の両方から見ている。片方だけでは
「面が消えた」のか「面の向きが決まった」のかを区別できない。

`exports` の実在確認は
`a name in exports that the library does not define is refused` ほか2件。
ABI の世代（`soversion`）は
`a shared library may declare its ABI generation` ほか3件で、宣言しなければ
版が付かないことも対にしてある——面が変わったかどうかを決めるのは道具では
なく作者である。


## F-057

報告先: [sabas0ba/dowel#135](https://github.com/sabas0ba/dowel/issues/135)

**Meson からの移行が、書庫とリンクの引数を翻訳の `flags` に混ぜるため、
下書きがそのままでは組めない。**

種別: 実装。`c154097` で修正（`9858932` で観測）。

### 観測

静的ライブラリと、それを使う実行ファイルという素朴な木を取り込む。

```toml
[lib.shapes.private]
flags = ["-fdiagnostics-color=always", "-Wall", "-Winvalid-pch", "-std=c11", "-fPIC", "csrDT"]

[bin.shapetool.private]
flags = ["…", "-Wl,--as-needed", "-Wl,--no-undefined", "-Wl,--start-group", "libshapes.a", "-Wl,--end-group"]
```

`flags` は**翻訳の**引数である。そこに `ar` の引数文字列（`csrDT`）、書庫の
名前（`libshapes.a`）、リンカへの引数（`-Wl,…`）が入っている。

```console
$ dowel build
cc: error: libshapes.a: linker input file not found: No such file or directory
```

同じ木を CMake から取り込むと、そのまま組める。File API が引数を仕分け済みで
渡し、木の中の依存を名指しするためである。

### なぜ問題か

`docs/60-cli.md` は「the rest → `flags`」と述べているが、その配列には
リンクと書庫の引数も入っている。移行は片道であり、下書きが組めなければ
利用者はまず**移行そのものを疑う**。実際には仕分けの問題であり、
`meson.build` にも木にも誤りは無い。

`csrDT` の由来は Meson の introspection を知らないと分からない。旗の形を
していないので検索もしにくい。

`dowel migrate verify` は差分として捉える。安全網は働いているが、`verify` は
「写した結果が元と同じ翻訳になるか」の答合わせであって、下書きが組めない
状態の説明ではない。

### 期待

`parameters` を仕分けるとき、翻訳の引数でないものを `flags` に入れない。
`-Wl,` は綴りで判別でき、書庫の名前とオブジェクトは落とせる（Meson から
`deps` を起こさない既存の判断は変わらない）。

そこまで踏み込まないなら、下書きの見出しに一言——Meson の `parameters` には
リンクの引数が混ざるため `flags` を確認せよ——があれば、利用者は自分の木を
疑わずに済む。

### なぜ内側から見つからないか

Meson 対応のフィクスチャは、取り込みたい要素を持つ最小の木になる。
`static_library` + `executable` + `link_with` という**普通の2目標の木**に
して初めて、`ar` の引数とリンクの引数が配列に現れる。そして「出た下書きを
実際に組んでみる」ところまで行かないと目に入らない——下書きは読むもので
あって、組むものだとは限らない。

### 修正

`parameters` の仕分けが行き先ごとに分かれた。`-Wl,` は `link_flags` へ、書庫の名前と `ar` の引数文字列は落として**註に残す**（`# link input, not a compile flag: … — declare it as a dep`）。黙って落とさないのは、下書きが未検証だからである。

下書きはまだそのままでは組めないが、理由が変わった——`flags` の混入ではなく、**書かれていない `deps`** である。これは Meson の introspection がリンクの関係を言わないことから来る文書どおりの限界であり、註がその1行を指している。

### 検査

`projects/16-migrate` の
`the compile flags carry nothing that belongs to the link or the archiver`、
`the linker's own arguments go to link_flags instead`、
`and what was dropped is noted rather than removed silently`、
`and says what to write instead, which is the edge Meson never reported`。

**落としたものが註に残ること**を見ているのが要点である。下書きは未検証で
あり、消えたものがあることは読む側に伝わっていなければならない。

「Meson から取り込んだ下書きがそのまま組める」という検査は取り下げた。
`deps` が空なのは Meson がリンクの関係を言わないためで文書どおりの限界で
あり、2目標の木がそのまま組めることは**そもそも期待できない**。代わりに
`so what still stops the draft is the missing edge, not the arguments` を置き、
残る理由が変わったことを固定してある。


## F-058

報告先: [sabas0ba/dowel#141](https://github.com/sabas0ba/dowel/issues/141)

**`template` を宣言したパッケージは `dowel check` を通らない。何も名指しして
いないのに `not-a-target` が出る。**

種別: 実装。未修正（`c154097`）。ADR-0035 の `template` を `apps/blink` に
使ってみて踏んだ。

### 観測

```console
$ dowel check
error[not-a-target]: `t:warn` is a template, not something to build
   = note: build a target that uses it, as in `use = [template("...")]`
1 errors, 0 warnings
$ echo $?
1
```

ほかの入口は正しい。

| 打ったもの | 結果 |
|---|---|
| `dowel check` | **`not-a-target` で終了状態 1** |
| `dowel build`（名指しなし） | 通る。雛形はグラフに現れない |
| `dowel test`（名指しなし） | 通る |
| `dowel build warn`（名指し） | `not-a-target`。**文書どおり** |

`docs/12-build-reference.md` は「**Naming one on the command line** is
`not-a-target`」と書いている。`check` は何も名指ししていない。

### なぜ問題か

`check` は「評価と診断のみ。ビルドしない」入口であり、編集中や commit 前に
誤りを洗い出す用途として置かれている。**その入口が、新機能を使った瞬間に
必ず落ちる。**

診断は「`use = [template("...")]` を使え」と助言するが、木は既にそう書いて
いる。助言に従っても直らない。しかも `build` は通るので、何が悪いのかが
利用者には分からない。

### 期待

`check` は雛形を「組むもの」として数えない。`build` と `test` が既にそう
なっているので、同じ扱いを `check` にも、という形である。`not-a-target` は
名指ししたときのために残す。

### なぜ内側から見つからないか

雛形のフィクスチャは「展開されること」「`sources` が拒まれること」「名指しが
`not-a-target` になること」を見れば足りる。どれも `build` か、意図的に名指し
する経路である。**何も名指しせずに `check` を打つ**のは利用者が最初にやる
ことだが、機構のフィクスチャからは出てこない。

### 検査

`apps/blink` の `the bare-metal package passes check`。known_issue F-058 で
ある。

対照として、`build` と `test` が雛形があっても通ること、展開された旗が3つの
目標すべてに届くこと、雛形がグラフに現れないこと、名指しが正しく拒まれること
は通常の検査として置いてある。壊れているのが機構ではなく `check` の目標の
数え方であることが、並びから読める。

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
- **三つ組ごとの機械の旗を束ねられない** — `apps/dsp` で踏んだ。
  `-mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16` が
  `core`（ライブラリの `match` の腕）と `fw`（使う側の目標）の2か所に要り、
  同じ値でなければならないのに揃っていることを確かめる手立てが無い。
  食い違えば呼び出し規約の違う書庫ができる。ただし `docs/12-build-reference.md`
  の種別の表は `template`（非再帰の再利用単位）を予約済みであり、変数も
  文字列の連結も無いのは ADR-0004 の決定である。そこで解かれるものと読んで
  報告しなかった。`expect.sh` は代わりに**2か所が実際に同じ旗を出している
  こと**をグラフから確かめている
