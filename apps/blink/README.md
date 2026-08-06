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

## 3つの関門

### リンカスクリプトを指せない（[F-025](../../docs/10-findings.md#f-025)）

`ld/thumbv7em-none-eabihf.ld` は木の中に置いてあるが、マニフェストから指す
方法が無い。

```
link_flags = ["-T", "ld/....ld"]      → cannot open linker script file
link_flags = ["-Wl,-T,ld/....ld"]     → 同じ
link_flags = ["-Lld", "-T....ld"]     → 同じ（-L も同じ基準で解決される）
link_flags = [file("ld/....ld")]      → type-mismatch（List<Str> である）
```

絶対パスなら通り、配置も効く。**足りないのは道の書き方だけ**である。

実害は像の大きさでも配置の見た目でもなく、**立ち上がらないこと**に出る。

| | 最初の LOAD | `dowel test` |
|---|---|---|
| スクリプトあり | `0x00000000`（flash の先頭） | `blink: ok` / ok (55ms) |
| スクリプトなし | `0x00008000`（何も無い番地） | `qemu: fatal: Lockup: can't escalate 3 to HardFault` |

リセット時、CPU は `0x00000000` から2語を読む。そこに何も無ければ、スタック
ポインタも入口も不定のまま実行が始まり、最初の例外で lockup する。書き込み器に
食わせる前の段階で、像は既に起動しない。

スクリプトが効いたときは、生イメージの先頭2語を直に読んで確かめている。

| | |
|---|---|
| `[0]` | `0x20400000` — SRAM の末尾。初期スタックポインタ |
| `[1]` | flash 内の番地 — リセットハンドラ |

### 対象の triple を宣言できない（[F-026](../../docs/10-findings.md#f-026)）

`--target` を付け忘れても、ホストには既定があるため計画が立つ。

```console
$ dowel build                      # --target を忘れた
cc: error: unrecognized command-line option '-mthumb'

$ dowel build --message-format=json | jq -r '.code'
                                   # 何も出ない
```

落ちること自体は良いが、**利用者が見るのはフラグについての苦情**である。
「この木はホスト向けではない」とはどこにも書かれておらず、`--target` の
付け忘れだと気づく手がかりが無い。

フラグがたまたまホストのコンパイラにも通る木（対象が
`aarch64-unknown-linux-gnu` など）では、**黙って x86-64 の「ファームウェア像」が
出来上がる**。書き込み器に食わせるつもりのファイルが、ホストの objcopy が
作った別物になる。どちらの形も dowel は何も言わない。

`expect.sh` は前者を通常の検査として記録し、パッケージが対象を宣言できることを
`xfail` として置いてある。

### 実行の宣言を置き違える（[F-027](../../docs/10-findings.md#f-027)）

`[toolchain.<triple>]` は `dowel.toml`、`[runner.<triple>]` は `dowel.build` で
ある。組み込みの構成ではこの2つを続けて書く。同じ triple を鍵に持ち名前も対に
なっているため、片方の隣にもう片方を書くのは自然な間違いである。

そう書くと、**診断が1件も出ずに無視される**。そのうえで `dowel test` が
「宣言が無い」と言い、書けと勧める。

```console
$ dowel check --target=thumbv7em-none-eabihf
check passed                       # [runner] は dowel.toml にある

$ dowel test --target=thumbv7em-none-eabihf
error[missing-runner]: no runner is declared for `thumbv7em-none-eabihf`
  = help: declare one, for example `[runner.<triple>]` with `command = "qemu-..."`
```

利用者は自分の `dowel.toml` を見て、書いてあることを確かめ、途方に暮れる。

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
