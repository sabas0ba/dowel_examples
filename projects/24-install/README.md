# 24-install — 組んだものを prefix の下へ出す

`dowel install --prefix=<dir>` は、組んだものを写す
（[ADR-0041](https://github.com/sabas0ba/dowel/blob/main/docs/adr/0041-install.md)）。
出したライブラリは pkg-config の記述子で自分を説明する
（[ADR-0043](https://github.com/sabas0ba/dowel/blob/main/docs/adr/0043-pkgconfig-generation.md)）。

ここまでの決定はすべて**1つのビルド木の中**の話だった。共有ライブラリを
宣言し（ADR-0038）、面を宣言して確かめ（ADR-0039）、世代を付けられる
（ADR-0040）——それらを**置く先**が無かった。

## 見るべきものは2つある

### 1. 出した先で動くこと

共有ライブラリを繋いだ成果物は、ビルド木への絶対パスを記録する。写しただけ
の実行ファイルは**木が在る間は動く**。壊れるのは受け取った側の機械であり、
作った側では再現しない。

決定は「自分からの相対の探索路も記録する」である（`$ORIGIN/../lib`）。
確かめ方は1つしかない——**木を消し、prefix ごと別の場所へ移して、動かす**。

```sh
cp -a prefix moved && rm -rf app/.dowel && moved/bin/app
```

`$` は ninja にとっても make にとっても、make の行を走らせる shell にとっても
意味を持つ記号である。引用を1つ落とすと、実行ファイルは**繋がり、木の中では
動き、移した後にだけ壊れる**。3つの backend すべてで見る。

### 2. 出した先が見つかること

置いただけでは誰にも引けない。dowel は pkg-config を**読む**側でありながら
**書け**なかった。段階的な移行という前提が崩れるのはここだった——使う側が
CMake や Meson や Makefile のままでは、移ったライブラリを引く手立てが無い。

読める記述子と**通る**記述子は別である。中身を読むだけでは足りないので、
**dowel を知らない使う側**を実際に組む。

```sh
cc consumer/main.c $(pkg-config --cflags --libs shapes)
```

## 木の形

| ところ | 何を持つか |
|---|---|
| `lib/` | `shapes`（共有、`soversion`、`exports`、公開の見出し・定義・結合旗）と、その上に乗る `render`（archive） |
| `app/` | `shapes` を使う `bin` と、配り物ではない `test` |
| `consumer/` | dowel を知らない使う側。pkg-config が刷る引数だけで組む |

`render` を**archive のまま**にしてあるのは、共有と静的で「配った記述子で繋がる
かどうか」が変わるためである。

## 何を確かめるか

| 見るもの | 期待 |
|---|---|
| 出るもの | `bin/` と `lib/`、公開ディレクトリの中身が `include/`、`lib/pkgconfig/<名>.pc` |
| 出ないもの | `test` / `bench`、使う側パッケージから見た依存の見出し、`bin` の記述子 |
| 世代 | 世代付きの実体に、世代なしの別名（symlink） |
| 同一性 | 組み直さない。配るバイト列は試したものと同じ |
| 行き先 | `--prefix` は必須。無ければ拒み、その名を出す |
| `--destdir` | 行き先だけ前へずれ、記述子は**本来の** prefix を述べる |
| 記述子 | `public` 区画を別の記法で書いたもの。`pkg-config --validate` を通る |
| 使う側 | dowel 無しで翻訳・結合・実行まで通る |
| 面のディレクトリ | ソースが混ざっていれば `source-among-headers`。宣言を指し、配るものは変えない |

同じパッケージの兄弟に乗るライブラリの記述子は、その兄弟を名指す
（[F-062](../../docs/10-findings.md#f-062)、`0.1.0` で修正済み）。共有なら
DT_NEEDED で繋がってしまうので、`render` を**archive のまま**にしてあるのは
静的にしたときにだけ現れるこの経路を通すためである。

## 面として配るディレクトリ（[ADR-0059](https://github.com/sabas0ba/dowel/blob/main/docs/adr/0059-an-interface-directory-holds-the-interface.md)）

`public.includes` は「使う側が何に対して翻訳するか」であり、install はその
中身を `include/` の下へ写す。見出しが自分のディレクトリを持つ限り、書かれた
とおりに働く。ソースの隣に置かれている場合はこうなる。

```console
$ dowel install --prefix=out
installed: out/include/core.c
installed: out/include/main.c
```

`core.c` はライブラリ自身のソースであり、`main.c` は**binary の**ソースで
ある。どちらも `pkg-config --cflags` が指す `include/` の下に出る。

宣言が2つの仕事をしている。**検索の路**としては正しい——`src/` に対して
翻訳する使う側は `core.h` を見つける。**何を配るかの表明**としては広すぎ、
それを言う者が居なかった。

拡張子で濾すのは明らかな一手であり、そして誤りである。宣言はディレクトリ
全体を使う側の `-I` に載せるので、一部だけを配れば `#include "impl.c"` を
する単一ファイルのライブラリが壊れる。**dowel は述べて、そのまま配る。**

検査は、警告が出ることに加えて、配られたバイト列が変わらないこと、1つの
宣言につき1件であること、そしてソースの混ざっていないディレクトリでは
**何も言わない**ことを見る。最後のものが無いと、この警告が「install すると
鳴る」ではなく「ソースが混ざっていると鳴る」ことを言えない。
