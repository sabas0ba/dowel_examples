#!/usr/bin/env python3
"""文書の整合。

文書の不整合はスイートの実行にもビルドにも影響しないため、検査しない限り
検出されない。実際、検査名を英語へ揃えた際に `docs/10-findings.md` の
引用側を直し忘れ、5件が実在しない名前を指したまま残った。

対象は機械的に判定できる項目に限る。記述内容の妥当性は検査しない
（dowel 本体の `crates/dowel-cli/tests/docs.rs` と同じ立場である）。

    check-docs.py <results.tsv>

`status<TAB>desc` を1行ずつ標準出力へ書く。`run.sh` がこれを表に載せる。
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 引用が検査名か、それ以外（パス、診断コード、識別子）かの区別。
# 検査名は英語の文であり、必ず空白を含む。パスと診断コードは含まない。
# 検査名は英語の一文である。同じ節にはマニフェストの断片も引用されるため
# （`abi = "c"`、`[features] exclusive`、`List<Str | Path>`）、それらを
# 検査名と読み違えないよう、名前には現れない字を持つものを除く。
_NOT_IN_A_CHECK_NAME = set('<>[]{}="|=')


def looks_like_a_check_name(s):
    return (
        " " in s
        and "/" not in s
        and not s.startswith("-")
        and not (_NOT_IN_A_CHECK_NAME & set(s))
    )


def markdown_files():
    """本リポジトリが追跡している Markdown だけを返す。

    走査を作業ディレクトリ全体にすると、そこに置かれた別のものまで拾う。
    実際 CI では dowel の checkout（`.dowel-src/`）が同じ木の中にあり、
    その `docs/10-manifest.md` に含まれる git 依存の例の rev を
    「文書が引用する版」と誤認して落ちた。追跡対象かどうかが正しい境界である。
    """
    try:
        tracked = subprocess.run(
            ["git", "-C", ROOT, "ls-files", "-z", "*.md"],
            capture_output=True, check=False,
        )
    except OSError:
        tracked = None  # git が無い
    if tracked is not None and tracked.returncode == 0:
        for name in tracked.stdout.decode("utf-8").split("\0"):
            if name:
                yield os.path.join(ROOT, name)
        return
    # git が使えない場合の退避。既知の置き場だけを見る。
    for sub in ("", "docs", "projects", "apps"):
        base = os.path.join(ROOT, sub)
        for cur, dirs, names in os.walk(base):
            dirs[:] = [d for d in dirs if not d.startswith(".") and d != "__pycache__"]
            for n in names:
                if n.endswith(".md"):
                    yield os.path.join(cur, n)


def rel(path):
    return os.path.relpath(path, ROOT)


# ---------------------------------------------------------------- 個々の検査


def check_links(report):
    """相対リンクの指す先が存在すること。"""
    broken = []
    for path in markdown_files():
        with open(path, encoding="utf-8") as f:
            text = f.read()
        for target in re.findall(r"\]\(([^)]+)\)", text):
            if target.startswith(("http://", "https://", "#", "mailto:")):
                continue
            target = target.split("#", 1)[0]
            if not target:
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
            if not os.path.exists(resolved):
                broken.append(f"{rel(path)} -> {target}")
    report(not broken, "every relative link in the documentation resolves", broken)


def check_project_index(report):
    """README の表が `projects/` と `apps/` の中身と一致すること。

    探索の根は2つあり、目的が違う（`projects/` は性質の検査、`apps/` は
    実アプリ）。どちらも README に並べ、抜けを機械的に見る。
    """
    for root, label in (("projects", "the project table in README.md matches projects/"),
                        ("apps", "the application table in README.md matches apps/")):
        base = os.path.join(ROOT, root)
        on_disk = sorted(
            d for d in os.listdir(base) if os.path.isdir(os.path.join(base, d))
        ) if os.path.isdir(base) else []
        with open(os.path.join(ROOT, "README.md"), encoding="utf-8") as f:
            listed = sorted(set(re.findall(r"\]\(" + root + r"/([^/)]+)/\)", f.read())))
        report(on_disk == listed, label,
               [f"on disk: {on_disk}", f"listed:  {listed}"])


def check_doc_index(report):
    """README の文書表が `docs/` の中身と一致すること。"""
    on_disk = sorted(n for n in os.listdir(os.path.join(ROOT, "docs")) if n.endswith(".md"))
    with open(os.path.join(ROOT, "README.md"), encoding="utf-8") as f:
        listed = sorted(set(re.findall(r"\]\(docs/([^)/]+\.md)\)", f.read())))
    report(
        on_disk == listed,
        "the documentation table in README.md matches docs/",
        [f"on disk: {on_disk}", f"listed:  {listed}"],
    )


def check_quoted_check_names(report, actual):
    """`### 検査` の節が引用する検査名が実在すること。

    検査名を変えたのに引用側を変え忘れる、という誤りはこれでしか検出できない。
    参照が解決しなくなっても、スイートは何事もなく通る。
    """
    if not actual:
        report(False, "check names quoted in the documentation exist",
               ["no results were given; run the whole suite"])
        return
    missing = []
    for path in markdown_files():
        with open(path, encoding="utf-8") as f:
            text = f.read()
        for section in re.findall(r"### 検査\n(.*?)(?=\n(?:###|##|---)|\Z)", text, re.S):
            for quoted in re.findall(r"`([^`\n]+)`", section):
                if not looks_like_a_check_name(quoted):
                    continue
                if quoted not in actual:
                    missing.append(f"{rel(path)}: {quoted}")
    report(not missing, "check names quoted in the documentation exist", missing)


def check_finding_ids(report):
    """`known_issue` が指す所見が `10-findings.md` に存在すること。"""
    declared = set(re.findall(r"^## (F-\d{3})$", _read("docs/10-findings.md"), re.M))
    used = set()
    for root in ("projects", "apps"):
        if not os.path.isdir(os.path.join(ROOT, root)):
            continue
        for base, dirs, names in os.walk(os.path.join(ROOT, root)):
            for n in names:
                if n == "expect.sh":
                    used |= set(re.findall(
                        r"known_issue\s+(F-\d{3})", _read_abs(os.path.join(base, n))))
    unknown = sorted(used - declared)
    report(
        not unknown,
        "every known_issue declaration names a finding that exists",
        [f"unknown: {unknown}"] if unknown else [],
    )


def check_findings_index(report):
    """`10-findings.md` の一覧が本文の節と一致すること（双方向）。"""
    text = _read("docs/10-findings.md")
    sections = set(re.findall(r"^## (F-\d{3})$", text, re.M))
    listed = set(re.findall(r"^\| \[(F-\d{3})\]", text, re.M))
    report(
        sections == listed,
        "the index of docs/10-findings.md matches its sections",
        [f"sections: {sorted(sections)}", f"listed:   {sorted(listed)}"],
    )


def check_pinned_ref(report):
    """文書が引用する dowel の版が `dowel-ref` と一致すること。

    追随のたびに書き換え忘れる。読み手は文書の値を信じて手元で checkout する。
    """
    ref = [l for l in _read("dowel-ref").splitlines()
           if l.strip() and not l.lstrip().startswith("#")][-1].strip()
    stale = []
    for path in markdown_files():
        for other in set(re.findall(r"\b[0-9a-f]{40}\b", _read_abs(path))):
            if other != ref:
                stale.append(f"{rel(path)}: {other[:12]}")
    report(not stale, "the dowel revision quoted in the documentation matches dowel-ref", stale)


def _read(relpath):
    return _read_abs(os.path.join(ROOT, relpath))


def _read_abs(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


# ------------------------------------------------------------------ 入口


def main():
    actual = set()
    if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
        with open(sys.argv[1], encoding="utf-8") as f:
            for line in f:
                parts = line.rstrip("\n").split("\t")
                if len(parts) == 3:
                    # xfail / xpass の行には harness が `  [F-010]` を足す。
                    # これは検査名ではなく状態の注記なので、照合の前に外す。
                    # 外さないと、未修正事項に対する検査は文書から引用できない。
                    actual.add(re.sub(r"\s+\[F-\d{3}\]$", "", parts[2]))

    failed = 0

    def report(ok, desc, detail):
        nonlocal failed
        if ok:
            print(f"pass\t{desc}")
        else:
            failed += 1
            note = "; ".join(detail[:6])
            if len(detail) > 6:
                note += f"; and {len(detail) - 6} more"
            print(f"fail\t{desc} ({note})")

    check_links(report)
    check_project_index(report)
    check_doc_index(report)
    check_quoted_check_names(report, actual)
    check_finding_ids(report)
    check_findings_index(report)
    check_pinned_ref(report)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
