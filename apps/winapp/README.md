# winapp — Windows

ここまでのクロスは、対象が違っても**同じ族のコンパイラ**だった（gcc と、その
aarch64 版、arm-none-eabi 版）。Windows は違う軸を持ち込む。実行ファイルの
綴りが変わり（`.exe`）、行末が変わり（CRLF）、経路の区切りが変わり（`\`）、
そして族がもう1つある（MSVC）。

```
app/   1つのパッケージで手元と Windows の両方へ組む。可搬な規則は共有し、
       答だけを構成ごとに差し替える
```

```console
$ dowel -C app build && ./wt
eol=lf sep=/ page=4096

$ dowel -C app build --target=x86_64-pc-windows-gnu
$ wine wt.exe
eol=crlf sep=\ page=4096
$ wine wt.exe base 'C:\a/b.txt'
b.txt
```

## 1枚の見出しの裏で差し替える

```
src/text.c        可搬。行末や区切りを「どう使うか」の規則はここ
src/plat_win.c    Windows の答（<windows.h> を含む）
src/plat_posix.c  POSIX の答（<unistd.h> を含む）
```

可搬な側は共有され、対象ごとに翻訳し直されるのは選ばれた1つだけである。
`#ifdef` で1つのファイルに詰め込むと、選ばれなかった側は二度と翻訳されず、
壊れても気づけない——`apps/plot` と同じ理由で `match` を使っている。

`wt info` が `page=` を出しているのは、**本当に Win32 を呼んでいる証**が
欲しいからである。行末と区切りだけなら定数を返す実装でも通せるが、
`GetSystemInfo` の答は可搬な代わりでは出せない。

## 走らせるところまで

wine を runner に据えれば、Windows 向けの成果物も表示の無い機械で起動できる
——`apps/blink` が qemu を相手にするのと同じ形である。確かめているのは:

| 見ること | 期待 |
|---|---|
| 行末 | CRLF を返す。裸の LF が `\r\n` に直る。既に CRLF なら二重にしない |
| 区切り | `\` を返す。`C:\a/b.txt` を **`/` でも割る**（Windows がそう扱う） |
| Win32 | `GetSystemInfo` の値が返る |

`file` で成果物を確かめると、Windows 側は PE、手元側は ELF である。同じ
ソースから、対象だけ変えて。

## 関門 1: `.exe`（[F-050](../../docs/10-findings.md#f-050)、[#112](https://github.com/sabas0ba/dowel/issues/112)）

**組めるのに使えない。** ドライバは `bin/wt.exe` を書き、dowel は `bin/wt` と
して扱う。

```console
$ dowel build --target=x86_64-pc-windows-gnu
built: .../bin/wt          # 存在しない
$ ls .../bin/
wt.exe
```

ずれは4か所に出る。`built:` の印字、runner へ渡す道（wine が `c0000135`）、
`artifacts` の `objcopy`（入力が無くてビルドが落ちる）、そして**増分**。

増分の面は検査を書いていて見つけ、[#112 に追記](https://github.com/sabas0ba/dowel/issues/112#issuecomment-5247985977)した。
宣言した出力が永久に無いので、何も触らなくてもリンクが毎回やり直される。

```console
$ for i in 1 2 3; do dowel build --target=x86_64-pc-windows-gnu; done
run 1: ran 2 steps    run 2: ran 2 steps    run 3: ran 2 steps
$ #  同じ木を手元へ: ran 0 steps に収束する
```

成功として終わる（終了状態 0、`built:` も出る）ので、手がかりは所要時間しか
ない。リンクが重い木で初めて「Windows のビルドはなぜか遅い」として現れる。

このアプリは、**組めること自体は通常の検査**として置き、手で wine に渡せば
正しく動くことも通常の検査として置いてある。壊れているのが成果物ではなく
名前であることが、検査の並びから読める形にしてある。

## 関門 2: MSVC（[F-051](../../docs/10-findings.md#f-051)、[#113](https://github.com/sabas0ba/dowel/issues/113)）

**名指しはできるが宣言はできない。** `cl` と `lib` を PATH に置くと計画は
立つ。出てくる引数が GNU の形である。

```console
$ dowel graph --target=x86_64-pc-windows-msvc
cl   -g -O0 -MD -MF …/x.o.d -c src/main.c -o …/x.o
lib  rcs …/lib/libapp.a …/x.o
cl   …/x.o …/lib/libapp.a -o …/bin/app
```

`-c` `-o` は `cl` の綴りではない。`-MD` に至っては MSVC では**動的 CRT の
指定**であり、`docs/00-overview.md` 自身が CRT を ABI の軸として挙げている。
書庫の綴りも `<名前>.lib` であるべきところが `lib<名前>.a` で、ツール表に
`link` が無いのでリンクを別の実行ファイルに割り当てることもできない。

検査は偽の `cl` を PATH に置いて計画だけを読む。**組もうとはしない**——
確かめたいのは「MSVC が使えるか」ではなく「引数の形が族に合っているか」で
あり、後者は本物の MSVC が無くても読める。

## 関門 3: 対象の OS（[F-053](../../docs/10-findings.md#f-053)、[#115](https://github.com/sabas0ba/dowel/issues/115)）

書きたいのは「対象が Windows なら」である。語彙にあるのは組む側の OS
（`host.os`）と、対象の三つ組そのもの（`cfg.target`）だけである。

素直に書くと、**意図と逆に効く**。

```toml
match host.os { windows => file("src/plat_win.c"), _ => file("src/plat_posix.c") }
```

Linux から `--target=x86_64-pc-windows-gnu` で組むと `plat_posix.c` が選ばれる。
`--target` にも `match` にも windows と書いてあるのに。`plat_posix.c` が
`<unistd.h>` を含んでいれば翻訳で落ちるが、含んでいなければ**組み上がって
答だけが違う**。

正しい綴りは三つ組の数え上げになる。Windows の三つ組は複数あり、「Windows の
どれか」と言う手段は無い。`_` が既定なので、書き忘れた三つ組は静かに POSIX
側へ落ちる。`cfg.target` は開いた領域なので網羅性の検査も掛からない。

`docs/99-open-questions.md` の Q1（`cfg` の語彙）は未着手と書かれているので、
バグではなく**実際に書いてみて足りなかった語**として報告した。

## 回避したもの: 同名のターゲット（[F-052](../../docs/10-findings.md#f-052)、[#114](https://github.com/sabas0ba/dowel/issues/114)）

ライブラリを `wtcore`、実行ファイルを `wt` と名乗っているのは、選んだので
はなく避けたのである。両方を `wt` にすると `dowel check` は通り、`public` は
どこへも伝播せず、同じソースを持つとオブジェクトの経路が衝突して **ninja の
言葉で**落ちる。

このアプリを書いていて踏み、`projects/04-diagnostics` にフィクスチャを置いた。
最初の報告には誤りがあり（対照を取る前に出してしまった）、検査を書く段で
気づいて[訂正を出した](https://github.com/sabas0ba/dowel/issues/114#issuecomment-5248006716)。

## 何を dowel に効かせているか

| | |
|---|---|
| 三つ組ごとの道具立て | `[toolchain.x86_64-pc-windows-gnu]` が mingw を指す |
| 対象ごとのソース | `match cfg.target`。可搬な側は共有される |
| runner | wine を据えて、組んだものを実際に起動する |
| 成果物の綴り | 対象で変わる（`wt` と `wt.exe`）。ここが F-050 |
| もう1つの族 | MSVC の引数の形。ここが F-051 |
| 対象の語彙 | 「対象が Windows なら」と書けるか。ここが F-053 |
| 二つの対象の分離 | 同じ木から PE と ELF が別のディレクトリに出る |
| 増分 | 選ばれなかったソースは依存にすら入らない |
