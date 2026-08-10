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

待ち方は択一なので、`dowel.toml` にそう宣言してある。

```toml
[features]
exclusive = [["epoll", "poll"]]
```

`--features=epoll` と打って既定の `poll` を落とし忘れると、
`conflicting-features` で拒まれる。宣言する場所が無かった頃、両方立った木は
ここが `lib` であるために**組み上がってしまい**、リンカが先に届いた側だけを
引いた。テストも通り、成果物だけが頼んだのと違うものになる
（[F-031](../../docs/10-findings.md#f-031)）。

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
| 計装の構成 | 翻訳とリンクの両方に、しかもライブラリ側にも乗せられること |

## 落ちないことも見る

サーバは要求を選べない。網の向こうから来るものは、切り詰められていたり、
終端が無かったり、そもそも HTTP ですらなかったりする。正しい要求に正しく
答えることは、実アプリの条件としては半分でしかない。

`sanitize` という機能を宣言し、計装した版を組んで実際に接続する。

```
flags      = ["-fsanitize=address,undefined" when feature.sanitize, ...]
link_flags = ["-fsanitize=address,undefined" when feature.sanitize]
```

送るのは 16 通り。CRLF の無い要求、空の要求、8k の要求行、64k の道、
メソッドの無い要求、1k の乱数バイト、道の中の NUL、2000 段の `../`、
1000 個の見出し、70k のメソッド名、ASCII でない道、繋いですぐ切る、など。

サーバは 1 接続で終える（`-1`）ため、**抜けたあとに計装が漏れも数える**。
終了状態が 0 でなければ、そこで何かを踏んでいる。待ち方を差し替えた側でも
同じものを送る。要求の読み方は共有しているが、それは確かめて初めて言える。

## 見つけたもの

[F-031](../../docs/10-findings.md#f-031) の `lib` の側——両方の待ち方が
立った書庫は黙って組み上がり、リンカが先に届いた側だけを引く——をこの木で
踏んだ（`bin` の側は [plot](../plot/) が踏んだ）。`17bd54e` の `exclusive`
で開き、上の宣言がその答である。

条件つきのソースと条件つきの `link_flags` そのものは、`projects/03-features`
が最小の形で見ているものと同じ機構である。実アプリの大きさにしても、形は
変わらなかった。計装の構成も同じで、`when feature.sanitize` を並べるだけで
書けている。
