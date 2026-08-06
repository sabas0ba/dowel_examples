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

## 3つの関門

### C のライブラリを C++ から使えない（[F-028](../../docs/10-findings.md#f-028)）

`abi` は `must_equal` である。C のライブラリと C++ の利用者は、正しく書けば
違う札になる。

```console
$ dowel -C cxxtool build           # abi = "gnu++17" と書いた
error[abi-mismatch]: `abi` does not match: "gnu++17" vs "gnu11"
```

見出しは `extern "C"` で囲ってあり、`extern "C"` の境界を跨いだ呼び出しに
ODR の問題は無い。それでも札が違えば拒まれる。**利用者はライブラリの札を
書き写す**しかない。

配る側から見ると、これは「札を1つ決めることが、すべての利用者にその札を
強制すること」を意味する。ライブラリの作者は利用者を知らない。

### 出所を2つ名乗っても黙って通る（[F-029](../../docs/10-findings.md#f-029)）

ライブラリの出所は開発の途中で変わる。手元で直しながら使う（`path`）から、
固まって配る（`git` + `rev`）へ。切り替えは片方を消してもう片方を書く操作で
あり、**消し忘れ**は起きる。

```toml
[[dependencies]]
name = "hashx"
path = "../lib"                                 # 消し忘れ
git  = "https://example.invalid/hashx"
rev  = "<40 桁の sha>"
```

```console
$ dowel check
check passed: 2 packages, 3 targets             # 無診断
```

`git` の宛先は解決できない TLD だが、取りに行かないので何も起きない。手元に
`../lib` があるので組めてしまい、CI でも通る。**気づくのは、その木を持たない
誰かが組んだとき**である。

出所が0個なら `incomplete-dependency` で拒まれる。規則が片側にしか無い。

### 版が2か所に別々に書かれる（[F-030](../../docs/10-findings.md#f-030)）

```toml
version = "0.4.0"          # dowel.toml
```
```c
#define HASHX_VERSION "0.4.0"   /* 見出し。手で写している */
```

マニフェストの版を翻訳へ届ける語彙が無い（`cfg` にパッケージの情報は無い）。
片方だけ動かしても診断は出ず、成果物は古い版を答え続ける。

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
