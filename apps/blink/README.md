# blink — 組み込み（ベアメタル）

libc も起動コードも持たない対象。入口はベクタ表の先の `_reset` であり、
記憶の配置はリンカスクリプトが決める。

対象は **Cortex-M4F**（`thumbv7em-none-eabihf`）。OS を持たない triple であり、
ツールチェーンは `arm-none-eabi-*` である。機械は **MPS2-AN386** を選んだ。
qemu-system-arm がこの機械を持つため、**組んだものを実際に走らせられる**。

```console
$ dowel build --target=thumbv7em-none-eabihf
built: .../bin/firmware
built: .../bin/firmware.bin
built: .../bin/firmware.hex

$ arm-none-eabi-size .../bin/firmware
   text	   data	    bss	    dec	    hex
    320	      0	     16	    336	    150
```

## 走らせるところまで

`[runner.<triple>]` を宣言してあるため、`dowel test` がそのまま qemu を起動する。

```
[runner.thumbv7em-none-eabihf]
command = "qemu-system-arm"
args    = ["-M", "mps2-an386", "-nographic", "-semihosting", "-kernel"]
```

成果物の道は実装が末尾に付ける（ADR-0008）。したがって `-kernel` を args の
最後に置けば `qemu-system-arm ... -kernel <artifact>` になる。

```console
$ dowel test --target=thumbv7em-none-eabihf --nocapture
blink: ok
test blink:onhw ... ok (55ms)

test result: ok. 1 passed; 0 failed
```

`tests/onhw.c` は**実機の上で**走る。周辺機器の番地を叩き、`bl_delay` の回数を
数え、結果を返す。返し方は semihosting である。libc が無いため `printf` も
`exit` も使えず、`bkpt 0xAB` で監視側へ渡す。

| 命令 | 意味 |
|---|---|
| `SYS_WRITE0`（`0x04`） | 文字列を1つ、監視側の標準出力へ |
| `SYS_EXIT_EXTENDED`（`0x20`） | `{ADP_Stopped_ApplicationExit, code}` で終了。qemu の終了状態になる |

`--nocapture` を付けているのは、装置が何と言ったかを見たいためである。付けないと
通ったときの出力は握り潰され、残るのは合否だけになる。

**「組めた」では足りない。ベアメタルでは走らせて初めて、配置が正しいことも
ベクタ表が生きていることも確かめられる。** 実際、F-025 の実害はここに出る
（下記）。

## 対象を増やす

RISC-V などを足すときに変わるのは3つだけである。

1. `dowel.toml` に `[toolchain.<triple>]` を1つ足す
2. `ld/<triple>.ld` を置く
3. cpu と ABI の指定を `match cfg.target` の腕にする

走らせる側も `[runner.<triple>]` を1つ足すだけである（`qemu-system-riscv32` は
`-M virt` を取る）。ソースは触らない。`bl_gpio_*` も `bl_delay` も番地と回数
しか扱わないため、対象に依存する部分はマニフェスト側に寄せてある。

## 静的にも読む

走ることと、余計なものが混ざっていないことは別である。`expect.sh` は成果物を
readelf と nm でも読む。

| 見るもの | 期待 |
|---|---|
| `readelf -d` の `NEEDED` | 0 件。共有ライブラリに依存しない |
| `nm` の `printf` / `malloc` / `__libc` | 0 件 |
| `readelf -h` の Machine | ARM |
| `readelf -h` の Flags | hard-float ABI（triple の `hf` と一致） |
| Entry point address | `nm` が言う `_reset` の番地と一致（thumb のため +1） |
| `.vectors` 節 | 残っている（誰も呼ばないが、消えると立ち上がらない） |

## 3つの関門（すべて `17bd54e` で開いた）

この木を書くことで3件を報告し、いずれも本体に修正が入った。経緯は所見に
残してある。ここには「いま何がどう書けるか」と、直る前に何が起きていたかを
記す。

### リンカスクリプト（[F-025](../../docs/10-findings.md#f-025)）

ベアメタルでは記憶の配置を省略できない。`link_flags` は `List<Str | Path>`
であり、`file()` の要素は絶対パスへ展開されるので、木の中のスクリプトを
そのまま指せる。

```
link_flags = [..., "-T", file("ld/thumbv7em-none-eabihf.ld")]
```

指せなかった頃の実害は、像の大きさでも配置の見た目でもなく**立ち上がらない
こと**に出ていた。`expect.sh` はいまも `-T` を外して確かめている。

| | 最初の LOAD | `dowel test` |
|---|---|---|
| スクリプトあり | `0x00000000`（flash の先頭） | `blink: ok` / ok (55ms) |
| スクリプトなし | `0x00008000`（何も無い番地） | `qemu: fatal: Lockup: can't escalate 3 to HardFault` |

リセット時、CPU は `0x00000000` から2語を読む。そこに何も無ければ、スタック
ポインタも入口も不定のまま実行が始まり、最初の例外で lockup する。

スクリプトが効いたときは、生イメージの先頭2語を直に読んで確かめている。

| | |
|---|---|
| `[0]` | `0x20400000` — SRAM の末尾。初期スタックポインタ |
| `[1]` | flash 内の番地 — リセットハンドラ |

### 対象の宣言（[F-026](../../docs/10-findings.md#f-026)）

この木はホスト向けではない。`dowel.toml` にそう書いてある。

```toml
[package]
targets = ["thumbv7em-none-eabihf"]
```

`--target` を付け忘れると、ホストの既定で計画が立つ前に**パッケージの側が
断る**（`unsupported-target`）。宣言が無かった頃、利用者が見るのは
`unrecognized command-line option '-mthumb'` というフラグへの苦情であり、
フラグがたまたま通る木では黙ってホストの「ファームウェア像」が出来上がった。

断っているのが `targets` であることは、宣言を外して確かめている。外すと
ホストのコンパイラの苦情に戻る。

### 実行の宣言の置き場所（[F-027](../../docs/10-findings.md#f-027)）

`[toolchain.<triple>]` は `dowel.toml`、`[runner.<triple>]` は `dowel.build`
である。組み込みの構成ではこの2つを続けて書くため、片方の隣にもう片方を
書くのは自然な間違いである。

いまは `dowel.toml` の未知の最上位テーブルが `unknown-table` で拒まれる。
直る前は**診断が1件も出ずに無視され**、そのうえで `dowel test` が「宣言が
無い」と言って書けと勧めてきた。利用者は自分の `dowel.toml` を見て、書いて
あることを確かめ、途方に暮れることになる。

## 何を dowel に効かせているか

| | |
|---|---|
| freestanding のフラグ | 成果物から libc の不在を読む |
| triple との整合 | `hf` の triple に hard-float ABI の成果物が対応すること |
| 節の配置 | `__attribute__((section(".vectors")))` が残ること |
| `artifacts` | `.bin` と `.hex`。作るのはクロスの objcopy |
| 道具の選択 | `c` / `ar` / `objcopy` を triple ごとに |
| `runner` | 組んだ像が実機（qemu）の上で本当に走ること |
| 増分 | 周辺機器のソースを触って、像が作り直され、隣が組み直されないこと |

## 設定を束ねる（[ADR-0035](https://github.com/sabas0ba/dowel/blob/main/docs/adr/0035-template-kind.md)）

機械の旗はこの木の3つの目標すべてに要る。

```
-mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16
-ffreestanding -fno-builtin -nostdinc
```

以前は3か所へ書き写していた。同じ値でなければ呼び出し規約の違うものが混ざる
のに、揃っていることを確かめる手立ては無かった。`template` がそれを1か所に
する。

```toml
[template.cortex_m4f]

[template.cortex_m4f.private]
flags = ["-mcpu=cortex-m4", …]

[lib.bl]
use     = [template("cortex_m4f")]
sources = [...]
```

雛形は**目標ではない**。`sources` も `linkage` も書けず、成果物も出さず、
グラフにも現れない。設定だけを持つ。

展開は「元の塊へ」入る——`private` は使う側の `private` に、`public` は
`public` になる。ソースを持たないライブラリでは代われない理由がここにある。
`public` だけが伝播するので、依存を通して設定を配ると下流すべてへ公開する
ことになってしまう。

置く値は目標自身の値の**前**に来る。`append` は順序を保ち、`replace` は目標が
勝つ。検査は、束ねた宣言ではなく**出てきた引数**が3つの目標で一致することを
見ている——束ねたことと効いていることは別である。

リンクの側は別の雛形にしてある。書庫を作るだけの `lib.bl` には要らない。
束ねるとは「同じものを配る」ことであって「全部に配る」ことではない。

### 関門: `check` が落ちる（[F-058](../../docs/10-findings.md#f-058)、[#141](https://github.com/sabas0ba/dowel/issues/141)）

雛形を宣言すると、そのパッケージは `dowel check` を通らない。

```console
$ dowel check
error[not-a-target]: `blink:cortex_m4f` is a template, not something to build
   = note: build a target that uses it, as in `use = [template("...")]`
```

何も名指ししていない。文書は「**名指ししたとき**が `not-a-target`」と書いて
おり、`build` と `test` は正しく通る。助言に従っても直らない——木は既に
`use = [template("...")]` と書いてある。

検査は `build` と `test` が通ることを対照に置いてあるので、壊れているのが
機構ではなく `check` の目標の数え方であることが読める。