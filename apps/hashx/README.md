# hashx — ライブラリ

ここまでの実アプリは、いずれも最後は実行ファイルだった。ライブラリはそうでは
ない。**成果物そのものが製品**であり、それを受け取るのは他人である。見るべき
ことが変わる。

```
lib/       ライブラリ本体。公開する見出しは include/hashx/hashx.h の1枚
ctool/     C の利用者。別パッケージ
cxxtool/   C++ の利用者。別パッケージ
tests/     ライブラリのテスト
```

```console
$ dowel -C lib build
built: .../lib/libhashx.a

$ printf '123456789' | ./hashsum      # C の利用者
crc32=cbf43926
$ printf '123456789' | ./hashcxx      # C++ の利用者、同じ書庫から
crc32=cbf43926
```

中身は CRC-32 と FNV-1a である。既知のベクタ（`"123456789"` の CRC-32 は
`0xCBF43926`）で固定できるものを選んだ。ライブラリで確かめたいのは値の正しさ
ではなく**配れるかどうか**なので、中身は小さいほうがよい。

## 面（おもて）は成果物の側で決まる

ライブラリの面は、書き手が「public に置いた」ことではない。**成果物が外へ出す
名前**である。数えれば分かる。

```
[lib.hashx.private]
flags = [..., "-fvisibility=hidden"]
```

```c
#define HASHX_API __attribute__((visibility("default")))
HASHX_API uint32_t hashx_crc32(const void *data, size_t len);
```

既定を隠し、印を付けたものだけを出す。印の付け忘れは面を**狭める**だけで、
面が勝手に広がることはない。

```console
$ readelf --syms --wide libhashx.a | awk '$4=="FUNC"'
GLOBAL DEFAULT  hashx_crc32       ← 公開
GLOBAL DEFAULT  hashx_crc_begin
...
GLOBAL HIDDEN   hx_crc_step       ← 翻訳単位は跨ぐが外へは出ない
LOCAL  DEFAULT  build             ← static
```

`expect.sh` は、**見出しが `HASHX_API` を付けた名前の集合**と、**書庫が
GLOBAL DEFAULT で出す名前の集合**が一致することを見る。片方だけを触れば落ちる。
印を付けずに新しい大域を足しても面に入らないことも、実際に足して確かめている。

## 3つの関門（すべて `17bd54e` で開いた）

この木を書くことで3件を報告し、いずれも本体に修正が入った。ここには
「いま何がどう書けるか」と、直る前に何が起きていたかを記す。

### C のライブラリを C++ から呼ぶ（[F-028](../../docs/10-findings.md#f-028)）

`abi` は `must_equal` である。C のライブラリと C++ の利用者は、正しく書けば
違う札になる。ライブラリの面は**境界**を名乗る。

```toml
[lib.hashx.public]
abi = "c"          # この面は C ABI。利用者の言語を問わない
```

`extern "C"` を跨ぐ呼び出しに ODR の危険は無いため、`c` はどの札とも合う。
C++ の利用者は自分の言語（`gnu++17`）をそのまま書ける。

境界を名乗らない札どうしが食い違えば、これまでどおり `abi-mismatch` で
落ちる。`expect.sh` はライブラリの札を `gnu11` に戻して、それを確かめている。
修正が黙って広がっていないことは、そちら側でしか言えない。

直る前は `c` が無く、利用者はライブラリの札を書き写すしかなかった。それは
札から意味を奪う——「本当の ABI」ではなく「このライブラリを使う組」を表す
名前になる。

### 出所の切り替え（[F-029](../../docs/10-findings.md#f-029)）

ライブラリの出所は開発の途中で変わる。手元で直しながら使う（`path`）から、
固まって配る（`git` + `rev`）へ。切り替えは片方を消してもう片方を書く操作で
あり、**消し忘れ**は起きる。

いまは出所を2つ名乗る項目が拒まれる。0個が `incomplete-dependency` で
拒まれるのと対になり、規則が両側に揃った。

直る前は無診断で通り、黙って `path` が勝った。手元に `../lib` があるので
組めてしまい、CI でも通る。気づくのは、その木を持たない誰かが組んだとき
だった。

### 版は1か所（[F-030](../../docs/10-findings.md#f-030)）

版は `dowel.toml` にしか無い。翻訳へは `pkg.version` で届く。

```toml
[lib.hashx.private]
defines = { HASHX_VERSION = pkg.version }
```

見出しに写しは無い。だから**版を動かすと、成果物が答える版も動く**。
`expect.sh` は `dowel.toml` を 9.9.9 にして組み直し、`--version` が 9.9.9 と
答えることまで確かめている。写しが無いのだから、ずれようがない。

直る前は届ける語彙が無く、作者は手で写すしかなかった。写し間違いは無診断で
通り、成果物は古い版を答え続けた。

## 配る先

`lib` は静的な書庫だけである。`.so` も `.pc` も CMake の設定も出ない。dowel は
システムのライブラリを pkg-config 経由で**使える**（`projects/17-deps`）が、
その逆は無い。

これは所見にしていない。`docs/90-roadmap.md` が第3段に「CMake の
`find_package` 設定を出す」、第6段に「書き出し対象（C ABI ほか）」を既に載せて
いるためである。現状だけ記録してある
（`what a build produces today is one static archive and nothing a foreign
consumer could read`）。段が来たときに何が変わるかは、この1行で読める。

## 何を dowel に効かせているか

| | |
|---|---|
| 公開と非公開 | `include/` だけが渡り、`src/` の内部見出しは渡らない |
| 言語の混在 | 同じ書庫が C の利用者にも C++ の利用者にも繋がること |
| リンクの駆動 | 閉包に C++ があればリンクは C++ のドライバを通ること |
| `abi` の札 | `must_equal` が何を拒むか（[F-028](../../docs/10-findings.md#f-028)） |
| 依存の出所 | `path` / `git` / `version` の扱い（[F-029](../../docs/10-findings.md#f-029)） |
| 機能フラグ | 実装は選ぶが**答は選ばない**こと |
| 増分 | 公開する見出しを触ると、取り込んだ利用者が組み直されること |

「機能フラグが答を選ばない」はライブラリ特有である。`small` は CRC の表を
持つ版と都度計算する版を切り替えるが、利用者から見て値が違ったら、それは
構成ではなく故障である。両方の構成で同じベクタを通している。

## 共有として配る（ADR-0030）

ここまでこのライブラリが作れたのは静的な書庫だけだった。書庫は「その木の
中でしか意味がない」形であり、dowel を使わない相手へ渡すには足りない。
`--features=shared` で共有ライブラリになる。

```toml
linkage = "shared" when feature.shared
exports = ["hashx_fnv1a", "hashx_crc32", "hashx_crc_begin",
           "hashx_crc_feed", "hashx_crc_end", "hashx_version"] when feature.shared
```

`exports` に既定は無い。**平面ごとに意味が逆だからである**——ELF と Mach-O
では `static` でない名前がすべて出るが、Windows では何も出ない。どちらを
既定にしても、同じマニフェストが2つの違う面を記述することになる。だから
一覧を要求し、リンカごとの形（version script / シンボル一覧 / `.def`）は
その1つの宣言から作る。省くと `missing-exports` で拒まれる。

名前は**そのまま**一致する。接頭辞ではない——`hashx_crc` と書いても
`hashx_crc_end` は出ない。書き落とせば、使う側のリンクで気づく。

| | 静的（既定） | `--features=shared` |
|---|---|---|
| 成果物 | `libhashx.a` | `libhashx.so` |
| 閉包の翻訳 | そのまま | すべて `-fPIC` |
| 使う側の `NEEDED` | 無し | `libhashx.so` |
| 走らせ方 | そのまま | `runpath` が木の `lib/` を指すのでそのまま |

答は配られ方で変わらない。`hashsum < abc` は両方で同じ行を出す——ここが
利用者から見た「同じライブラリ」の意味である。

### 関門: 自分の検査が組めない（[F-056](../../docs/10-findings.md#f-056)、[#134](https://github.com/sabas0ba/dowel/issues/134)）

このライブラリの検査は内部の名前（`hx_crc_step`）を直に呼ぶ。公開の面だけを
叩く検査では、面の後ろにある表の構築を覆えないためである。

共有にすると、それが繋がらなくなる。

```console
$ dowel -C lib test --features=shared
… ld: undefined reference to `hx_crc_step'
```

共有ライブラリとしては正しい振る舞いである。足りないのは**内側へ繋ぐ手立て**
の方で、いま残る道は「面を壊す（内部の名前を `exports` に足す）」「ソースの
一覧を2か所に持つ」「共有では検査を諦める」しかない。CMake の `OBJECT`
ライブラリ、Meson の `objects:` がこの役を果たしている。

検査は静的の側で同じものが通ること、共有の側でも**使う側**は組めて走ること
を対照に置いてある。壊れているのが配られ方ではなく内側への繋ぎ方であることが、
並びから読める形にしてある。
