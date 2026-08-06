# jsonfmt — 依存を持たない実アプリ

JSON を読んで整形して書く CLI。

```console
$ echo '{"b":[1,2],"a":"x"}' | jsonfmt
{
  "b": [
    1,
    2
  ],
  "a": "x"
}

$ echo '{"b":[1,2],"a":"x"}' | jsonfmt -c
{"b":[1,2],"a":"x"}

$ echo '{"a" 1}' | jsonfmt
jsonfmt: syntax error at byte 5
```

外部依存は1つも無い。C コンパイラだけで完結する層である。

## 形

```
core/          解析と整形。公開する見出しは include/json/json.h の1枚だけ
  include/json/json.h
  src/         internal.h, scan.c, sink.c, format.c
cli/           引数を解釈して読み書きする
  src/main.c
tests/         両パッケージのテストを1か所に置く
  parse.c      core の単体テスト
  cli.c        cli から見出しが繋がっていること
```

パッケージを2つに割るのは、**公開と非公開の分離が本当に使える形かどうか**を
確かめるためである。1つの木に押し込むと、その分離は名目になる。

`cli` は `core/include` だけを見る。`core/src/internal.h` は `core` の
`private` にしか入っていないので、`cli` から `#include "internal.h"` と書くと
コンパイルが通らない。`expect.sh` はそれを実際に書いて確かめている。

## 機能フラグ

入れ子の上限を構成で切り替える。

```toml
# cli/dowel.toml
[features]
deep = ["jsonfmt-core/deep"]
```

上位が下位の構成を選ぶ形である。実アプリでは普通に要る。

```console
$ jsonfmt --max-depth                          # 既定
256
$ dowel build --features=deep && jsonfmt --max-depth
4096
```

転送そのものは正しく働く。ただし転送した名前 `jsonfmt-core/deep` が構成の
識別子に入り、`/` がパス区切りとして展開される
（[F-023](../../docs/10-findings.md#f-023)）。

## 何を dowel に効かせているか

| | |
|---|---|
| 公開と非公開の分離 | 内部見出しを取り込むと**実際に落ちる**ところまで |
| 機能フラグの転送 | 上位の `deep` が下位に届き、成果物の答が変わる |
| テストの置き場所 | 宣言するパッケージの外にソースを置ける |
| 走らせた結果 | 整形結果を文字単位で見る。組めたことは正しいことを意味しない |
| 増分 | 1ファイル触って、隣が組み直されないこと |
| 呼び出しの形 | `test` と `build` を交互に打つ（[F-024](../../docs/10-findings.md#f-024)） |
| 計装の構成 | 翻訳とリンクの両方に、しかも依存先にも同じものを乗せられること |

## 落ちないことも見る

組めたことも、正しい入力で答が合うことも足りない。利用者が食わせるのは
壊れた入力である。`sanitize` という機能を宣言し、計装した版を組んで実際に
食わせる。

```
flags      = ["-fsanitize=address,undefined" when feature.sanitize, ...]
link_flags = ["-fsanitize=address,undefined" when feature.sanitize]
```

計装は翻訳とリンクの両方に要り、しかも `cli` だけに乗せても意味が無い。
`core` にも同じものが要る。そこで `sanitize` は `deep` と同じく
`jsonfmt-core/sanitize` へ転送する。ライブラリの private な `link_flags` が
使う側のリンクにも乗る（[F-018](../../docs/10-findings.md#f-018)）ため、
`cli` は計装を知らなくてよい。

食わせるのは 14 通り。終端の無い文字列、末尾の `\`、空、10k 個の未閉じ括弧、
制御バイト、100k 文字の原子、2万要素のオブジェクト、UTF-8 でないバイト、
5万個のエスケープなど。**落ちてよいのは「文法の誤り」としてであり、
シグナルでも計装の報告でもない。**

再帰の深さも同様である。`--features=deep,sanitize` で 10 万段を食わせ、
スタックを溢れさせるのではなく上限で拒むことを見る。

最後の2つは、**実アプリでしか出ない形**である。`projects/` の増分の層は同じ
呼び出しを2回繰り返して 0 件を見るが、開発中に実際に起きるのは
「`test` して `build` して」の往復であり、そこで初めて記録の上書きが現れる。

## 見つけたもの

| | |
|---|---|
| [F-023](../../docs/10-findings.md#f-023) | 転送した機能名の `/` がビルドディレクトリを2階層に割る |
| [F-024](../../docs/10-findings.md#f-024) | 狭い呼び出しが記録を上書きし、次の広い呼び出しがやり直す |

どちらも「約束を1つずつ確かめる」形では現れない。前者はパッケージを跨いだ
機能名を使って初めて `/` が入り、後者は呼び出しの形を変えて初めて出る。
