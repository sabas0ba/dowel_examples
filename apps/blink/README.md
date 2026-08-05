# blink — 組み込み（freestanding）

libc も起動コードも持たない対象。入口はベクタ表の先の `_reset` であり、
記憶の配置はリンカスクリプトが決める。

```console
$ dowel build --target=thumbv7em-none-eabihf
built: .../bin/firmware
built: .../bin/firmware.bin
built: .../bin/firmware.hex

$ arm-none-eabi-size .../bin/firmware
   text	   data	    bss	    dec	    hex
    320	      0	     16	    336	    150
```

対象は **Cortex-M4F**（`thumbv7em-none-eabihf`）。OS を持たない triple であり、
ツールチェーンは `arm-none-eabi-*` である。

## 対象を増やす

RISC-V などを足すときに変わるのは3つだけである。

1. `dowel.toml` に `[toolchain.<triple>]` を1つ足す
2. `ld/<triple>.ld` を置く
3. cpu と ABI の指定を `match cfg.target` の腕にする

ソースは触らない。`bl_gpio_*` も `bl_delay` も番地と回数しか扱わないため、
対象に依存する部分はマニフェスト側に寄せてある。

## 「組めた」では足りない

freestanding は、組めたかどうかではなく**何が混ざらなかったか**で判定する。
`expect.sh` は成果物を readelf と nm で読む。

| 見るもの | 期待 |
|---|---|
| `readelf -d` の `NEEDED` | 0 件。共有ライブラリに依存しない |
| `nm` の `printf` / `malloc` / `__libc` | 0 件 |
| `readelf -h` の Machine | AArch64 |
| Entry point address | `nm` が言う `_reset` の番地と一致 |
| `.vectors` 節 | 残っている（誰も呼ばないが、消えると立ち上がらない） |

## 2つの関門

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
`expect.sh` はそこまで確かめている。

配置を決めないことの実害は、大きさではなく**番地**に出る。

| | 最初の LOAD |
|---|---|
| スクリプトあり | `0x08000000`（この部品の flash の先頭） |
| スクリプトなし | `0x00008000`（既定のスクリプトが選ぶ番地。flash は無い） |

書き込み器はこの像を flash へ置けない。ベクタ表も flash の先頭に来ないため、
リセット時に読まれる2語が正しくない。

スクリプトが効いたときは、生イメージの先頭2語を直に読んで確かめている。

| | |
|---|---|
| `[0]` | `0x20010000` — SRAM の末尾。初期スタックポインタ |
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

## 何を dowel に効かせているか

| | |
|---|---|
| freestanding のフラグ | 成果物から libc の不在を読む |
| triple との整合 | `hf` の triple に hard-float ABI の成果物が対応すること |
| 節の配置 | `__attribute__((section(".vectors")))` が残ること |
| `artifacts` | `.bin` と `.hex`。作るのはクロスの objcopy |
| 道具の選択 | `c` / `ar` / `objcopy` を triple ごとに |
| 増分 | 周辺機器のソースを触って、像が作り直され、隣が組み直されないこと |
