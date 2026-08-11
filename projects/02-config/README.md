# 02-config — 構成による分岐

```
app ──private──> probe
```

`probe` が構成の語彙をひととおり使い、`app` がその依存元から見る。

| 使う要素 | 書いてある場所 |
|---|---|
| `match cfg.opt`（有限・網羅） | `probe` の `public.defines`、`app` の `private.defines` |
| `match host.os`（有限・網羅） | `probe` の `private.defines` |
| `match host.arch`（有限・網羅） | `app` の `private.flags` |
| `match cfg.target`（開いた値域・`_` 必須） | `probe` の `private.link_flags` |
| 後置 `when feature.<name>` | `probe` の `private.flags` |
| `when` の合成（`and` / `or` / `not` / 括弧） | `app` の `private.c_flags` |

## 何を固定するか

1. **`match` の結果が引数まで届く。** `match` の結果は `Cfg<T>` であり、
   具体化はアクション生成まで遅れる。遅らせた結果が最終的に
   コンパイラの引数として正しく現れることを、実行時の値で確かめる
2. **依存の公開値も構成で変わる。** `probe` の `public.defines` は
   `match cfg.opt` の結果である。`app` は自分で `match` を書いていないが、
   `--config=release` で `PROBE_OPT` が変わる。
   ライブラリの実体とヘッダに届いた定数が食い違えば、実行時に落ちる
3. **公開と非公開が分離している。** `probe` の `private.defines` /
   `private.flags` / `private.includes` は `app` の引数に現れない。
   同時に `probe` 自身のコンパイルには効いている。「消えている」のではなく
   「伝播しない」ことを、両側から見る
4. **後置 `when` が要素を落とす。** `--no-default-features` で
   `-DPROBE_TRACE=1` が消え、`probe_trace()` が 0 を返す
5. **機能が構成識別子に入る。** `debug-trace` と `debug` が別の
   ビルドディレクトリになる。入らないと、機能を切り替えた成果物が混ざる
6. **`compile_commands.json` に具体化後の値が入る。** 言語サーバに渡るのは
   この内容であり、ここが崩れれば補完と診断が同じだけ崩れる
7. **述語が合成できる。** `and` / `or` / `not` と括弧。優先順位は
   not > and > or

## 述語の合成（[ADR-0032](https://github.com/sabas0ba/dowel/blob/main/docs/adr/0032-predicate-composition.md)）

```toml
c_flags = [
    "-DP_EITHER" when target.os == "linux" or target.os == "macos",
    "-DP_NOTWIN" when not target.os == "windows",
    "-DP_BOTH"   when feature.trace and not feature.quiet,
    "-DP_PAREN"  when (target.os == "linux" or target.os == "macos") and cfg.opt == "debug",
]
```

`not` が要るのは「Windows 以外のどこでも」を正しく保つためである。他の値を
並べる書き方は、`target.os` に語が1つ足された日に**黙って覆わなくなる**。
数え上げは語彙の変化に追随しない。

検査の書き方で2つ気をつけている。

- **決して真にならない述語を1つ混ぜてある。** 真になるものだけ並べると、
  「何を書いても真」の実装でも検査が通る
- **優先順位は括弧を書かない式から読む。** `a and not b or b` に対し、
  片側だけを反転させる機能を立てると、前半が偽になり後半で真に戻る。
  括弧を書いてしまうと、確かめているのは括弧であって優先順位ではない

語彙の検査は葉まで届く。合成の中に隠れた綴り違いは、単独のときと同じに
`unknown-pattern` で拒まれる——ここが緩いと、合成は誤りを隠す場所になる。

主張の大半は C 側の `#error` と実行時の比較に書いてある。
伝播しないことの検査だけは、値の不在でしか観測できないため
アクショングラフを見ている（`args_lack`）。

## 実行ファイルの出力

```
app_opt=0 probe_opt=0 arch=1 os=1 trace=1
```

`--config=release` で `app_opt` と `probe_opt` が 1 になり、
`--no-default-features` で `trace` が 0 になる。
`arch` と `os` はビルドしたホストの値である。
