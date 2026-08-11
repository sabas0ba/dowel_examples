# dsp — 1つのライブラリを複数の三つ組で

ここまでのアプリは、1つのアプリが1つの対象を持っていた。実務でよくあるのは
その逆で、**算法は1つ、走る機械が何種類もある**。手元で書いて試し、同じもの
を ARM の基板と RISC-V の基板で動かし、さらに OS の無いマイコンにも載せる。

そのとき問われるのは「組めるか」ではなく、**どの機械でも同じ答が出るか**で
ある。

```
core/   算法。整数だけで書いてあり、4つの三つ組へ組まれる
cli/    使う側。ホストの載っている3つ
gui/    使う側。cairo を引く。手元のみ
fw/     使う側。Cortex-M4F。OS も libc も無い
```

| 三つ組 | 走らせ方 |
|---|---|
| `x86_64-unknown-linux-gnu` | そのまま |
| `aarch64-unknown-linux-gnu` | `qemu-aarch64-static` |
| `riscv64gc-unknown-linux-gnu` | `qemu-riscv64-static` |
| `thumbv7em-none-eabihf` | `qemu-system-arm`（MPS2-AN386、semihosting） |

## 算法

Q15 固定小数の双二次フィルタ（2次バターワース低域通過）である。緩やかな
三角波に速い矩形波を重ねた試験波を通し、後者だけが落ちる。

**整数だけで書いてある。** 浮動小数を使うと、同じ式でも機械によって丸めが
変わりうる。答が「だいたい合っている」になった瞬間、複数の三つ組で同じ答が
出ることを検査にできなくなる。

中間の積は `int64_t` で持つ。`a1` は Q15 で -58278、`y1` は最大 32767 なので、
積は 1.9e9 を超えて `int32_t` を溢れる。溢れた側は機械によって畳まれ方が
変わりうる——**そこが三つ組ごとの差になる**。

畳み込み（CRC-32）も、標本を**明示的に下位バイトから**入れている。
`dsp_crc32(v, n * 2)` で済ませると記憶の中の並びをそのまま読むので、大小の
端が違う機械では違う値になる。いま相手にする4つはすべて小端だが、たまたま
揃っているだけのものを検査の土台にはしない。

## 同じ答

```console
$ ./dsp                                    # x86_64
in=53106e76 out=b9b26ef1 rough_in=1342514 rough_out=98452
$ qemu-aarch64-static -L /usr/aarch64-linux-gnu ./dsp      # ARM
in=53106e76 out=b9b26ef1 rough_in=1342514 rough_out=98452
$ qemu-riscv64-static -L /usr/riscv64-linux-gnu ./dsp      # RISC-V
in=53106e76 out=b9b26ef1 rough_in=1342514 rough_out=98452
```

```console
$ dowel -C fw test onhw --target=thumbv7em-none-eabihf
test dsp-fw:onhw ... ok (5009ms)
```

**期待値は `tests/golden.h` の1枚**であり、4つすべてがそれを読む。ホスト向け
の検査（`tests/vectors.c`）とベアメタルの検査（`fw/src/onhw.c`）は、libc の
有無で実体が分かれるが、突き合わせる数は同じである。三つ組ごとに期待値を
分けた瞬間、この検査は「機械が違えば答も違う」を追認するだけのものになる。

答が同じであることと機械が同じであることは別なので、**機械が本当に違う**
ことも見ている。`file` が aarch64 / RISC-V / x86-64 と答えること、ベアメタル
側が生の像も出すこと。語長は3つとも同じ（LP64）なので、それが答を揃えて
いる理由ではないことも固定してある。

## 三つ組ごとに変わるもの

ソースは1つで、`#ifdef` は1つも無い。変わるのは**旗と ABI ラベルだけ**で
ある。

```toml
[lib.dsp.private]
flags = match cfg.target {
    "thumbv7em-none-eabihf" => [
        "-Wall", "-Wextra",
        "-mcpu=cortex-m4", "-mthumb", "-mfloat-abi=hard", "-mfpu=fpv4-sp-d16",
        "-ffreestanding", "-fno-builtin",
    ],
    _ => ["-Wall", "-Wextra"],
}
```

ホスト付きの3つに機械の旗が要らないのは、三つ組を渡されたコンパイラが自分で
正しく選ぶからである。それが `[toolchain.<triple>]` に別のコンパイラを書く
意味である。

書きたいのは「OS が無い側なら freestanding」であって「この三つ組なら」では
ない。語彙に対象の OS を指す語が無いので三つ組を数え上げている
（[F-053](../../docs/10-findings.md#f-053)）。腕は1本で済んでいるが、対象が
増えるたびに `flags` と `abi` の両方へ増える。

## 関門 1: ライブラリが自分の道具立てを持てない（[F-054](../../docs/10-findings.md#f-054)、[#125](https://github.com/sabas0ba/dowel/issues/125)）

どのコンパイラで組むかは**ライブラリの知識**である。しかし依存の宣言は
使う側の build に効かない。

```console
$ dowel -C app build --target=aarch64-unknown-linux-gnu
error[missing-toolchain]: no toolchain is declared for target `aarch64-unknown-linux-gnu`
  = note: declare one, for example `[toolchain.aarch64-unknown-linux-gnu]` with `c = "..."`
warning[toolchain-mismatch]: package `mylib` asks for `c = "aarch64-linux-gnu-gcc"` but the build uses `cc`
```

同じ出力の中で、dowel は「宣言が無い」と言って止まり、その2行下で
「`aarch64-linux-gnu-gcc` と書いてある」と読み上げている。**探しているものを
見つけていて、それでも無いと言う。**

結果、`core` が4つの表を持っていても、`cli` は2つを、`fw` は1つを写す。
支える三つ組の数 × 使う側の数だけ写しが増え、食い違っても警告で済む。

警告が出ること自体は文書どおりなので、報告したのは**診断が読んだものを
言わないこと**の側である。

## 関門 2: 目標を三つ組で絞れない（[F-055](../../docs/10-findings.md#f-055)、[#126](https://github.com/sabas0ba/dowel/issues/126)）

`core` の検査はホスト向けである（libc を使う）。`fw` をベアメタル向けに
組むと、それが混ざって落ちる。

```console
$ dowel -C fw test --target=thumbv7em-none-eabihf
… ld: libc.a(libc_a-lseekr.o): undefined reference to `_lseek'

$ dowel -C fw test onhw --target=thumbv7em-none-eabihf
test dsp-fw:onhw ... ok
```

`fw` のマニフェストに誤りは無い。落ちているのは依存側の検査である。
ライブラリの側で「この検査はホストの載っている三つ組でだけ」と書く手立てが
無く（`[package] targets` はパッケージ全体に掛かる）、残るのはパッケージを
割ることだけになる。

ホスト付きの三つ組では余計に組まれるだけで無害なので、**組めない三つ組が
混じって初めて**現れる。

## 束ねられない旗

機械の旗は2か所に要る——`core` の `match` の腕と、`fw` の目標である。同じ値
でなければ呼び出し規約の違う書庫ができるが、揃っていることを確かめる手立てが
文法に無い（変数も文字列の連結も無い）。

`template` という種別が「非再帰の再利用単位」として予約されているので、
そこで解かれるものと読んで報告はしていない。`expect.sh` は代わりに、
**2か所が実際に同じ旗を出していること**をグラフから確かめている。

## 見せる側

`gui/` は cairo で波形を描き、PPM に書き出す。同じ算法を引く4番目の使い方で
あり、見どころは算法の側が**何も変わらない**ことである——cairo はこの使う側
の private な依存で、`core` の翻訳にも成果物にも現れない。

窓を開けるかどうかは [plot](../plot/) が見ている問題なので、ここでは扱わない。

```console
$ ./dspview --out drawn.ppm
drew 512x200 from 256 samples, rough_in=1342514 rough_out=98452
```

描いたものは読み返している。寸法と、隅が単色の背景のままであること。

## 何を dowel に効かせているか

| | |
|---|---|
| 三つ組ごとの道具立て | 4つの `[toolchain.<triple>]`。手元の `cc` が別の対象の物を作らない |
| 三つ組ごとの runner | qemu-user 2つと qemu-system 1つ |
| 三つ組ごとの旗 | `match cfg.target`。ソースは1つ、`#ifdef` は無し |
| 三つ組ごとの ABI ラベル | ベアメタルだけ別。組まない目標の宣言も突き合わされる |
| 対象の分離 | ビルドディレクトリが分かれ、同名の書庫の中身が違う |
| 依存の道具立て | 効かない。ここが F-054 |
| 目標の三つ組での絞り込み | できない。ここが F-055 |
| 派生 | ベアメタルの側は `objcopy` で生の像も出す |
| 増分 | 触った対象だけが組み直され、他の対象を道連れにしない |
