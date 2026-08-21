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
#   - **壊れた要求で落ちないこと**。計装した版を組んで実際に食わせる（7節）

# ------------------------------------------------------------ 下ごしらえ

# built <構成の一部> — その構成の httpd。
built() { find .dowel/build -type f -path "*$1/bin/httpd" 2>/dev/null | head -1; }

# waiter <構成の一部> — 成果物自身が名乗る待ち方と並行の形。
waiter() { local b; b=$(built "$1"); [ -n "$b" ] && "$b" --waiter; }

# link_args [dowel args...] — httpd のリンク引数。
link_args() {
    "$DOWEL" graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r '.steps[] | select(.kind == "link" and .target == "httpd:httpd")
               | ([.program] + .arguments) | join(" ")'
}

# sources_of [dowel args...] — 翻訳された src のファイル名。
sources_of() {
    "$DOWEL" graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r '.steps[] | select(.kind == "cc") | ([.program] + .arguments)[]' |
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

# 既定を落とし忘れると、両方が立つ。機能は加算であり、`--features=epoll`
# だけでは `default = ["poll"]` は消えない。
#
# 待ち方は択一なので `exclusive` に宣言してある。宣言が無かった頃、ここは
# `lib` なので**組み上がってしまった**——両方の翻訳単位が同じ archive に入り、
# リンカが片方だけを引く。テストも通り、成果物だけが頼んだのと違うものに
# なる。`bin` に直に並べた場合（apps/plot）は multiple definition で落ちる
# ので、同じ誤りが目標の種別によって「落ちる」と「黙って選ばれる」に
# 分かれていた。F-031 / #82 として報告し、`exclusive` が入った。

_last_cmd="grep exclusive dowel.toml"
OUT=$(grep -n 'exclusive' dowel.toml)
RC=0
[ -n "$OUT" ]
fact $? "a package can declare that its two waiters are exclusive"

diag conflicting-features \
    "and a package that would end up with two implementations of one interface says so" \
    check --features=epoll

fails "the build does not proceed to pick one silently" build --no-compdb --features=epoll

run check --features=epoll
said=$OUT
_last_cmd="dowel check --features=epoll"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'comes from `default`'
fact $? "naming default as the source, which is what --no-default-features drops"

# 成果物自身に名乗らせる。引数の形だけでは、翻訳された側が実際にリンク
# されたかどうかは分からない。
ok "the epoll configuration builds" build --no-compdb --no-default-features --features=epoll

got=$(waiter '-debug-httpd--poll')
[ "$got" = "poll sequential" ]
v=$?; RC=0; _last_cmd="httpd --waiter"; OUT="said: ${got:-(nothing)}"
fact $v "the default artifact says it is the portable waiter"

got=$(waiter '-debug-httpd--epoll')
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
got=$(waiter '-debug-httpd--poll+httpd--threads')
[ "$got" = "poll threaded" ]
v=$?; RC=0; _last_cmd="httpd --waiter  # --features=threads"
OUT="said: ${got:-(nothing)}"
fact $v "and its artifact says it is threaded"

# ------------------------------------------------------------ 4. 実際に繋がる
#
# 組めたことは、繋がることを意味しない。本物のソケットで取りに行く。

ok "the default configuration builds" build --no-compdb

serve_once '-debug-httpd--poll' $'GET /index.html HTTP/1.0\r\n\r\n'
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

serve_once '-debug-httpd--poll' $'GET /nope.html HTTP/1.0\r\n\r\n'
_last_cmd="GET /nope.html"; OUT="$SAID"; RC=0
printf '%s' "$SAID" | grep -q '^HTTP/1.1 404'
fact $? "a request for a file that does not exist is answered with 404"

# 経路の外へ出ようとする要求。実アプリとして最低限の性質である。
serve_once '-debug-httpd--poll' $'GET /../dowel.toml HTTP/1.0\r\n\r\n'
_last_cmd="GET /../dowel.toml"; OUT="$SAID"; RC=0
printf '%s' "$SAID" | grep -q '^HTTP/1.1 403'
fact $? "a path that climbs out of the root is refused"

# 別の実装でも同じ答である。差し替えたのは待ち方だけであり、
# 振る舞いは変わってはならない。
serve_once '-debug-httpd--epoll' $'GET /index.html HTTP/1.0\r\n\r\n'
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

# ------------------------------------------------------------ 7. 壊れた要求で落ちないこと
#
# サーバは要求を選べない。網の向こうから来るものは、切り詰められていたり、
# 終端が無かったり、そもそも HTTP ですらなかったりする。正しい要求に正しく
# 答えることは、実アプリの条件としては半分でしかない。
#
# ここで見るのは2つある。
#
#   1. **アプリ側** — 壊れた要求で落ちないか、未定義動作を踏まないか、
#      接続ごとに漏らしていないか（計装は終了時に漏れも数える）
#   2. **dowel 側** — 計装のような「翻訳とリンクの両方に乗せる必要があり、
#      かつライブラリ側にも同じものを乗せないと意味が無い」フラグを、
#      マニフェストの語彙だけで書き切れるか

ok "the instrumented configuration passes check" check --features=sanitize
ok "and builds"                                  build --no-compdb --features=sanitize

# 計装は翻訳だけでは効かない。ライブラリの private な link_flags が、
# それを使う側のリンクにも乗ること（F-018 で入った性質）を実地で使う。
_last_cmd="graph --features=sanitize | select(.kind==\"link\")"
OUT=$(link_args --features=sanitize)
RC=0
printf '%s' "$OUT" | grep -q 'fsanitize'
fact $? "the instrumentation the library asks for reaches the link of the server"

ok "the unit tests pass with the instrumentation on" test --features=sanitize

# 壊れた要求を実際に送る。サーバは 1 接続で終える（-1）ため、抜けたあとに
# 計装が漏れを数える。終了状態が 0 でなければ、そこで何かを踏んでいる。
survives() {
    local bin; bin=$(built "$1")
    HTTPD="${bin:-/nonexistent}" python3 - <<'PY' 2>&1
import os, re, socket, subprocess, sys, time

bin = os.path.abspath(os.environ["HTTPD"])
cases = {
    "a request with no CRLF":       b"GET /index.html HTTP/1.0",
    "an empty request":             b"",
    "bare CRLFs":                   b"\r\n\r\n",
    "an 8k request line":           b"GET /" + b"a" * 8192 + b" HTTP/1.0\r\n\r\n",
    "a 64k path":                   b"GET /" + b"b" * 65536 + b" HTTP/1.0\r\n\r\n",
    "a request with no method":     b"/index.html HTTP/1.0\r\n\r\n",
    "1k of binary garbage":         bytes(range(256)) * 4,
    "a NUL inside the path":        b"GET /ind\x00ex.html HTTP/1.0\r\n\r\n",
    "2000 dot-dot segments":        b"GET /" + b"../" * 2000 + b"etc/passwd HTTP/1.0\r\n\r\n",
    "1000 headers":                 b"GET /index.html HTTP/1.0\r\n" + b"X-h: v\r\n" * 1000 + b"\r\n",
    "a lone CR":                    b"GET /index.html HTTP/1.0\r",
    "spaces only":                  b"   \r\n\r\n",
    "a 70k method":                 b"X" * 70000 + b" / HTTP/1.0\r\n\r\n",
    "percent-encoded dot-dots":     b"GET /%2e%2e%2f%2e%2e%2fdowel.toml HTTP/1.0\r\n\r\n",
    "a path that is not ASCII":     "GET /éè中.html HTTP/1.0\r\n\r\n".encode(),
    "a connection closed at once":  None,
}

bad = []
for name, req in cases.items():
    log = open(".fuzz.log", "wb+")
    p = subprocess.Popen([bin, "-r", "www", "-1"], stdout=log, stderr=subprocess.STDOUT)
    port = None
    for _ in range(60):
        log.seek(0)
        m = re.search(rb"^listening (\d+)", log.read(), re.M)
        if m:
            port = int(m.group(1))
            break
        time.sleep(0.1)
    if port is None:
        p.kill()
        bad.append("%s: the server never announced a port" % name)
        continue
    try:
        s = socket.create_connection(("127.0.0.1", port), timeout=5)
        if req is None:
            s.close()
        else:
            s.sendall(req)
            s.shutdown(socket.SHUT_WR)
            s.settimeout(5)
            try:
                while s.recv(65536):
                    pass
            except socket.timeout:
                pass
            s.close()
    except OSError:
        pass                                    # 拒まれること自体は落ちていない
    try:
        rc = p.wait(timeout=15)
    except subprocess.TimeoutExpired:
        p.kill()
        bad.append("%s: the server never came back" % name)
        continue
    log.seek(0)
    out = log.read()
    why = []
    if rc < 0:
        why.append("killed by signal %d" % -rc)
    elif rc != 0:
        why.append("exit %d" % rc)
    if b"runtime error" in out or b"Sanitizer" in out:
        why.append(out.decode("utf-8", "replace").strip().splitlines()[0])
    if why:
        bad.append("%s: %s" % (name, "; ".join(why)))

print("\n".join(bad) if bad else "%d requests, the server survived them all" % len(cases))
PY
}

report=$(survives '-debug-httpd--poll+httpd--sanitize')
printf '%s' "$report" | grep -q 'survived them all'
v=$?
RC=0; _last_cmd="send 16 malformed requests to the instrumented server"
OUT="$report"
fact $v "a malformed request is answered or refused, never crashes the server"

# 待ち方を差し替えた側でも同じである。差し替えたのは待ち方だけであり、
# 要求の読み方は共有している——が、それは確かめて初めて言える。
ok "the epoll configuration builds instrumented too" \
    build --no-compdb --no-default-features --features=epoll,sanitize

report=$(survives '-debug-httpd--epoll+httpd--sanitize')
printf '%s' "$report" | grep -q 'survived them all'
v=$?
RC=0; _last_cmd="the same 16 requests against the epoll build"
OUT="$report"
fact $v "and the other waiter survives the same requests"

rm -f .fuzz.log
