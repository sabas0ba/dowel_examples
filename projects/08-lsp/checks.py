"""08-lsp の検査本体。

`status \t desc [\t 所見]` を1行1検査で標準出力へ書く。判定は expect.sh が
記録する。シェルから JSON-RPC を話すのは無理があるため、この段だけ Python で
書き、ハーネスとの境界は他のプロジェクトと同じ「1検査1行」に揃える。
"""

import json
import os
import subprocess
import sys

sys.path.insert(0, os.environ["SUITE_ROOT"] + "/lib")
from lsp_client import Lsp, utf16_len  # noqa: E402

DOWEL = os.environ["DOWEL"]
ROOT = os.path.abspath("subject")
BUILD_URI = "file://" + ROOT + "/dowel.build"
TOML_URI = "file://" + ROOT + "/dowel.toml"
ROOT_URI = "file://" + ROOT

VALID = open(os.path.join(ROOT, "dowel.build"), encoding="utf-8").read()
VALID_TOML = open(os.path.join(ROOT, "dowel.toml"), encoding="utf-8").read()


def report(ok, desc, issue=""):
    print("%s\t%s\t%s" % ("pass" if ok else "fail", desc, issue))


# --------------------------------------------------------------- CLI 側の観測
#
# 一致を見るには、同じ本文に対する `dowel check` の答が要る。
# 実体を汚さないよう、複製した木の上で走らせて必ず戻す。

def cli_codes(text, name="dowel.build"):
    path = os.path.join(ROOT, name)
    keep = open(path, encoding="utf-8").read()
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        p = subprocess.run(
            [DOWEL, "check", "--message-format=json"],
            cwd=ROOT, capture_output=True, timeout=60,
        )
        out = set()
        for line in p.stdout.decode("utf-8", "replace").splitlines():
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            if obj.get("code"):
                out.add(obj["code"])
        return sorted(out)
    finally:
        with open(path, "w", encoding="utf-8") as f:
            f.write(keep)


def session():
    s = Lsp(DOWEL, ROOT)
    s.initialize(ROOT_URI)
    return s


# --------------------------------------------------------------- 1. 手続き
#
# エディタが起動主体である以上、話が通じることそのものが前提になる。

def protocol():
    with session() as s:
        reply = s.request("initialize", {"processId": None,
                                         "rootUri": ROOT_URI, "capabilities": {}})
        # 2度目の initialize は本筋ではない。上の session() の結果を見る。
        caps = ((reply or {}).get("result") or {}).get("capabilities", {})
        report(bool(reply), "initialize is answered")
        report(caps.get("hoverProvider") is True, "the server advertises hover")
        report("textDocumentSync" in caps, "the server advertises document sync")

    with session() as s:
        s.open(BUILD_URI, VALID)
        d = s.diagnostics(BUILD_URI)
        report(d is not None, "didOpen publishes diagnostics even when there are none")
        report(d == [], "a valid manifest publishes an empty list")

        s.settle()
        s.change(BUILD_URI, '[bin.subject]\nsources = glob("src/*.c"\n', 2)
        report(s.codes(BUILD_URI) == ["expected-token"],
               "didChange republishes for the new text")

        s.settle()
        s.save(BUILD_URI)
        # didSave 後に通知が来るかは実装の自由。落ちないことだけを見る。
        report(s.alive(), "didSave does not upset the server")

        s.settle()
        s.close_doc(BUILD_URI)
        report(s.diagnostics(BUILD_URI, timeout=5) == [],
               "didClose clears the diagnostics of that document")

        s.settle()
        s.open(BUILD_URI, '[bin.subject]\nsources = glob("src/*.c"\n')
        report(s.codes(BUILD_URI) == ["expected-token"],
               "reopening a closed document publishes again")

    with session() as s:
        report(s.shutdown() == 0, "shutdown and exit end the process cleanly")


def rpc_robustness():
    """「読めない本文は捨てて次を読み、1件の不正で接続を落とさない」。

    エディタと言語サーバの間には、こちらが書いていない実装が挟まる。
    1件の不正で落ちると、利用者には言語サーバが不安定に見える。
    """
    # 1件ずつ別のセッションで与える。1つの接続に続けて流すと、こちらが
    # 壊した流れの上で次を測ることになり、何を見ているのか分からなくなる。
    # 枠付けが正しく、本文だけが読めないもの。ここは復帰まで見る。
    # 「読めない本文は捨てて次を読む」が成り立つのは、次の本文の始まりが
    # 分かる場合だけであり、それは Content-Length が正しい場合である。
    for label, payload in [
        ("a body that is not JSON", b"Content-Length: 5\r\n\r\nhello"),
        ("a JSON body that is not a request", b"Content-Length: 2\r\n\r\n[]"),
    ]:
        with session() as s:
            s.open(BUILD_URI, VALID)
            s.diagnostics(BUILD_URI)
            s.send_raw(payload)
            report(s.alive(), "the server survives %s" % label)
            s.settle()
            s.change(BUILD_URI, '[bin.subject]\nsources = glob("src/*.c"\n', 2)
            report(s.codes(BUILD_URI, timeout=8) == ["expected-token"],
                   "diagnostics still arrive after %s" % label)

    # 枠付けそのものが壊れているもの。本文の終わりが決まらないため、
    # 捨てて次へ進むことが原理的にできない。見るのは生存だけである。
    for label, payload in [
        ("a body shorter than Content-Length says", b"Content-Length: 9999\r\n\r\n{}"),
        ("a body with no Content-Length", b"\r\n{}"),
        ("a Content-Length that is not a number", b"Content-Length: abc\r\n\r\n{}"),
    ]:
        with session() as s:
            s.send_raw(payload)
            report(s.alive(), "the server survives %s" % label)

    with session() as s:
        reply = s.request("textDocument/nosuchmethod", {})
        err = (reply or {}).get("error", {})
        report(err.get("code") == -32601,
               "an unknown method is answered with method-not-found")
        report(s.alive(), "the server survives an unknown method")


# --------------------------------------------------------------- 2. 診断の形

def diagnostic_shape():
    with session() as s:
        s.open(BUILD_URI, '[bin.subject]\nsources = glob("src/*.c"\n')
        d = s.diagnostics(BUILD_URI) or []
        one = d[0] if d else {}
        report(bool(d), "a broken manifest yields at least one diagnostic")
        report(one.get("code") == "expected-token",
               "the diagnostic carries the stable code")
        report(one.get("source") == "dowel", "the diagnostic names dowel as its source")
        report(one.get("severity") == 1, "a parse error is reported as an error")
        rng = one.get("range", {})
        report("start" in rng and "end" in rng, "the diagnostic carries a range")

        # 行は0始まりである。2行目の誤りが line=1 として出る。
        s.settle()
        s.change(BUILD_URI, '[bin.subject]\nsources = glob("src/*.c" @\n', 2)
        d = s.diagnostics(BUILD_URI) or []
        got = [x for x in d if x.get("code") == "unknown-char"]
        report(bool(got) and got[0]["range"]["start"]["line"] == 1,
               "diagnostic lines are zero based")


def utf16_columns():
    """桁は UTF-16 単位である（`docs/91-implementation-status.md`）。

    バイト数や符号位置数と一致してしまう入力だけを見ていると、
    取り違えても気づけない。星界面（4 バイト・UTF-16 で2単位）が
    3つの数え方を初めて分ける。
    """
    fills = [("ASCII", "a"), ("a two byte character", "é"),
             ("a three byte character", "日"),
             ("an astral plane character", "\U0001F4A9")]
    with session() as s:
        s.open(BUILD_URI, VALID)
        s.diagnostics(BUILD_URI)
        version = 1
        for label, ch in fills:
            line = 'sources = ["' + ch * 3 + '"] @'
            prefix = line.split("@")[0]
            want = utf16_len(prefix)
            s.settle()
            version += 1
            s.change(BUILD_URI, "[bin.subject]\n" + line + "\n", version)
            d = s.diagnostics(BUILD_URI) or []
            got = [x for x in d if x.get("code") == "unknown-char"]
            col = got[0]["range"]["start"]["character"] if got else None
            report(col == want,
                   "the column of a diagnostic is in UTF-16 units after %s" % label)


def utf16_positions():
    """入力側の桁も UTF-16 単位で解される必要がある。

    エディタが送るのは UTF-16 の桁である。サーバがバイト位置として読むと、
    非 ASCII を含む行ではホバーが別の語に当たる。
    """
    fills = [("ASCII", "aaa"), ("a two byte character", "é" * 3),
             ("a three byte character", "日" * 3),
             ("an astral plane character", "\U0001F4A9" * 3)]
    with session() as s:
        s.open(BUILD_URI, VALID)
        s.diagnostics(BUILD_URI)
        version = 1
        for label, fill in fills:
            line = ('flags = ["' + fill
                    + '", match cfg.opt { debug => "-O0", release => "-O2" }]')
            text = ('[bin.subject]\nsources = glob("src/*.c")\n\n'
                    '[bin.subject.private]\n' + line + "\n")
            column = utf16_len(line[: line.index("cfg.opt") + 1])
            s.settle()
            version += 1
            s.change(BUILD_URI, text, version)
            s.diagnostics(BUILD_URI, timeout=5)
            text_at = s.hover_text(BUILD_URI, 4, column) or ""
            report("cfg.opt" in text_at,
                   "a hover position is read in UTF-16 units after %s" % label)


# --------------------------------------------------------------- 3. CLI との一致
#
# エディタと `dowel check` が同じ本文に別の答を返すなら、どちらかが嘘である。
# 利用者はエディタの方を信じるため、出ない側の誤りが通る。

SINGLE_FILE = [
    # (期待する安定コード, 本文, 未修正の所見)
    ("unterminated-string", '[bin.subject]\nsources = glob("src/*.c\n', ""),
    ("expected-token", '[bin.subject]\nsources = glob("src/*.c"\n', ""),
    ("unknown-char", '[bin.subject]\nsources = glob("src/*.c") @\n', ""),
    ("expected-value", "[bin.subject]\nsources =\n", ""),
    ("missing-newline", "[bin.subject] [bin.other]\n", ""),
    ("unterminated-comment", "[bin.subject]\n/* sources\n", ""),
    ("duplicate-table",
     '[bin.subject]\nsources = glob("src/*.c")\n[bin.subject]\n'
     'sources = glob("src/*.c")\n', ""),
    ("unknown-function", '[bin.subject]\nsources = globb("src/*.c")\n', ""),
    ("unknown-cfg-key",
     '[bin.subject]\nsources = glob("src/*.c")\n\n[bin.subject.private]\n'
     'flags = ["-O0" when cfg.nosuch]\n', ""),
    ("non-exhaustive-match",
     '[bin.subject]\nsources = glob("src/*.c")\n\n[bin.subject.private]\n'
     'flags = [match cfg.opt { debug => "-O0" }]\n', ""),
    # 型検査の段。かつては言語サーバから出ていなかった
    # （docs/10-findings.md F-012）。開いている1ファイルだけで決まる。
    ("unknown-property",
     '[bin.subject]\nsources = glob("src/*.c")\n\n[bin.subject.private]\n'
     'include = [dir("src")]\n', ""),
    ("unknown-kind", '[binn.subject]\nsources = glob("src/*.c")\n', ""),
    ("type-mismatch", "[bin.subject]\nsources = 42\n", ""),
    ("toplevel-entry", 'sources = glob("src/*.c")\n', ""),
    ("missing-field",
     '[bin.subject]\nsources = glob("src/*.c")\n\n'
     '[runner.aarch64-unknown-linux-gnu]\nargs = ["-x"]\n', ""),
]


def agreement():
    with session() as s:
        s.open(BUILD_URI, VALID)
        s.diagnostics(BUILD_URI)
        version = 1
        for code, text, issue in SINGLE_FILE:
            in_cli = code in cli_codes(text)
            s.settle()
            version += 1
            s.change(BUILD_URI, text, version)
            got = s.codes(BUILD_URI, timeout=8) or []
            # 前提が崩れていないことを先に見る。CLI が出さないなら比較にならない。
            report(in_cli, "dowel check still reports %s" % code)
            report(code in got,
                   "the language server reports %s as dowel check does" % code, issue)


def toml_agreement():
    cases = [
        ("expression-in-strict-toml",
         VALID_TOML + 'x = glob("a")\n', ""),
        ("expected-token", '[package\nname = "p"\n', ""),
        ("unterminated-string", '[package]\nname = "p\nversion = "0.1.0"\n', ""),
        ("duplicate-key",
         '[package]\nname = "p"\nname = "q"\nversion = "0.1.0"\n'
         'edition = "2026"\n', ""),
        ("missing-table", 'name = "p"\n', ""),
    ]
    with session() as s:
        for code, text, issue in cases:
            in_cli = code in cli_codes(text, "dowel.toml")
            s.settle()
            s.open(TOML_URI, text, language="toml")
            got = s.codes(TOML_URI, timeout=8) or []
            s.settle()
            s.close_doc(TOML_URI)
            report(in_cli, "dowel check still reports %s in dowel.toml" % code)
            report(code in got,
                   "the language server reports %s in dowel.toml" % code, issue)


# ------------------------------------------------------- 3.1. 計画段との一致
#
# 上の一致は、開いた本文だけで決まる誤りを見ている。ここで見るのは
# **ファイルシステムを走査しないと分からない誤り**である。glob の展開、
# パスの解決、ツールチェーンの実在がそれにあたる。
#
# かつてこれらは言語サーバから出ず、`dowel_lsp::UNSUPPORTED` に理由つきで
# 並んでいた。エディタが黙る誤りは、利用者にとって存在しない誤りになる。
# `check` と同じ深さで出るようになったことを、同じ本文への答が一致するか
# どうかで見る（`docs/91-implementation-status.md`）。

PLAN_STAGE = [
    # (期待する安定コード, 本文, 未修正の所見)
    ("empty-glob", '[bin.subject]\nsources = glob("nowhere/*.c")\n', ""),
    ("no-sources", "[bin.subject]\nsources = []\n", ""),
    # 実在するが翻訳できないもの。ディレクトリを file() で指した場合。
    ("invalid-source", '[bin.subject]\nsources = [file("src")]\n', ""),
    # 実在しないもの。ビルドツールの「no known rule」より前に捕まえる。
    ("unresolved-path", '[bin.subject]\nsources = [file("src/nowhere.c")]\n', ""),
]


def plan_agreement():
    with session() as s:
        s.open(BUILD_URI, VALID)
        s.diagnostics(BUILD_URI)
        version = 1
        for code, text, issue in PLAN_STAGE:
            in_cli = code in cli_codes(text)
            s.settle()
            version += 1
            s.change(BUILD_URI, text, version)
            got = s.codes(BUILD_URI, timeout=8) or []
            report(in_cli, "dowel check still reports %s" % code)
            report(code in got,
                   "the language server scans the file system for %s" % code, issue)

    # ツールチェーンの実在は dowel.toml 側の宣言で決まる。走査ではなく
    # PATH の探索だが、同じく「開いた本文だけでは決まらない」側である。
    text = VALID_TOML + '\n[toolchain]\nc = "no-such-compiler-xyz"\n'
    with session() as s:
        in_cli = "missing-toolchain" in cli_codes(text, "dowel.toml")
        s.settle()
        s.open(TOML_URI, text, language="toml")
        got = s.codes(TOML_URI, timeout=8) or []
        s.settle()
        s.close_doc(TOML_URI)
        report(in_cli, "dowel check still reports missing-toolchain")
        report("missing-toolchain" in got,
               "the language server looks for the declared compiler too")


# --------------------------------------------- 3.2. 出さないと決めてあるもの
#
# 出さないものは残っている。エディタの会期は**読むだけ**であり、取得も
# しなければ外部のプロセスも起こさない（ADR-0015）。境界は空にするのが
# 目標だが、空でない間は「出ないこと」自体を固定する。出ないと決めたものが
# うっかり出るようになると、エディタが副作用を持つ。

def unsupported_boundary():
    # システムパッケージの解決は pkg-config を起こす。CLI は拒むが、
    # 言語サーバは何も言わない。
    text = VALID_TOML + ('\n[[dependencies]]\nname    = "nosuchmodule-xyz"\n'
                         'version = "1.0"\n')
    in_cli = "unsatisfied-dependency" in cli_codes(text, "dowel.toml")
    with session() as s:
        s.settle()
        s.open(TOML_URI, text, language="toml")
        got = s.codes(TOML_URI, timeout=8) or []
        s.settle()
        s.close_doc(TOML_URI)
    report(in_cli, "dowel check refuses an unresolvable system package")
    report("unsatisfied-dependency" not in got,
           "the language server does not run pkg-config to resolve it")
    # 記録の突き合わせも解決に付随する。会期が lock を書くと、エディタで
    # 開いただけで版管理に差分が出る。
    report(not os.path.exists(os.path.join(ROOT, "dowel.lock")),
           "opening a manifest never writes dowel.lock")


# --------------------------------------------------------------- 4. ホバー
#
# ホバーはスキーマそのものを説明にする（`docs/30-devexp.md` 3.2 節）。
# 出所は `dowel schema dump` と同じ表であり、二重に持たない。

def hover():
    text = ('[bin.subject]\nsources = glob("src/*.c")\n\n'
            '[bin.subject.private]\nincludes = [dir("src")]\n'
            'flags    = [match cfg.opt { debug => "-O0", release => "-O2" }]\n')
    with session() as s:
        s.open(BUILD_URI, text)
        s.diagnostics(BUILD_URI)

        cases = [
            ((1, 2), ["sources", "List<Path>", "append"],
             "hover on a property gives its type and merge rule"),
            ((4, 2), ["includes", "Set<Path>", "union"],
             "hover on includes gives union as its merge rule"),
            ((1, 12), ["glob", "(Str) -> List<Path>"],
             "hover on a builtin gives its signature"),
            ((5, 20), ["cfg.opt", "debug", "release"],
             "hover on a configuration key gives its domain"),
            ((0, 2), ["bin"], "hover on a table kind explains the kind"),
            ((3, 5), ["subject"], "hover on a target name names the target"),
            ((3, 14), ["private"], "hover on a block explains the block"),
        ]
        for (line, col), wants, desc in cases:
            got = s.hover_text(BUILD_URI, line, col) or ""
            report(all(w in got for w in wants), desc)

        # 誤りを含むファイルでも説明が出る必要がある（同 3.2 節）。編集中の
        # マニフェストは常にどこかが壊れているため、ここが働かないと
        # ホバーは「直し終わってから使うもの」になり、修復の役に立たない。
        #
        # 壊すのは後ろの行にする。閉じていない呼び出しは以降の行を引数として
        # 飲み込むため、その内側の語は語として残らない。これは復帰の仕方で
        # あって説明の不在ではない。
        s.settle()
        s.change(BUILD_URI, text.replace('dir("src")]', 'dir("src"]'), 2)
        s.diagnostics(BUILD_URI, timeout=5)
        for (line, col), want in [((1, 2), "sources"), ((1, 12), "glob"),
                                  ((4, 2), "includes")]:
            got = s.hover_text(BUILD_URI, line, col) or ""
            report(want in got,
                   "hover answers for %s while a later line has a parse error" % want)

        # 語でない位置と範囲外。null が返ること、落ちないこと。
        s.settle()
        s.change(BUILD_URI, text, 3)
        s.diagnostics(BUILD_URI, timeout=5)
        report(s.hover_text(BUILD_URI, 2, 0) is None,
               "hover on a blank line answers with no contents")
        report(s.hover_text(BUILD_URI, 9999, 0) is None,
               "hover past the end of the file answers with no contents")
        report(s.hover_text(BUILD_URI, 1, 9999) is None,
               "hover past the end of a line answers with no contents")
        report(s.alive(), "the server survives hover positions that are out of range")

        # 未知のプロパティにはホバーが無い。スキーマを引けている証拠であり、
        # 同じ判定が unknown-property として出ることと対になる（F-012）。
        s.settle()
        s.change(BUILD_URI, text.replace("includes =", "include  ="), 4)
        s.diagnostics(BUILD_URI, timeout=5)
        report(s.hover_text(BUILD_URI, 4, 2) is None,
               "hover on an unknown property answers with no contents")


# --------------------------------------------------------------- 5. 頑健性
#
# 07-robustness と同じ性質を、言語サーバの入口から見る。CLI では利用者が
# シェルに戻るだけだが、ここで落ちるとエディタとの接続が切れる。

def robustness():
    # 深さは「確実に足りる」ものと「確実に溢れる」ものだけを使う。溢れる境目は
    # 機械の stack の大きさで決まるため、その付近に置いた検査は dowel ではなく
    # 実行した機械を記録することになる。実際、深さ 10000 は手元では abort し、
    # CI の runner では通った（07-robustness が 100000 を選ぶのと同じ理由）。
    for depth, issue in [(64, ""), (1000, ""), (100000, "")]:
        with session() as s:
            s.open(BUILD_URI, VALID)
            s.diagnostics(BUILD_URI)
            s.settle()
            s.change(BUILD_URI, "[bin.subject]\nsources = "
                     + "[" * depth + "]" * depth + "\n", 2)
            got = s.diagnostics(BUILD_URI, timeout=15)
            report(not s.aborted(),
                   "the server survives a didChange nested %d deep" % depth, issue)
            report(got is not None,
                   "the server answers a didChange nested %d deep" % depth, issue)

    # 素直でないバイト列。エディタの緩衝は文字列として渡るため、
    # BOM は本文の先頭の1文字として現れる。些末部として読み飛ばされる（F-011）。
    with session() as s:
        s.open(BUILD_URI, VALID)
        s.diagnostics(BUILD_URI)
        s.settle()
        s.change(BUILD_URI, "﻿" + VALID, 2)
        got = s.codes(BUILD_URI, timeout=8)
        report(got == [], "a UTF-8 BOM in the buffer is not reported as an error")
        s.settle()
        s.change(BUILD_URI, VALID.replace("\n", "\r\n"), 3)
        report(s.codes(BUILD_URI, timeout=8) == [],
               "CRLF in the buffer is not reported as an error")
        s.settle()
        s.change(BUILD_URI, "[bin.subject]\nsources = glob(\"src/日本語.c\")\n", 4)
        s.diagnostics(BUILD_URI, timeout=8)
        report(s.alive(), "the server survives non-ASCII paths in the buffer")


def main():
    for stage in (protocol, rpc_robustness, diagnostic_shape, utf16_columns,
                  utf16_positions, agreement, toml_agreement, plan_agreement,
                  unsupported_boundary, hover, robustness):
        try:
            stage()
        except Exception as e:  # 段が落ちても残りは走らせる
            report(False, "the %s stage runs to completion (%s: %s)"
                   % (stage.__name__, type(e).__name__, e))


if __name__ == "__main__":
    main()
