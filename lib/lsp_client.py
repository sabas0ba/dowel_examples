"""`dowel lsp` と話す最小のクライアント。

エディタと同じ経路で言語サーバを外から見るためだけのもので、
本体のソースは一切参照しない。枠付け（`Content-Length`）と JSON-RPC の
対応付けは本体と同じく自前に持つ。

通知は非同期に届く。ある操作の応答を待つときは、直前の操作が出した通知が
残っていると取り違える。`settle()` がその境目を作る。
"""

import json
import subprocess
import threading
import time


class Lsp:
    """1つのサーバプロセス。`with` で使うと確実に落とす。"""

    def __init__(self, exe, root, timeout=10.0):
        self.proc = subprocess.Popen(
            [exe, "lsp"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=root,
        )
        self.timeout = timeout
        self.root = root
        self._id = 0
        self._msgs = []
        self._lock = threading.Lock()
        self.stderr = []
        self.reader_error = None
        threading.Thread(target=self._read_stdout, daemon=True).start()
        threading.Thread(target=self._read_stderr, daemon=True).start()

    # ------------------------------------------------------------ 読み取り

    def _read_stderr(self):
        for line in self.proc.stderr:
            self.stderr.append(line.decode("utf-8", "replace").rstrip())

    def _read_stdout(self):
        f = self.proc.stdout
        try:
            while True:
                headers = {}
                while True:
                    line = f.readline()
                    if not line:
                        raise EOFError("stdout closed")
                    line = line.decode("ascii", "replace").strip()
                    if line == "":
                        break
                    key, _, value = line.partition(":")
                    headers[key.strip().lower()] = value.strip()
                body = f.read(int(headers["content-length"]))
                with self._lock:
                    self._msgs.append(json.loads(body.decode("utf-8")))
        except Exception as e:  # 落ちたことは status() で観測する
            self.reader_error = e

    # ------------------------------------------------------------ 書き出し

    def send_raw(self, payload):
        """枠付けを含めてそのまま流す。壊れた入力を与えるために使う。"""
        try:
            self.proc.stdin.write(payload)
            self.proc.stdin.flush()
        except BrokenPipeError:
            pass

    def send(self, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_raw(b"Content-Length: %d\r\n\r\n%s" % (len(body), body))

    def request(self, method, params):
        self._id += 1
        want = self._id
        self.send({"jsonrpc": "2.0", "id": want, "method": method, "params": params})
        return self.wait(lambda m: m.get("id") == want)

    def notify(self, method, params):
        self.send({"jsonrpc": "2.0", "method": method, "params": params})

    # ------------------------------------------------------------ 待ち合わせ

    def wait(self, pred, timeout=None):
        end = time.time() + (timeout if timeout is not None else self.timeout)
        while time.time() < end:
            with self._lock:
                for m in self._msgs:
                    if pred(m):
                        return m
            if self.proc.poll() is not None:
                return None
            time.sleep(0.01)
        return None

    def settle(self, seconds=0.2):
        """直前の操作が出した通知を受け切ってから捨てる。

        これを挟まないと、`didClose` が出す空の通知を次の `didOpen` の
        応答と取り違える。
        """
        time.sleep(seconds)
        with self._lock:
            self._msgs = []

    def published(self, uri=None):
        """これまでに届いた publishDiagnostics を古い順に返す。"""
        with self._lock:
            return [
                m["params"]
                for m in self._msgs
                if m.get("method") == "textDocument/publishDiagnostics"
                and (uri is None or m["params"]["uri"] == uri)
            ]

    def diagnostics(self, uri, timeout=None):
        """次に届く publishDiagnostics の中身。届かなければ None。"""
        m = self.wait(
            lambda m: m.get("method") == "textDocument/publishDiagnostics"
            and m["params"]["uri"] == uri,
            timeout,
        )
        return None if m is None else m["params"]["diagnostics"]

    def codes(self, uri, timeout=None):
        d = self.diagnostics(uri, timeout)
        return None if d is None else sorted({x.get("code") for x in d})

    # ------------------------------------------------------------ 文書

    def initialize(self, root_uri):
        reply = self.request(
            "initialize",
            {"processId": None, "rootUri": root_uri, "capabilities": {}},
        )
        self.notify("initialized", {})
        return reply

    def open(self, uri, text, language="dowel"):
        self.notify(
            "textDocument/didOpen",
            {"textDocument": {"uri": uri, "languageId": language,
                              "version": 1, "text": text}},
        )

    def change(self, uri, text, version=2):
        self.notify(
            "textDocument/didChange",
            {"textDocument": {"uri": uri, "version": version},
             "contentChanges": [{"text": text}]},
        )

    def save(self, uri):
        self.notify("textDocument/didSave", {"textDocument": {"uri": uri}})

    def close_doc(self, uri):
        self.notify("textDocument/didClose", {"textDocument": {"uri": uri}})

    def hover(self, uri, line, character):
        return self.request(
            "textDocument/hover",
            {"textDocument": {"uri": uri},
             "position": {"line": line, "character": character}},
        )

    def hover_text(self, uri, line, character):
        reply = self.hover(uri, line, character)
        result = (reply or {}).get("result")
        return None if result is None else result["contents"]["value"]

    # ------------------------------------------------------------ 生死

    def alive(self):
        return self.proc.poll() is None

    def status(self):
        """(生きているか, 終了状態)。シグナルによる終了は負で返る。"""
        return (self.proc.poll() is None, self.proc.poll())

    def aborted(self):
        """シグナルで死んだか、パニックの文言を残したか。"""
        rc = self.proc.poll()
        if rc is not None and rc < 0:
            return True
        return any("panicked" in e or "overflowed its stack" in e
                   for e in self.stderr)

    def shutdown(self):
        if self.alive():
            self.request("shutdown", None)
            self.notify("exit", None)
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        return self.proc.returncode

    def kill(self):
        if self.alive():
            self.proc.kill()
        self.proc.wait()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.kill()
        return False


def utf16_len(s):
    """UTF-16 単位での長さ。LSP の桁はこの単位である。"""
    return len(s.encode("utf-16-le")) // 2
