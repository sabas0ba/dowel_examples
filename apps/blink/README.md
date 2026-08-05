# blink — 組み込み（freestanding）

libc も起動コードも持たない対象。入口はベクタ表の先の `_reset` であり、
記憶の配置はリンカスクリプトが決める。

```console
$ dowel build --target=aarch64-unknown-linux-gnu
built: .../bin/firmware
built: .../bin/firmware.bin
built: .../bin/firmware.hex
```

## なぜ aarch64 なのか

Cortex-M ではなく aarch64 の freestanding にしてある。本スイートが既に要求して
いる道具立てで足り、`gcc-arm-none-eabi` を足さずに済むためである。

dowel に効かせる性質は変わらない。

- `-ffreestanding -nostdinc -nostdlib` が届くこと
- ベクタ表が誰にも参照されないまま成果物に残ること
- 入口が libc の起動処理ではないこと
- `artifacts` が書き込み用の像を作ること
- 道具（`c` / `ar` / `objcopy`）が triple ごとに選ばれること

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

`ld/app.ld` は木の中に置いてあるが、マニフェストから指す方法が無い。

```
link_flags = ["-T", "ld/app.ld"]      → cannot open linker script file
link_flags = ["-Wl,-T,ld/app.ld"]     → 同じ
link_flags = ["-Lld", "-Tapp.ld"]     → 同じ（-L も同じ基準で解決される）
link_flags = [file("ld/app.ld")]      → type-mismatch（List<Str> である）
```

絶対パスなら通り、配置も効く（FLASH の `0x08000000` に載る）。**足りないのは
道の書き方だけ**である。`expect.sh` はそこまで確かめている。

配置を決めないことには実害がある。`objcopy -O binary` は最初と最後の節の間を
すべて埋めるため、既定の配置では像が桁違いに膨らむ。

| | 生イメージの大きさ |
|---|---|
| スクリプトあり | 数百バイト |
| スクリプトなし | 130 KB 超 |

その比を検査にしてある。

### 対象の triple を宣言できない（[F-026](../../docs/10-findings.md#f-026)）

`--target` を付け忘れると、**ホストの既定のツールチェーンで組み上がる**。
診断も警告も無い。

```console
$ dowel build                      # --target を忘れた
built: .../x86_64-unknown-linux-gnu-debug/bin/firmware
built: .../x86_64-unknown-linux-gnu-debug/bin/firmware.bin
```

x86-64 の「ファームウェア像」が出る。名前も置き場所の形も本物と同じで、違うのは
triple の接頭辞だけである。バレメタルの木にホストの構成は存在しないので、
出来上がるものに意味は無い。

`expect.sh` はこれが**起きること**を通常の検査として記録し、パッケージが対象を
宣言できることを `xfail` として置いてある。

## 何を dowel に効かせているか

| | |
|---|---|
| freestanding のフラグ | 成果物から libc の不在を読む |
| 節の配置 | `__attribute__((section(".vectors")))` が残ること |
| `artifacts` | `.bin` と `.hex`。作るのはクロスの objcopy |
| 道具の選択 | `c` / `ar` / `objcopy` を triple ごとに |
| 増分 | 周辺機器のソースを触って、像が作り直され、隣が組み直されないこと |
