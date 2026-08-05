# httpd — システムプログラミング

静的ファイルを返す HTTP サーバ。ソケット、シグナル、待ち方の選択、任意で
接続ごとのスレッド。libc の外には出ない。

```console
$ httpd -r www
listening 41879

$ curl -s localhost:41879/index.html
<!doctype html>
<title>hello</title>
<p>dowel

$ httpd --waiter
poll sequential
```

## 実装の差し替えをソースの一覧で行う

待ち方は2つある。`poll`（どこでも動く）と `epoll`（Linux 固有）。

```
[lib.hd]
sources = [
    file("src/http.c"),
    file("src/mime.c"),
    file("src/serve.c"),
    file("src/wait_epoll.c") when feature.epoll,
    file("src/wait_poll.c")  when feature.poll,
]
```

**`#ifdef` で1つのファイルに詰め込まない。** 詰め込むと、選ばれなかった側は
二度と翻訳されず、壊れても気づけない。ソースの一覧で切り替えれば、どちらの
構成でも1つの翻訳単位が丸ごと通る。

`expect.sh` はアクショングラフを読んで、選ばれた側**だけ**が翻訳されている
ことを両方向で確かめる。加えて、成果物自身に `--waiter` で名乗らせる。
引数の形だけでは、翻訳された側が実際にリンクされたかは分からない。

## 機能フラグはリンクの要求も動かす

```
[bin.httpd.private]
link_flags = ["-pthread"] when feature.threads
```

スレッドを使う版だけが `-pthread` を要る。要らない版に付けると、使っていない
依存が成果物に残る。

## 実際に繋がるところまで見る

組めたことは、繋がることを意味しない。`expect.sh` は本物のソケットで
取りに行く。

| 要求 | 期待 |
|---|---|
| `GET /index.html` | 200、`Content-Type: text/html`、中身が一致 |
| `GET /nope.html` | 404 |
| `GET /../dowel.toml` | 403（経路の外へ出さない） |

最後の1つは、静的ファイルを返すプログラムとして最低限の性質である。
`epoll` の版でも同じ答が返ることを見て、差し替えたのが待ち方だけであることを
確かめる。

ポート番号は 0 で束ねて、実際に取れた番号をサーバ自身に出させる。固定の番号を
使うと、同時に走った別の実行と衝突する。

## 何を dowel に効かせているか

| | |
|---|---|
| 条件つきのソース | `file(...) when feature.x`。選ばれなかった翻訳単位が落ちること |
| 条件つきのリンク要求 | `link_flags ... when feature.threads` |
| 構成が成果物に届くこと | `--waiter` が名乗る値が構成ごとに変わる |
| 公開と非公開 | `src/` は `lib` の private、`include/hd/` だけが公開 |
| 増分 | 待ち方を触って、無関係な翻訳単位が組み直されないこと |

## 見つけたもの

無し。この層は素直に通った。

条件つきのソースと条件つきの `link_flags` は、`projects/03-features` が
最小の形で見ているものと同じ機構である。実アプリの大きさにしても、形は
変わらなかった。
