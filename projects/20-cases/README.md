# 20-cases — 1本の実行ファイルから複数のテストを登録する

`[test.<name>.cases]` は ctest の `add_test` にあたる（[ADR-0022](https://github.com/sabas0ba/dowel/blob/main/docs/adr/0022-test-cases.md)）。
事例は**同じ実行ファイルの別の起動**であり、翻訳単位を増やさない。分けるのは
引数だけである。

```toml
[test.suite.cases]
plain   = { args = ["plain"] }
slow    = { args = ["sleep1"], labels = ["slow"] }
rejects = { args = ["fail"], should_fail = true }
strict  = { args = ["env"], env = { SUITE_MODE = "strict" } }
patient = { args = ["plain"], timeout = 30 }
```

```console
$ dowel test
test subject:suite/plain ... ok (1ms)
test subject:suite/slow ... ok (1001ms)
test subject:suite/rejects ... ok (1ms)
test subject:suite/strict ... ok (1ms)
test subject:suite/patient ... ok (10ms)
test subject:lone ... ok (1ms)
```

`subject:lone` は事例を書かない目標である。ADR-0022 の規則どおり、目標自身が
1件になる。

## ハーネスを採らない設計

dowel は実行ファイルに「どんな事例を含むか」を尋ねない。C には標準の試験
ハーネスが無く、1つの規約を採ると利用者の枠組みを決めてしまうためである。
そのぶん**事例はマニフェストに書く**ことになる。

この木の `tests/suite.c` も、試験フレームワークを使わず引数で振る舞いを
選ぶ。設計をそのまま写した形である。

## 何を固定するか

| | |
|---|---|
| 宣言が届くか | `args` / `env` / `timeout` / `should_fail` / `labels` |
| 翻訳単位 | 事例5件でも実行ファイルは1本 |
| 選べるか | `--label` / `--failed` / `--fail-fast` / `--test-jobs` |
| 並列 | 同じ目標の事例が同時に走り、表示は要求順のまま |
| 検証 | 未知の鍵、型、重複、`bin` への `cases` |
| 語彙として見えるか | `schema dump`、言語サーバ、走らせずに一覧すること |

最後の1行がこの層の持ち場である。1 と 2 は本体も内側から見ているが、
**「文書に書いてあるとおりか」「エディタが同じことを知っているか」は
外側からしか問えない**。

## 見つけたもの

14 件。うち3つが重い。

| | |
|---|---|
| [F-032](../../docs/10-findings.md#f-032) | `should_fail` がシグナルによる異常終了を期待どおりの失敗として通す |
| [F-034](../../docs/10-findings.md#f-034) | `--label` の空振りが状態 0（`60-cli.md` の記述と食い違う） |
| [F-042](../../docs/10-findings.md#f-042) | `schema dump` と LSP が `cases` を知らない |

F-032 は正しさに直接効く。`should_fail` を書く場所は「壊れた入力を食わせる
事例」であり、それは**クラッシュが最も起きやすい事例**でもある。この2つが
同じ場所に来ることが、外側の用途から見て初めて分かる。

F-034 と F-042 は、どちらも**文書に書かれた約束が実装されていない**形で
ある。`60-cli.md` は空振りを「zero tests で通すのではない」と述べ、
`12-build-reference.md` は「頁とエディタと診断は黙って食い違えない」と
述べている。

残りは [F-033](../../docs/10-findings.md#f-033)、
[F-035](../../docs/10-findings.md#f-035) から
[F-041](../../docs/10-findings.md#f-041)、
[F-043](../../docs/10-findings.md#f-043) から
[F-045](../../docs/10-findings.md#f-045)。

## 通ったもの

公平を期すと、次は正しく動いた。ラベルの形と要約、`--fail-fast`（走らな
かった数まで報告）、`--test-jobs` の並列と**要求順の表示**、時間切れの報告、
**時間切れが `should_fail` に優先すること**、`should_fail` が状態0で落ちた
ときの言い方、事例の型検査（未知の鍵・型不一致・重複鍵）、`[bin.*.cases]`
の拒否、`env` が親環境を継承したうえで上書きすること。

時間切れの優先は F-032 の論拠でもある。**異常な終わり方は期待された失敗では
ない**という判断は、既に一度下されている。
