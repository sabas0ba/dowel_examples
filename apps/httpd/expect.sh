# apps/httpd — システムプログラミング
#
# 静的ファイルを返す HTTP サーバ。libc 以外に依存しない。ソケット、
# シグナル、待ち方（poll / epoll）、任意でスレッド。
#
# 実アプリとして意味を持たせているもの。
#
#   - **実装の差し替えをソースの一覧で行う。** 選ばれなかった側の翻訳単位は
#     ソースから落ちる。`#ifdef` で1つのファイルに詰め込むと、落ちた側は
#     二度と翻訳されず、壊れても気づけない
#   - 機能フラグがリンクの要求まで動かす（`threads` のときだけ -pthread）
#   - 実際に接続して応答を読む。組めたことは、繋がることを意味しない

# ------------------------------------------------------------ 道具立て

# built <構成の一部> — その構成の httpd。
built() { find .dowel/build -type f -path "*$1/bin/httpd" 2>/dev/null | head -1; }

# waiter <構成の一部> — 成果物自身が名乗る待ち方と並行の形。
waiter() { local b; b=$(built "$1"); [ -n "$b" ] && "$b" --waiter; }

# link_args [dowel args...] — httpd のリンク引数。
link_args() {
    "$DOWEL" graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r '.actions[] | select(.kind == "link" and .target == "httpd:httpd")
               | .command | join(" ")'
}

# sources_of [dowel args...] — 翻訳された src のファイル名。
sources_of() {
    "$DOWEL" graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r '.actions[] | select(.kind == "cc") | .command[]' |
        grep '/src/' | sed 's|.*/||' | sort -u | paste -sd' ' -
}

# fetch <ポート> <要求> — 1つ取りに行って応答を返す。
fetch() {
    python3 - "$1" "$2" <<'PY'
import socket, sys, time
port, req = int(sys.argv[1]), sys.argv[2].encode()
try:
    s = socket.create_connection(("127.0.0.1", port), timeout=5)
    s.sendall(req)
    s.settimeout(5)
    out = b""
    while True:
        try:
            b = s.recv(65536)
        except socket.timeout:
            break
        if not b:
            break
        out += b
    sys.stdout.write(out.decode("utf-8", "replace"))
except OSError as e:
    sys.stdout.write("connect failed: %s" % e)
PY
}

# serve_once <構成の一部> <要求> — サーバを1接続ぶん起こして応答を SAID に。
SAID=""
serve_once() {
    local bin; bin=$(built "$1")
    local log=".serve.log"
    : >"$log"
    [ -n "$bin" ] || { SAID="(not built)"; return 1; }
    "$bin" -r www -1 >"$log" 2>&1 &
    local pid=$!
    local port="" i
    for i in $(seq 1 50); do
        port=$(sed -n 's/^listening //p' "$log")
        [ -n "$port" ] && break
        sleep 0.1
    done
    if [ -z "$port" ]; then
        SAID="(never announced a port)"
        kill "$pid" 2>/dev/null
        return 1
    fi
    SAID=$(fetch "$port" "$2")
    wait "$pid" 2>/dev/null
    return 0
}

# ------------------------------------------------------------ 1. 組める

ok "the package passes check" check
ok "it builds"                build --no-compdb

# libc の外には出ない。既定の構成ではリンクの追加要求も無い。
_last_cmd="graph --kind=action | select(.kind==\"link\")"
OUT=$(link_args)
RC=0
! printf '%s' "$OUT" | grep -q -- '-pthread'
fact $? "the default build asks for nothing beyond the standard library"

# ------------------------------------------------------------ 2. 実装の差し替え
#
# 待ち方は2つあり、翻訳されるのは選ばれた側だけである。選ばれなかった側が
# ソースの一覧から落ちることを、アクショングラフで確かめる。

got=$(sources_of)
_last_cmd="graph --kind=action | 翻訳された src"; OUT="$got"; RC=0
case $got in *wait_poll.c*) v=0 ;; *) v=1 ;; esac
fact $v "the default configuration compiles the portable waiter"

case $got in *wait_epoll.c*) v=1 ;; *) v=0 ;; esac
_last_cmd="graph --kind=action | 翻訳された src"; OUT="$got"; RC=0
fact $v "and does not compile the one it did not choose"

got=$(sources_of --no-default-features --features=epoll)
_last_cmd="graph ... --features=epoll"; OUT="$got"; RC=0
case $got in *wait_epoll.c*) v=0 ;; *) v=1 ;; esac
fact $v "choosing the other feature compiles the other waiter"

case $got in *wait_poll.c*) v=1 ;; *) v=0 ;; esac
_last_cmd="graph ... --features=epoll"; OUT="$got"; RC=0
fact $v "and drops the first one"

# 成果物自身に名乗らせる。引数の形だけでは、翻訳された側が実際にリンク
# されたかどうかは分からない。
ok "the epoll configuration builds" build --no-compdb --no-default-features --features=epoll

got=$(waiter '-debug-poll')
[ "$got" = "poll sequential" ]
v=$?; RC=0; _last_cmd="httpd --waiter"; OUT="said: ${got:-(nothing)}"
fact $v "the default artifact says it is the portable waiter"

got=$(waiter '-debug-epoll')
[ "$got" = "epoll sequential" ]
v=$?; RC=0; _last_cmd="httpd --waiter  # --features=epoll"; OUT="said: ${got:-(nothing)}"
fact $v "the epoll artifact says so too"

# ------------------------------------------------------------ 3. リンクの要求
#
# 機能フラグが動かすのは翻訳だけではない。スレッドを使う版は -pthread を
# 要る。要らない版に付けてしまうと、使っていない依存が成果物に残る。

_last_cmd="graph ... --features=threads | select(.kind==\"link\")"
OUT=$(link_args --features=threads)
RC=0
printf '%s' "$OUT" | grep -q -- '-pthread'
fact $? "the threaded configuration asks the linker for threads"

ok "the threaded configuration builds" build --no-compdb --features=threads
got=$(waiter '-debug-poll+threads')
[ "$got" = "poll threaded" ]
v=$?; RC=0; _last_cmd="httpd --waiter  # --features=threads"
OUT="said: ${got:-(nothing)}"
fact $v "and its artifact says it is threaded"

# ------------------------------------------------------------ 4. 実際に繋がる
#
# 組めたことは、繋がることを意味しない。本物のソケットで取りに行く。

ok "the default configuration builds" build --no-compdb

serve_once '-debug-poll' $'GET /index.html HTTP/1.0\r\n\r\n'
said=$SAID
_last_cmd="GET /index.html"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q '^HTTP/1.1 200 OK'
fact $? "a request for a file that exists is answered with 200"

_last_cmd="GET /index.html"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'Content-Type: text/html'
fact $? "the response carries the media type the path implies"

_last_cmd="GET /index.html"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'dowel'
fact $? "and the body is what the file holds"

serve_once '-debug-poll' $'GET /nope.html HTTP/1.0\r\n\r\n'
_last_cmd="GET /nope.html"; OUT="$SAID"; RC=0
printf '%s' "$SAID" | grep -q '^HTTP/1.1 404'
fact $? "a request for a file that does not exist is answered with 404"

# 経路の外へ出ようとする要求。実アプリとして最低限の性質である。
serve_once '-debug-poll' $'GET /../dowel.toml HTTP/1.0\r\n\r\n'
_last_cmd="GET /../dowel.toml"; OUT="$SAID"; RC=0
printf '%s' "$SAID" | grep -q '^HTTP/1.1 403'
fact $? "a path that climbs out of the root is refused"

# 別の実装でも同じ答である。差し替えたのは待ち方だけであり、
# 振る舞いは変わってはならない。
serve_once '-debug-epoll' $'GET /index.html HTTP/1.0\r\n\r\n'
_last_cmd="GET /index.html  # epoll build"; OUT="$SAID"; RC=0
printf '%s' "$SAID" | grep -q '^HTTP/1.1 200 OK'
fact $? "the epoll build answers the same request the same way"

# ------------------------------------------------------------ 5. テスト

ok "the unit tests pass" test
ok "and pass under the other waiter too" test --no-default-features --features=epoll

# ------------------------------------------------------------ 6. 増分

ok "a rebuild of the same configuration is a no-op" build --no-compdb
runs_actions 0 "nothing runs when nothing changed" --no-compdb

# 待ち方だけを差し替えたとき、無関係な翻訳単位まで組み直さないこと。
printf '\n/* touched */\n' >>src/wait_poll.c
build_direct --no-compdb
rebuilt "wait_poll.c" "editing the chosen waiter recompiles it"
not_rebuilt "mime.c" "and leaves the rest of the library alone"
