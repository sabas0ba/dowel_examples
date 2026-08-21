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

## かつての関門 1: `.exe`（[F-050](../../docs/10-findings.md#f-050)、[#112](https://github.com/sabas0ba/dowel/issues/112)、`9858932` で修正）

**組めるのに使えない**状態だった。ドライバは `bin/wt.exe` を書き、dowel は
`bin/wt` として扱っていた。ずれは4か所に出る。`built:` の印字、runner へ渡す
道（wine が `c0000135`）、`artifacts` の `objcopy`（入力が無くてビルドが落ちる）、
そして**増分**。

4つ目は検査を書いていて見つけ、[#112 に追記](https://github.com/sabas0ba/dowel/issues/112#issuecomment-5247985977)した。
宣言した出力が永久に無いので、何も触らなくてもリンクが毎回やり直される。
成功として終わる（終了状態 0、`built:` も出る）ので、手がかりは所要時間しか
なかった。リンクが重い木で初めて「Windows のビルドはなぜか遅い」として現れる。

いまは成果物の綴りが `target.os` に従う。1か所で決まるので、4つの面が同時に
消えた。

```console
$ dowel build --target=x86_64-pc-windows-gnu
built: .../bin/wt.exe          # 実在する
$ dowel test --target=x86_64-pc-windows-gnu
test winapp:unit/eol ... ok
$ for i in 1 2; do dowel build --target=x86_64-pc-windows-gnu; done
run 1: ran 0 steps    run 2: ran 0 steps
```

検査は綴りが**対象に従う**ことを見る形へ書き換えた——Windows 向けには
`.exe` が付き、手元向けには付かない。片方だけでは「たまたま合っている」と
区別がつかない。

## かつての関門 2: MSVC（[F-051](../../docs/10-findings.md#f-051)、[#113](https://github.com/sabas0ba/dowel/issues/113)、`9858932` で修正）

**名指しはできるが宣言はできない**状態だった。`cl` と `lib` を PATH に置くと
計画は立つが、出てくる引数が GNU の形（`-c` `-o` `-MD -MF`）だった。`-MD` に
至っては MSVC では**動的 CRT の指定**であり、`docs/00-overview.md` 自身が
CRT を ABI の軸として挙げている。

いまは引数の様式を宣言できる（ADR-0027）。triple からも導かれる。

```console
$ dowel graph --target=x86_64-pc-windows-msvc
cl    /Z7 /Od /nologo /showIncludes /c src/main.c /Fo:…/src_main.c.obj
link  /nologo …/src_main.c.obj /OUT:…/app.exe
```

依存の記録は `/showIncludes` になり、`link` が道具の表に入り、成果物の綴りも
`.obj` / `.exe` になった。**dowel が組み立てる引数だけ**が様式ごとに綴られ、
利用者の書いた `flags` はそのまま渡る——そこが分かれていないと、`flags` を
書く側が様式を意識することになる。

検査は偽の `cl` / `lib` / `link` を PATH に置いて計画だけを読む。
**組もうとはしない**——確かめたいのは「MSVC が使えるか」ではなく
「引数の形が族に合っているか」であり、後者は本物の MSVC が無くても読める。

## かつての関門 3: 対象の OS（[F-053](../../docs/10-findings.md#f-053)、[#115](https://github.com/sabas0ba/dowel/issues/115)、`9858932` で修正）

書きたいのは「対象が Windows なら」である。かつて語彙にあったのは組む側の OS
（`host.os`）と対象の triple そのもの（`cfg.target`）だけで、素直に書くと
**意図と逆に効いた**——Linux から Windows 向けに組むと `plat_posix.c` が
選ばれる。`plat_posix.c` が `<unistd.h>` を含んでいれば翻訳で落ちるが、
含んでいなければ**組み上がって答だけが違う**。

いまは `target.os` がある。このアプリはそれで書いてある。

```toml
match target.os {
    windows => file("src/plat_win.c"),
    _       => file("src/plat_posix.c"),
}
```

有限領域（`linux` / `macos` / `windows` / `none` / `other`）なので `match` の
網羅性が検査される。triple を数え上げる形の一番の弱点——Windows の triple が
複数あり、書き忘れが静かに `_` の腕へ落ちること——が消えた。`host.os` は
組む側を指したまま残っている。両方が要る。

`docs/99-open-questions.md` の Q1（`cfg` の語彙）は未着手と書かれていたので、
バグではなく**実際に書いてみて足りなかった語**として報告した。

## かつて回避したもの: 同名のターゲット（[F-052](../../docs/10-findings.md#f-052)、[#114](https://github.com/sabas0ba/dowel/issues/114)、`9858932` で修正）

ライブラリを `wtcore`、実行ファイルを `wt` と名乗っているのは、選んだのでは
なく避けたのである。両方を `wt` にすると、かつては `dowel check` が通って
しまい、`public` はどこへも伝播せず、同じソースを持つとオブジェクトの経路が
衝突して **ninja の言葉で**落ちた。

いまは `duplicate-target` で拒まれる。名前を割るのは回避ではなく規則になった
——名前は `target()`・ラベル・`obj/` の3か所で鍵として使われており、診断が
そう述べている。

このアプリを書いていて踏み、`projects/04-diagnostics` にフィクスチャを置いた。
最初の報告には誤りがあり（対照を取る前に出してしまった）、検査を書く段で
気づいて[訂正を出した](https://github.com/sabas0ba/dowel/issues/114#issuecomment-5248006716)。

## 何を dowel に効かせているか

| | |
|---|---|
| triple ごとの toolchain | `[toolchain.x86_64-pc-windows-gnu]` が mingw を指す |
| 対象ごとのソース | `match target.os`。可搬な側は共有される |
| runner | wine を据えて、組んだものを実際に起動する |
| 成果物の綴り | 対象で変わる（`wt` と `wt.exe`）。`target.os` から決まる |
| もう1つの族 | MSVC の引数の様式。`style` で宣言でき、triple からも導かれる |
| 対象の語彙 | 「対象が Windows なら」と書ける。`target.os` は有限領域 |
| 二つの対象の分離 | 同じ木から PE と ELF が別のディレクトリに出る |
| 増分 | 選ばれなかったソースは依存にすら入らない |
