# 21-debug — 宣言されたデバッガを、宣言されたスタブ越しに起こす

`dowel debug <target>` は組んでから、成果物に対してデバッガを起こす
（[ADR-0024](https://github.com/sabas0ba/dowel/blob/main/docs/adr/0024-debug-command.md)）。
ビルド系は成果物を作った動作の入力を全て知っているので、デバッガの構成を
人に書かせて同期を頼むのではなく、**生成できる**——それがこの機能の設計の
言い分である。

```console
$ dowel debug app                    # 組んで、gdb で開く
$ dowel debug app --dap              # 起動構成を書き出すだけ。何も起こさない
$ dowel test --debug-failed          # 前回落ちた事例を、その宣言のまま開く
```

デバッガは道具の表の1行である（`debug`、既定 `gdb`）。クロスはトリプルが
自分のデバッガを名乗り、runner が「保持する側」と「繋ぐ側」を宣言する。

```toml
[toolchain.aarch64-unknown-linux-gnu]
c     = "aarch64-linux-gnu-gcc"
debug = "gdb-multiarch"
```
```toml
[runner.aarch64-unknown-linux-gnu]
command       = "qemu-aarch64-static"
args          = ["-L", "/usr/aarch64-linux-gnu"]
debug_args    = ["-g", "17233"]         # これで runner がスタブになる
debug_connect = "localhost:17233"       # ここへデバッガが繋ぐ
```

## 対話する道具を、対話せずに確かめる

デバッガは対話的であり、そのままでは検査にならない。2段に分ける。

1. **起動の形。** argv を記録して即座に終わる偽のデバッガを PATH に置き、
   dowel が何をどの引数で起こしたかを記録から読む（`18-tools` と同じ手口）
2. **本物の接続。** gdb に標準入力から命令を流し、ブレークポイントが
   実際に効いて `Breakpoint 1, add (a=2, b=2)` と止まること、止まった
   プログラムの式（`print a + b` → `= 4`）が評価できることまで見る

クロスも同じ2段で、qemu-user のスタブ越しに aarch64 の像を止める。
スタブが残らないこと（繋ぐ側が終われば保持する側も終わる）も見る。

## --dap は同じ事実を書き出す

`--dap` は起動する代わりに、同じ解決結果を DAP の起動構成として stdout へ
書く。**エディタで開く構成と実起動が同じ値から出る**ため、2経路が
食い違わない。検査は `.program` / `.cwd` / `.miDebuggerPath` /
`.miDebuggerServerAddress` / `.debugServerArgs` が宣言と一致することを見る。

## 落ちた事例を開き直す

`--debug-failed` は失敗の記録から事例を選び、その宣言——引数・環境変数・
作業ディレクトリ——を**そのまま**起動構成にする。手で書き写すものは無い。

- ちょうど1件でなければ開かない。複数なら並べて名指しを求める
- 何も落ちていなければ成功としてそう述べる
- ハーネスが発見した事例も `run` の引数ごと開ける

## 見つけたもの

| | |
|---|---|
| [F-046](../../docs/10-findings.md#f-046) | `debug_args` の挿し込み位置が `-kernel` で終わる runner を壊す（apps/blink に検査がある） |
| [F-048](../../docs/10-findings.md#f-048) | 半分だけ宣言したスタブに「宣言が無い」と言う |
| [F-049](../../docs/10-findings.md#f-049) | 落ちていない事例をデバッガの下で開けない |

F-046 が重い。qemu-user では偶然通る挿し込み位置が、qemu-system の
`-kernel`（成果物を取るフラグを args の末尾に置く——ADR-0008 が勧める形）で
壊れる。組み込みのデバッグという、この機能の眼目の半分が現状は宣言できない。
