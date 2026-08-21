#!/usr/bin/env python3
"""検査結果の集計と publish。

`run.sh` が `.work/` に残した TSV から、次の3つを作る。

    summary.md    人間向け。GitHub Actions のジョブ要約へそのまま流せる形
    results.json  機械可読。1回の実行を1オブジェクトで表す
    index.html    publish 用。過去の実行を積んだ履歴から作る
    history.svg   同じ履歴の図（`scripts/chart.py`）。README が埋める版

サブコマンドは2つ。

    report.py run  --work .work --out <dir>
        1回の実行をまとめる。summary.md と results.json を書く

    report.py site --history <history.json> [--latest <results.json>] --out <dir>
        履歴から index.html と history.svg を作る。publish 用の枝で使う。
        --latest を渡すと、直近の実行の内訳（検査の全件）も出す

履歴の追記は `run --append <history.json>` で行う。同じ実行（run_id）が
二度来た場合は後のもので置き換える。再実行しても行が増えない。
"""

import argparse
import html
import json
import os
import sys

import chart

# 状態の表示順。この順序が表の列の順序になる。
STATES = ["pass", "fail", "xfail", "xpass"]

LABEL = {
    "pass": "passed",
    "fail": "failed",
    "xfail": "known",
    "xpass": "fixed",
}

# 履歴に積む件数の上限。publish する表が際限なく伸びると読めなくなる。
HISTORY_LIMIT = 100


# ------------------------------------------------------------------ 読み取り


def read_tsv(path, fields):
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) != len(fields):
                continue
            rows.append(dict(zip(fields, parts)))
    return rows


def read_meta(path):
    meta = {}
    for row in read_tsv(path, ["key", "value"]):
        meta[row["key"]] = row["value"]
    return meta


def collect(work):
    """`.work/` の中身を1回の実行として組み立てる。"""
    meta = read_meta(os.path.join(work, "meta.tsv"))
    checks = read_tsv(os.path.join(work, "results.tsv"), ["status", "project", "desc"])
    raw = read_tsv(
        os.path.join(work, "projects.tsv"),
        ["name", "duration_ms", "pass", "fail", "xfail", "xpass", "root"],
    )
    pkgs = read_tsv(os.path.join(work, "packages.tsv"), ["project", "path"])

    projects = []
    for r in raw:
        counts = {s: int(r[s]) for s in STATES}
        projects.append(
            {
                "name": r["name"],
                # 実体の置き場所。projects/ は性質の検査、apps/ は実アプリ。
                # 古い履歴には無いため projects/ を既定にする。
                "root": r.get("root") or "projects",
                "duration_ms": int(r["duration_ms"]),
                "counts": counts,
                "total": sum(counts.values()),
                # 失敗と XPASS のどちらも「直すべきもの」である。
                "ok": counts["fail"] == 0 and counts["xpass"] == 0,
                # 検査の全件。publish で内訳を出すために持つ。履歴には積まない
                # （100 回分を抱えると読めない大きさになる）。
                "checks": [
                    {"status": c["status"], "desc": c["desc"]}
                    for c in checks
                    if c["project"] == r["name"]
                ],
                # 実体へ辿るための材料。
                "packages": [p["path"] for p in pkgs if p["project"] == r["name"]],
            }
        )

    totals = {s: sum(p["counts"][s] for p in projects) for s in STATES}

    return {
        "run_id": os.environ.get("GITHUB_RUN_ID", ""),
        "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", ""),
        "run_url": run_url(),
        "commit": meta.get("commit", ""),
        "branch": meta.get("branch", ""),
        "started_at": meta.get("started_at", ""),
        "dowel_version": meta.get("dowel_version", ""),
        "dowel_ref": os.environ.get("DOWEL_REF", ""),
        "dowel_commit": os.environ.get("DOWEL_COMMIT", ""),
        "cc": meta.get("cc", ""),
        "ninja": meta.get("ninja", ""),
        "projects": projects,
        "totals": totals,
        "total": sum(totals.values()),
        # 1件も走っていない実行を成功と呼ばない。検査が0件になるのは
        # 走らせる前に落ちた場合であり、それは成功ではない。
        "ok": bool(projects) and totals["fail"] == 0 and totals["xpass"] == 0,
        "attention": [c for c in checks if c["status"] in ("fail", "xpass")],
        "known_issues": [c for c in checks if c["status"] == "xfail"],
    }


def run_url():
    server = os.environ.get("GITHUB_SERVER_URL", "")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    if server and repo and run_id:
        return f"{server}/{repo}/actions/runs/{run_id}"
    return ""


# ---------------------------------------------------------------- 実体への道
#
# publish は結果しか持たない。「この検査は何を見ているのか」を追うには、
# 実体へ辿れる必要がある。相手は2つのリポジトリに固定されているため、
# ここで定数として持つ。環境変数で上書きできる。

SUITE_REPO = os.environ.get("SUITE_REPO_URL", "https://github.com/sabas0ba/dowel_examples")
DOWEL_REPO = os.environ.get("DOWEL_REPO_URL", "https://github.com/sabas0ba/dowel")


def suite_tree(run, path=""):
    """本リポジトリの、その実行が用いた版へのリンク。"""
    ref = run.get("commit") or "main"
    return f"{SUITE_REPO}/tree/{ref}/{path}".rstrip("/")


def suite_blob(run, path):
    ref = run.get("commit") or "main"
    return f"{SUITE_REPO}/blob/{ref}/{path}"


def dowel_link(run):
    """検証に用いた dowel。版が分かっていればその commit を指す。"""
    sha = run.get("dowel_commit") or ""
    return f"{DOWEL_REPO}/commit/{sha}" if sha else DOWEL_REPO


# -------------------------------------------------------------- 1回分の要約


def verdict(ok):
    return "PASSED" if ok else "FAILED"


def render_summary(run):
    t = run["totals"]
    out = []
    out.append("# dowel_examples")
    out.append("")
    out.append(
        "**{}** — {} checks: {} passed, {} failed, {} known, {} fixed".format(
            verdict(run["ok"]), run["total"], t["pass"], t["fail"], t["xfail"], t["xpass"]
        )
    )
    out.append("")

    if not run["projects"]:
        out.append(
            "No check ran at all. The job failed before the suite started. See the job log."
        )
        out.append("")
        return "\n".join(out) + "\n"

    out.append("| project | state | checks | " + " | ".join(LABEL[s] for s in STATES) + " | time |")
    out.append("|---|---|--:|--:|--:|--:|--:|--:|")
    for p in run["projects"]:
        out.append(
            "| {} | {} | {} | {} | {} | {} | {} | {:.1f}s |".format(
                p["name"],
                "ok" if p["ok"] else "**FAILED**",
                p["total"],
                *[p["counts"][s] for s in STATES],
                p["duration_ms"] / 1000,
            )
        )
    out.append("")

    if run["attention"]:
        out.append("## Needs attention")
        out.append("")
        out.append("| state | project | check |")
        out.append("|---|---|---|")
        for c in run["attention"]:
            out.append("| {} | {} | {} |".format(c["status"], c["project"], c["desc"]))
        out.append("")
        out.append(
            "`xpass` means a check declared against a known unfixed issue now passes. "
            "The upstream issue is fixed: update `docs/10-findings.md` and drop the "
            "`known_issue` declaration."
        )
        out.append("")

    if run["known_issues"]:
        out.append("## Known unfixed issues")
        out.append("")
        out.append("Checks left failing on purpose. See `docs/10-findings.md`.")
        out.append("")
        out.append("| project | check |")
        out.append("|---|---|")
        for c in run["known_issues"]:
            out.append("| {} | {} |".format(c["project"], c["desc"]))
        out.append("")

    out.append("## Environment")
    out.append("")
    out.append("| | |")
    out.append("|---|---|")
    for key, label in [
        ("dowel_version", "dowel"),
        ("dowel_ref", "dowel ref"),
        ("dowel_commit", "dowel commit"),
        ("cc", "cc"),
        ("ninja", "ninja"),
        ("commit", "suite commit"),
        ("started_at", "started"),
    ]:
        if run.get(key):
            out.append("| {} | `{}` |".format(label, run[key]))
    out.append("")

    return "\n".join(out) + "\n"


# ------------------------------------------------------------------ 履歴


def for_history(run):
    """履歴へ積む形。1回分の重い部分を落とす。

    履歴が要るのは各回の内訳の数であって、検査1件ずつの一覧ではない。
    100 回分の全件を抱えると、読むにも押し込むにも大きくなりすぎる。
    直近の実行の全件は `latest.json` にあり、publish はそちらから描く。
    """
    trimmed = {k: v for k, v in run.items() if k != "known_issues"}
    trimmed["projects"] = [
        {k: v for k, v in p.items() if k != "checks"} for p in run.get("projects", [])
    ]
    return trimmed


def append_history(path, run):
    history = []
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                history = json.load(f)
        except (json.JSONDecodeError, OSError):
            history = []
    if not isinstance(history, list):
        history = []

    # 同じ実行の再実行は置き換える。行を増やさない。
    key = (run.get("run_id"), run.get("run_attempt"))
    if key != ("", ""):
        history = [h for h in history if (h.get("run_id"), h.get("run_attempt")) != key]

    history.append(for_history(run))
    history = history[-HISTORY_LIMIT:]

    with open(path, "w", encoding="utf-8") as f:
        json.dump(history, f, ensure_ascii=False, indent=1)
        f.write("\n")
    return history


# ------------------------------------------------------------------ publish

CSS = """
:root { color-scheme: light dark; --fg:#1a1a1a; --bg:#fff; --muted:#666;
        --line:#e0e0e0; --ok:#1a7f37; --ng:#cf222e; --warn:#9a6700; }
@media (prefers-color-scheme: dark) {
  :root { --fg:#e6e6e6; --bg:#0d1117; --muted:#9198a1; --line:#30363d;
          --ok:#3fb950; --ng:#f85149; --warn:#d29922; }
}
* { box-sizing: border-box; }
body { margin:0; padding:2rem 1rem; color:var(--fg); background:var(--bg);
       font:15px/1.6 -apple-system, "Helvetica Neue", "Hiragino Sans",
       "Noto Sans JP", sans-serif; }
main { max-width: 62rem; margin: 0 auto; }
h1 { font-size:1.5rem; margin:0 0 .25rem; }
h2 { font-size:1.1rem; margin:2.5rem 0 .75rem; padding-bottom:.3rem;
     border-bottom:1px solid var(--line); }
p.lede { color:var(--muted); margin:0 0 2rem; }
.scroll { overflow-x:auto; }
table { border-collapse:collapse; width:100%; font-size:.9rem; }
th, td { padding:.45rem .7rem; text-align:left; border-bottom:1px solid var(--line);
         white-space:nowrap; }
th { font-weight:600; color:var(--muted); font-size:.8rem;
     text-transform:uppercase; letter-spacing:.04em; }
td.n, th.n { text-align:right; font-variant-numeric:tabular-nums; }
td.wrap { white-space:normal; }
.ok { color:var(--ok); font-weight:600; }
.ng { color:var(--ng); font-weight:600; }
.warn { color:var(--warn); }
.zero { color:var(--muted); }
code, .mono { font-family:ui-monospace, SFMono-Regular, Menlo, monospace;
              font-size:.85em; }
a { color:inherit; }
footer { margin-top:3rem; color:var(--muted); font-size:.8rem; }
p.links { margin:.4rem 0 1.2rem; font-size:.85rem; color:var(--muted); }
p.links a { color:inherit; }
.muted { color:var(--muted); font-weight:400; }
details { border:1px solid var(--line); border-radius:6px; padding:.6rem .9rem;
          margin-bottom:.6rem; }
details[open] { padding-bottom:.2rem; }
summary { cursor:pointer; font-size:.95rem; }
summary::marker { color:var(--muted); }
details p.links { margin:.5rem 0 .6rem; }

/* 図。明暗それぞれの背景に対して選んだ2枚を持ち、頁の側で切り替える。
   片方を機械的に反転させると、暗い側で色が検証していないものになる。 */
.chart { display:block; width:100%; height:auto; margin:.2rem 0 .4rem; }
.chart.dark { display:none; }
@media (prefers-color-scheme: dark) {
  .chart.light { display:none; }
  .chart.dark { display:block; }
}
"""


def cell(n, kind):
    """0 は目立たせない。0 でない失敗は赤くする。"""
    if n == 0:
        return '<td class="n zero">0</td>'
    cls = {"fail": "ng", "xpass": "ng", "xfail": "warn"}.get(kind, "")
    return '<td class="n {}">{}</td>'.format(cls, n)


def short(s, n=12):
    return html.escape(s[:n]) if s else "—"


def render_site(history, latest=None):
    """履歴から publish の本文を作る。

    `latest` は直近の実行の全件（`latest.json`）。履歴には検査1件ずつの
    一覧を積まないため、内訳を出すにはこちらが要る。省いた場合は
    履歴の最後の要素で代用し、内訳の節は出さない。
    """
    if not history and not latest:
        return "<main><h1>dowel_examples</h1><p>No run yet.</p></main>"

    detailed = latest is not None
    if latest is None:
        latest = history[-1]
    if not history:
        history = [for_history(latest)]
    names = sorted({p["name"] for h in history for p in h["projects"]})

    out = []
    out.append("<main>")
    out.append("<h1>dowel_examples</h1>")
    out.append(
        '<p class="lede">Results of the suite that checks dowel from the outside. '
        "What each check fixes is in the README of its project; why some are left "
        "failing is in docs/10-findings.md.</p>"
    )

    # publish は結果しか持たない。実体へ辿れないと「何を見ている検査なのか」が
    # 分からないため、対象と自分自身への道をここに置く。
    links = [
        '<a href="{}">dowel</a>'.format(DOWEL_REPO),
    ]
    if latest.get("dowel_commit"):
        links.append(
            'checked against <a href="{}"><code>{}</code></a>'.format(
                dowel_link(latest), short(latest["dowel_commit"])
            )
        )
    links.append('<a href="{}">dowel_examples</a>'.format(SUITE_REPO))
    links.append('<a href="{}">dowel-ref</a>'.format(suite_blob(latest, "dowel-ref")))
    links.append('<a href="{}">docs/10-findings.md</a>'.format(
        suite_blob(latest, "docs/10-findings.md")))
    out.append('<p class="links">' + " &middot; ".join(links) + "</p>")

    # ---------------------------------------------------------- 直近の実行
    t = latest["totals"]
    out.append("<h2>Latest run</h2>")
    out.append(
        '<p><span class="{}">{}</span> — {} checks: {} passed, {} failed, {} known, {} fixed'
        "<br><span class=\"mono\">{}</span> {} on <span class=\"mono\">{}</span></p>".format(
            "ok" if latest["ok"] else "ng",
            verdict(latest["ok"]),
            latest["total"],
            t["pass"], t["fail"], t["xfail"], t["xpass"],
            short(latest.get("commit", "")),
            html.escape(latest.get("started_at", "")),
            html.escape(latest.get("branch", "")),
        )
    )

    out.append('<div class="scroll"><table>')
    out.append(
        "<tr><th>project</th><th>state</th><th class='n'>checks</th>"
        + "".join("<th class='n'>{}</th>".format(LABEL[s]) for s in STATES)
        + "<th class='n'>time</th></tr>"
    )
    for p in latest["projects"]:
        out.append(
            "<tr><td>{}</td><td class='{}'>{}</td><td class='n'>{}</td>{}<td class='n'>{:.1f}s</td></tr>".format(
                '<a href="{}">{}</a>'.format(
                    suite_tree(latest, p.get("root", "projects") + "/" + p["name"]),
                    html.escape(p.get("root", "projects") + "/" + p["name"]),
                ),
                "ok" if p["ok"] else "ng",
                "ok" if p["ok"] else "FAILED",
                p["total"],
                "".join(cell(p["counts"][s], s) for s in STATES),
                p["duration_ms"] / 1000,
            )
        )
    out.append("</table></div>")

    # ------------------------------------------------------------ 内訳
    #
    # 表の数だけでは「何を固定している検査なのか」が分からない。
    # 全件を出し、あわせて実体（プロジェクトと各パッケージ）へのリンクを置く。
    # 落ちているものを含むプロジェクトだけ開いた状態にする。
    if detailed:
        out.append("<h2>Checks</h2>")
        out.append(
            "<p>Every check this run made, by project. "
            "Each project links to its directory in the repository; "
            "<code>README</code> states what that project fixes.</p>"
        )
        for p in latest["projects"]:
            opened = "" if p["ok"] and not p["counts"]["xfail"] else " open"
            root = p.get("root", "projects")
            tree = suite_tree(latest, root + "/" + p["name"])
            out.append("<details{}>".format(opened))
            out.append(
                "<summary><span class='{}'>{}</span> "
                "<a href='{}'>{}</a> — {} checks "
                "<span class='muted'>({} passed, {} failed, {} known, {} fixed)</span>"
                "</summary>".format(
                    "ok" if p["ok"] else "ng",
                    "ok" if p["ok"] else "FAILED",
                    tree,
                    html.escape(root + "/" + p["name"]),
                    p["total"],
                    p["counts"]["pass"], p["counts"]["fail"],
                    p["counts"]["xfail"], p["counts"]["xpass"],
                )
            )
            src = [
                '<a href="{}">README</a>'.format(
                    suite_blob(latest, "{}/{}/README.md".format(root, p["name"]))
                )
            ]
            src += [
                '<a href="{}/{}"><code>{}</code></a>'.format(tree, pkg, html.escape(pkg))
                for pkg in p.get("packages", [])
            ]
            out.append('<p class="links">' + " &middot; ".join(src) + "</p>")
            out.append('<div class="scroll"><table>')
            out.append("<tr><th>state</th><th>check</th></tr>")
            for c in p.get("checks", []):
                cls = {"pass": "ok", "fail": "ng", "xfail": "warn", "xpass": "ng"}[c["status"]]
                out.append(
                    "<tr><td class='{}'>{}</td><td class='wrap'>{}</td></tr>".format(
                        cls, LABEL[c["status"]], html.escape(c["desc"])
                    )
                )
            out.append("</table></div>")
            out.append("</details>")

    # ------------------------------------------------------ 直すべきもの
    if latest.get("attention"):
        out.append("<h2>Needs attention</h2>")
        out.append('<div class="scroll"><table>')
        out.append("<tr><th>state</th><th>project</th><th>check</th></tr>")
        for c in latest["attention"]:
            out.append(
                "<tr><td class='ng'>{}</td><td>{}</td><td class='wrap'>{}</td></tr>".format(
                    html.escape(c["status"]), html.escape(c["project"]), html.escape(c["desc"])
                )
            )
        out.append("</table></div>")

    # -------------------------------------------------- 既知の未修正事項
    if not detailed and latest.get("known_issues"):
        out.append("<h2>Known unfixed issues</h2>")
        out.append(
            "<p>Checks left failing because the upstream issue is not fixed yet. "
            "When it is fixed they turn <span class='ng'>xpass</span> and the suite fails, "
            "which is the signal to drop the declaration.</p>"
        )
        out.append('<div class="scroll"><table>')
        out.append("<tr><th>project</th><th>check</th></tr>")
        for c in latest["known_issues"]:
            out.append(
                "<tr><td>{}</td><td class='wrap warn'>{}</td></tr>".format(
                    html.escape(c["project"]), html.escape(c["desc"])
                )
            )
        out.append("</table></div>")

    # ------------------------------------------------------------ 成長
    #
    # 下の表は各回の数を全件持つが、100 行の数字を上から下へ辿って
    # 「どこで何が伸びたか」に気づける人はいない。図はそのためにある。
    # 図が示す数はすべて表にもある（図は補助であり、値の唯一の経路ではない）。
    out.append("<h2>Growth</h2>")
    out.append(
        "<p>How the suite grew, run by run. The top plot is the total, split by "
        "where the checks live; the bottom grid is one plot per layer on a shared "
        "scale, so both the arrival of a layer and its size are visible. "
        "Every number here is also a row of the table below.</p>"
    )
    out.append(chart.inline(history, "light"))
    out.append(chart.inline(history, "dark"))

    # ------------------------------------------------------------ 履歴
    out.append("<h2>History</h2>")
    out.append(
        "<p>Each cell is passed / failed / known / fixed for that project. "
        "A dash means the project did not exist at that point.</p>"
    )
    out.append('<div class="scroll"><table>')
    out.append(
        "<tr><th>run</th><th>state</th><th>branch</th><th>commit</th><th>dowel</th>"
        + "".join("<th class='n'>{}</th>".format(html.escape(n)) for n in names)
        + "<th class='n'>total</th></tr>"
    )
    for h in reversed(history):
        by_name = {p["name"]: p for p in h["projects"]}
        cells = []
        for n in names:
            p = by_name.get(n)
            if p is None:
                cells.append('<td class="n zero">—</td>')
                continue
            c = p["counts"]
            cls = "ng" if not p["ok"] else ("warn" if c["xfail"] else "")
            cells.append(
                '<td class="n {}">{}/{}/{}/{}</td>'.format(
                    cls, c["pass"], c["fail"], c["xfail"], c["xpass"]
                )
            )
        label = html.escape(h.get("started_at", "")) or "—"
        if h.get("run_url"):
            label = '<a href="{}">{}</a>'.format(html.escape(h["run_url"]), label)
        out.append(
            "<tr><td class='mono'>{}</td><td class='{}'>{}</td><td>{}</td>"
            "<td class='mono'>{}</td><td class='mono'>{}</td>{}<td class='n'>{}</td></tr>".format(
                label,
                "ok" if h["ok"] else "ng",
                "ok" if h["ok"] else "FAILED",
                html.escape(h.get("branch", "")),
                short(h.get("commit", "")),
                short(h.get("dowel_commit", "")) if h.get("dowel_commit") else html.escape(h.get("dowel_version", "")),
                "".join(cells),
                h["total"],
            )
        )
    out.append("</table></div>")

    out.append(
        "<footer>This page is generated by CI and pushed to the publication branch. "
        "Edits here are overwritten by the next run.</footer>"
    )
    out.append("</main>")
    return "\n".join(out)


def render_page(history, latest=None):
    title = "dowel_examples — check results"
    return (
        "<!doctype html>\n"
        '<html lang="ja">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{title}</title>\n<style>{CSS}</style>\n</head>\n<body>\n"
        + render_site(history, latest)
        + "\n</body>\n</html>\n"
    )


# ------------------------------------------------------------------ 入口


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("run", help="1回の実行をまとめる")
    r.add_argument("--work", default=".work")
    r.add_argument("--out", required=True)

    a = sub.add_parser("append", help="1回分の結果を履歴へ積む")
    a.add_argument("--results", required=True)
    a.add_argument("--history", required=True)

    s = sub.add_parser("site", help="履歴から index.html を作る")
    s.add_argument("--history", required=True)
    s.add_argument("--latest", help="直近の実行の全件（results.json / latest.json）")
    s.add_argument("--out", required=True)

    args = ap.parse_args()

    if args.cmd == "run":
        os.makedirs(args.out, exist_ok=True)
        run = collect(args.work)
        with open(os.path.join(args.out, "summary.md"), "w", encoding="utf-8") as f:
            f.write(render_summary(run))
        with open(os.path.join(args.out, "results.json"), "w", encoding="utf-8") as f:
            json.dump(run, f, ensure_ascii=False, indent=1)
            f.write("\n")
        # 検査そのものの合否は run.sh が返す。ここでは集計だけを行う。
        return 0

    if args.cmd == "append":
        with open(args.results, encoding="utf-8") as f:
            append_history(args.history, json.load(f))
        return 0

    os.makedirs(args.out, exist_ok=True)
    history = []
    if os.path.exists(args.history):
        with open(args.history, encoding="utf-8") as f:
            history = json.load(f)
    latest = None
    if args.latest and os.path.exists(args.latest):
        with open(args.latest, encoding="utf-8") as f:
            latest = json.load(f)
    with open(os.path.join(args.out, "index.html"), "w", encoding="utf-8") as f:
        f.write(render_page(history, latest))
    # 図は頁の中にも埋めるが、単体の SVG としても書き出す。README は
    # publish 用の枝のこのファイルを画像として参照する。
    chart.write(history or ([for_history(latest)] if latest else []), args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
