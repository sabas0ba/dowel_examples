# 20-cases — 1本の実行ファイルから複数のテストを登録する

事例の宣言には2つの形がある。どちらも「事例は何か」に答え、同時には書けない。

**マニフェストに登録する**（[ADR-0022](https://github.com/sabas0ba/dowel/blob/main/docs/adr/0022-test-cases.md)、ctest の `add_test` にあたる）。

```toml
[test.suite.cases]
plain   = { args = ["plain"] }
slow    = { args = ["sleep1"], labels = ["slow"] }
rejects = { args = ["fail"], should_fail = true }
strict  = { args = ["env"], env = { SUITE_MODE = "strict" } }
patient = { args = ["plain"], timeout = 30 }
```

**実行ファイル自身に列挙させる**（[ADR-0023](https://github.com/sabas0ba/dowel/blob/main/docs/adr/0023-harness-protocol.md)、cargo test の形）。規約はマニフェストが述べ、dowel は枠組みを1つも知らない。

```toml
[test.disc.harness]
list = ["--list"]      # これを渡すと1行1件で名前を書き出す
run  = ["--run"]       # これに続けて名前を渡すと、その1件だけ走る
```

事例は**同じ実行ファイルの別の起動**であり、翻訳単位を増やさない。この層の
subject も試験フレームワークを使わず、引数で振る舞いを選ぶ。設計をそのまま
写した形である。

## 何を固定するか

| | |
|---|---|
| 宣言が届くか | `args` / `env` / `timeout` / `should_fail` / `labels` / `cwd`、条件付きの事例 |
| 判定 | 時間切れとシグナルは `should_fail` を満たさない。異常な終わり方は期待された失敗ではない |
| 選べるか | `--label` / `--failed` / `--fail-fast` / `--test-jobs`、印字されたラベルの貼り戻し |
| 空振り | 誰も持たないラベル・消えた記録は、0件通過ではなく失敗 |
| 検証 | 名前の文法、未知の鍵、型と位置、重複、空の表、表見出しの誤り |
| 語彙 | `schema dump` の `case_properties` / `harness_properties` / `runner_properties`、`--no-run` の一覧 |
| 発見 | 列挙の読み方、失敗・時間切れの扱い、`cases` との排他 |

## 見つけたもの

この層で報告した 14 件（F-032〜F-045、[#88](https://github.com/sabas0ba/dowel/issues/88)〜[#101](https://github.com/sabas0ba/dowel/issues/101)）は、**すべて `e12bac7` で修正された**。
検査は新しい挙動を使う形へ書き換えて通常の検査として残してある。

ハーネス規約を検査して1件が新たに出て（[F-047](../../docs/10-findings.md#f-047)）、
これも `9858932` で直った。

マニフェストに書く名前は書き手が選べるが、**列挙が返す名前は選べない**。
既存の試験フレームワークの出力には空白も `/` も普通に混ざる。規則が片方の
入口にしか無い、という形だった。いまは両方に揃っている。

この1件は、**直ったのに検査が落ち続けた**例でもある。元の検査は「壊れた
ラベルが出力に現れないこと」を見ていたが、修正後の診断は拒んでいるラベルを
引用して説明する。出力に現れることが正しい状態になったので、その見方では
偽の失敗になった。終了状態で判定する形へ書き換えてある。
