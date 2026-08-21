#!/usr/bin/env python3
"""履歴を1枚の図にする。

`history.json` は各回の数だけを持つ。表として読めば1回ずつの値は分かるが、
**どこで何が伸びたか**は読み取れない。100 行の数字を上から下へ辿って
「07-29 に apps が現れた」と気づける人はいない。図はそのためにある。

3つの面を上から順に置く。どれも横軸は同じ（左が最初の実行、右が直近）。

    総数        層の系統ごとに積んだ面。上端が総数そのものになる
    未修正      xfail / fail / xpass の推移。docs/20-ci.md 4節が読めと言う列
    層ごと      1層1枚の小さい面。縦軸を共有し、層の大きさも比べられる

層は 27 あり、色で見分けられる数を超えている（7つが上限）。積み上げの色は
**系統**（`projects/` `apps/` `docs`）にだけ使い、層ごとの内訳は小さな面を
並べて示す。色数を増やして解こうとすると、どの色も見分けられなくなる。

明暗2つの版を書き出す。publish の頁も README も明暗の両方で読まれるため、
片方を機械的に反転させるのではなく、それぞれの背景に対して選んだ色を使う。

    chart.py <history.json> <出力ディレクトリ>

`report.py site` から呼ばれる。単体で走らせると同じ2枚を書き出すので、
手元で図だけを作り直して確かめられる。
"""

import html
import json
import math
import os
import sys

# publish 用の枝に置く名前。README がこの名前で参照する。
# `scripts/check-docs.py` が両者の一致を見る。
FILES = {"light": "history.svg", "dark": "history-dark.svg"}

# publish の頁が README から参照される先。
RAW_BASE = "https://raw.githubusercontent.com/sabas0ba/dowel_examples/gh-pages"


# ------------------------------------------------------------------ 色

# 系統の色は dataviz の分類用配色の 1..3 番（blue / orange / aqua）。
# 明暗それぞれ、実際に描かれる背景（#ffffff / #0d1117）に対して検証してある。
#
# 面は FILL の濃さで塗る。塗った結果は元の色ではなく背景と混ざった色になり、
# 実際に読まれるのはそちらであるため、**混ざったあとの色**を検証している。
#
#   明 #4a8cdc / #ee7f52 / #3dbb8e   CVD ΔE 8.6、通常視 20.4
#   暗 #3275c6 / #ba4e24 / #178963   CVD ΔE 8.4、通常視 18.3
#
# 明るい背景では橙と碧が対比 3:1 に届かない。色だけに意味を持たせないよう、
# 凡例と右端の注記を必ず添える（History の表も同じ数を全件持つ）。
FILL = 0.85

# 文字と罫の色は publish の頁（`report.py` の CSS）に揃える。図は頁の中に
# 埋め込まれるため、頁と別の灰色を持ち込むと図だけが浮く。
THEMES = {
    "light": {
        "surface": "#ffffff",
        "ink": "#1a1a1a",
        "ink2": "#555555",
        "muted": "#767676",
        "grid": "#e6e6e6",
        "axis": "#c9c9c9",
        "series": {"projects": "#2a78d6", "apps": "#eb6834", "docs": "#1baf7a"},
    },
    "dark": {
        "surface": "#0d1117",
        "ink": "#e6e6e6",
        "ink2": "#b6bdc6",
        "muted": "#9198a1",
        "grid": "#21262d",
        "axis": "#30363d",
        "series": {"projects": "#3987e5", "apps": "#d95926", "docs": "#199e70"},
    },
}

# 状態の色は分類用とは別の組（dataviz の status）。系統の色と取り違えない
# ようにするため、明暗で同じ値を使う。明るい背景では warning の対比が
# 足りないため、線だけに意味を持たせず必ず値を添える。
STATUS = {"xfail": "#fab219", "fail": "#d03b3b", "xpass": "#0ca30c"}
STATUS_LABEL = {"xfail": "known", "fail": "failed", "xpass": "fixed"}

FONT = ('system-ui, -apple-system, "Segoe UI", "Helvetica Neue", '
        '"Hiragino Sans", "Noto Sans JP", sans-serif')

# 系統。積む順は下から上。`projects/` が最も大きいため下に置く。
GROUPS = ["projects", "apps", "docs"]
GROUP_LABEL = {"projects": "projects/", "apps": "apps/", "docs": "docs"}


def group_of(project):
    """その層がどの系統に属するか。

    `docs` は文書の検査であって `projects/` の下にディレクトリを持たない。
    履歴では root が既定の `projects` になっているため、名前で分ける。

    知らない root は `projects` に寄せる。系統を増やすと色が要るが、色を
    その場で作ると見分けられない色が混ざる（`GROUPS` を増やすのが正しい
    直し方である）。寄せずに落とすと、積み上げの上端が総数と合わなくなる。
    """
    if project.get("name") == "docs":
        return "docs"
    root = project.get("root") or "projects"
    return root if root in GROUPS else "projects"


# ------------------------------------------------------------------ 版取り

# 図の骨格。1か所で決め、各面はここから位置を取る。
W = 920
PLOT_L = 56           # 縦軸の目盛りの幅
PLOT_R = 800          # 右端。ここから先は直接の注記に使う
LABEL_R = W - 24

TOTAL_TOP, TOTAL_BOTTOM = 118, 358      # 総数の面
STATUS_TOP, STATUS_BOTTOM = 404, 460    # 未修正の面
AXIS_Y = STATUS_BOTTOM + 16             # 横軸は2つの面で共有し、下に1度だけ置く
LEGEND_X = 430                          # 凡例は見出しの行に置く（1行を節約する）
SMALL_TOP = 526                         # 層ごとの面の始まり
SMALL_COLS = 7
SMALL_PLOT_H = 34
SMALL_CELL_H = 60


def nice_scale(vmax, ticks=5):
    """目盛りが読める数で切れるように上端と刻みを決める。"""
    if vmax <= 0:
        return 1, 1
    raw = vmax / float(ticks)
    exp = math.floor(math.log10(raw)) if raw > 0 else 0
    base = 10.0 ** exp
    step = 10 * base
    for m in (1, 2, 2.5, 5, 10):
        if raw <= m * base:
            step = m * base
            break
    top = step * math.ceil(vmax / step)
    return top, step


def comma(n):
    return "{:,}".format(int(n))


def esc(s):
    return html.escape(str(s), quote=True)


def text(x, y, s, fill, size=11, weight=400, anchor="start", extra=""):
    return (
        '<text x="{:.1f}" y="{:.1f}" fill="{}" font-size="{}" '
        'font-weight="{}" text-anchor="{}"{}>{}</text>'
    ).format(x, y, fill, size, weight, anchor, extra, esc(s))


# ------------------------------------------------------------------ 系列取り


def series(history):
    """履歴を、描くのに必要な形へ畳む。

    層は途中で増える。その回に無かった層は 0 とする（無い層を飛ばすと
    横軸が層ごとにずれ、面が比べられなくなる）。
    """
    runs = []
    for h in history:
        by_group = {g: 0 for g in GROUPS}
        by_name = {}
        for p in h.get("projects", []):
            by_group[group_of(p)] = by_group.get(group_of(p), 0) + p.get("total", 0)
            by_name[p["name"]] = p
        runs.append(
            {
                "date": (h.get("started_at") or "")[:10],
                "total": h.get("total", 0),
                "totals": h.get("totals", {}),
                "groups": by_group,
                "by_name": by_name,
                "ok": h.get("ok", True),
            }
        )

    # 層の並び。`projects/` を番号順、次に `apps/`、最後に `docs`。
    # README の並びに合わせる。読み手が同じ順で覚えているため。
    #
    # 系統は「その層が最後に現れた回」のもので決める。消えた層も履歴には
    # 残るため、直近の回だけを見ると系統が分からず、色が既定に落ちる。
    names = {}
    for r in runs:
        for name, p in r["by_name"].items():
            names[name] = group_of(p)
    order = [n for g in GROUPS for n in sorted(x for x, y in names.items() if y == g)]
    return runs, order, names


# ------------------------------------------------------------------ 描画


def render(history, theme_name):
    """図の中身（`<g>` の並び）を返す。`<svg>` の枠は付けない。"""
    t = THEMES[theme_name]
    runs, order, groups = series(history)
    if not runs:
        return text(PLOT_L, 40, "No run yet.", THEMES[theme_name]["muted"]), 72

    out = [_header(t, runs)]

    # 1回しか無いときは、その1点を面の両端に置いて平らに描く。1点のままだと
    # 積み上げは幅を持たず、層ごとの面は三角形になって「増えて減った」と
    # 読める。動きが無いことは、平らであることで示す。
    single = len(runs) == 1
    if single:
        runs = runs + [dict(runs[0])]
    n = len(runs)

    def x(i):
        return PLOT_L + (PLOT_R - PLOT_L) * i / float(n - 1)

    out.append(_totals_panel(t, runs, x, n))
    out.append(_status_panel(t, runs, x, n))
    out.append(_x_axis(t, runs, x, n, single))
    body, height = _small_multiples(t, runs, order, groups, n)
    out.append(body)
    out.append(
        text(PLOT_L, height + 16,
             "Generated by CI from history.json on the publication branch. "
             "The same numbers, run by run, are in the History table.",
             t["muted"], size=10)
    )
    return "\n".join(out), height + 32


def _header(t, runs):
    """総数を1つの数として出す。図の見出しにあたる。"""
    latest, first = runs[-1], runs[0]
    grown = latest["total"] - first["total"]
    span = "{} run{}".format(len(runs), "" if len(runs) == 1 else "s")
    if first["date"] and latest["date"]:
        span += "  ·  {} → {}".format(first["date"], latest["date"])
    delta = "+{} since the first run".format(comma(grown)) if grown > 0 else ""
    return "\n".join([
        text(PLOT_L, 22, "checks", t["muted"], size=11, weight=600,
             extra=' letter-spacing="0.06em"'),
        text(PLOT_L, 56, comma(latest["total"]), t["ink"], size=34, weight=600),
        text(PLOT_L, 74, "  ·  ".join(x for x in (span, delta) if x), t["muted"], size=11),
    ])


def _totals_panel(t, runs, x, n):
    """系統ごとに積んだ面。上端が総数になる。"""
    out = []
    top, step = nice_scale(max(r["total"] for r in runs))
    h = TOTAL_BOTTOM - TOTAL_TOP

    def y(v):
        return TOTAL_BOTTOM - h * (v / float(top))

    out.append(text(PLOT_L, TOTAL_TOP - 14,
                    "Total checks, stacked by layer group", t["ink"], size=12, weight=600))
    out.append(_legend(t))

    # 目盛り。罫は背景から一段だけ離す。
    v = 0.0
    while v <= top + 1e-9:
        out.append(
            '<line x1="{:.1f}" y1="{:.1f}" x2="{:.1f}" y2="{:.1f}" stroke="{}" '
            'stroke-width="1"/>'.format(PLOT_L, y(v), PLOT_R, y(v),
                                        t["axis"] if v == 0 else t["grid"])
        )
        out.append(text(PLOT_L - 8, y(v) + 3.5, comma(v), t["muted"], size=10,
                        anchor="end", extra=' font-variant-numeric="tabular-nums"'))
        v += step

    # 面。下から積む。境目は背景色の 2px で分ける（枠線は引かない）。
    lower = [TOTAL_BOTTOM] * n
    cum = [0] * n
    edges = []
    for g in GROUPS:
        upper = []
        for i, r in enumerate(runs):
            cum[i] += r["groups"].get(g, 0)
            upper.append(y(cum[i]))
        pts_u = " ".join("{:.1f},{:.1f}".format(x(i), upper[i]) for i in range(n))
        pts_l = " ".join("{:.1f},{:.1f}".format(x(i), lower[i]) for i in range(n - 1, -1, -1))
        out.append(
            '<polygon points="{} {}" fill="{}" fill-opacity="{}"/>'.format(
                pts_u, pts_l, t["series"][g], FILL)
        )
        edges.append(list(upper))
        lower = list(upper)

    for e in edges[:-1]:
        out.append(
            '<polyline points="{}" fill="none" stroke="{}" stroke-width="2"/>'.format(
                " ".join("{:.1f},{:.1f}".format(x(i), e[i]) for i in range(n)), t["surface"])
        )

    # 上端は総数そのもの。系統ではないので中立の色で引き、終端に値を置く。
    out.append(
        '<polyline points="{}" fill="none" stroke="{}" stroke-width="2" '
        'stroke-linejoin="round"/>'.format(
            " ".join("{:.1f},{:.1f}".format(x(i), edges[-1][i]) for i in range(n)), t["ink2"])
    )
    out.append('<circle cx="{:.1f}" cy="{:.1f}" r="4" fill="{}" stroke="{}" '
               'stroke-width="2"/>'.format(x(n - 1), edges[-1][-1], t["ink2"], t["surface"]))
    out.append(text(PLOT_R + 12, edges[-1][-1] + 4, comma(runs[-1]["total"]) + " total",
                    t["ink"], size=11, weight=600))

    # 帯ごとの注記を右端に置く。置けるのは、帯に厚みがあり、かつ既に置いた
    # 注記と重ならないときだけ。置けなかった系統は凡例が引き受ける。
    placed = [edges[-1][-1] + 4]
    bottom = TOTAL_BOTTOM
    for gi, g in enumerate(GROUPS):
        band_top = edges[gi][-1]
        at = (bottom + band_top) / 2 + 4
        if bottom - band_top >= 15 and all(abs(at - p) >= 14 for p in placed):
            out.append(text(PLOT_R + 12, at,
                            "{} {}".format(GROUP_LABEL[g], comma(runs[-1]["groups"][g])),
                            t["ink2"], size=10.5))
            placed.append(at)
        bottom = band_top

    out.append(_hover(t, runs, x, n, TOTAL_TOP, TOTAL_BOTTOM, group_readout))
    return "\n".join(out)


def _legend(t):
    """凡例。2系列以上には必ず置く。色だけに identity を持たせないための channel。

    数は右端の直接の注記が持つ。ここは名前と色の対応だけを引き受ける。
    """
    out = []
    cx = LEGEND_X
    for g in GROUPS:
        out.append('<rect x="{:.1f}" y="{:.1f}" width="10" height="10" rx="2" '
                   'fill="{}" fill-opacity="{}"/>'.format(
                       cx, TOTAL_TOP - 23, t["series"][g], FILL))
        out.append(text(cx + 15, TOTAL_TOP - 14, GROUP_LABEL[g], t["ink2"], size=10.5))
        cx += 28 + 6.3 * len(GROUP_LABEL[g])
    return "\n".join(out)


def _status_panel(t, runs, x, n):
    """未修正・退行・修正済みの推移。

    docs/20-ci.md 4節が「History で見たいのは列の動きである」と言う、その列。
    一度も 0 以外にならなかった系列は線を引かない。0 の線が3本重なっても
    読めないためである。そのことは凡例に書く（線が無いのと、系列が無いのとは
    違う）。
    """
    out = []
    out.append(text(PLOT_L, STATUS_TOP - 14,
                    "Checks failing on purpose, regressions, and fixes",
                    t["ink"], size=12, weight=600))

    drawn = [s for s in ("xfail", "fail", "xpass")
             if any(r["totals"].get(s, 0) for r in runs)]
    vmax = max([r["totals"].get(s, 0) for r in runs for s in ("xfail", "fail", "xpass")] or [0])
    top, _ = nice_scale(vmax, ticks=3)
    h = STATUS_BOTTOM - STATUS_TOP

    def y(v):
        return STATUS_BOTTOM - h * (v / float(top))

    for v, color in ((0, t["axis"]), (top, t["grid"])):
        out.append('<line x1="{:.1f}" y1="{:.1f}" x2="{:.1f}" y2="{:.1f}" stroke="{}" '
                   'stroke-width="1"/>'.format(PLOT_L, y(v), PLOT_R, y(v), color))
        out.append(text(PLOT_L - 8, y(v) + 3.5, comma(v), t["muted"], size=10,
                        anchor="end", extra=' font-variant-numeric="tabular-nums"'))

    for s in drawn:
        pts = " ".join("{:.1f},{:.1f}".format(x(i), y(r["totals"].get(s, 0)))
                       for i, r in enumerate(runs))
        out.append('<polyline points="{}" fill="none" stroke="{}" stroke-width="2" '
                   'stroke-linejoin="round" stroke-linecap="round"/>'.format(pts, STATUS[s]))
        last = runs[-1]["totals"].get(s, 0)
        out.append('<circle cx="{:.1f}" cy="{:.1f}" r="4" fill="{}" stroke="{}" '
                   'stroke-width="2"/>'.format(x(n - 1), y(last), STATUS[s], t["surface"]))

    # 明るい背景では状態色そのものの対比が足りない。線だけに意味を持たせず、
    # 名前と値をここに置く（色は名前の脇の点が持つ）。一度も 0 以外に
    # ならなかった系列は線が無いため、そのことも書く。
    cx = LEGEND_X
    for s in ("xfail", "fail", "xpass"):
        label = "{} {}".format(STATUS_LABEL[s], runs[-1]["totals"].get(s, 0))
        if s not in drawn:
            label += " (none yet)"
        out.append('<circle cx="{:.1f}" cy="{:.1f}" r="4" fill="{}"/>'.format(
            cx + 5, STATUS_TOP - 18, STATUS[s]))
        out.append(text(cx + 15, STATUS_TOP - 14, label, t["ink2"], size=10.5))
        cx += 28 + 6.3 * len(label)

    out.append(_hover(t, runs, x, n, STATUS_TOP, STATUS_BOTTOM, status_readout))
    return "\n".join(out)


def _small_multiples(t, runs, order, groups, n):
    """層ごとに1枚。縦軸を共有するため、層の大きさもそのまま比べられる。

    27 層を1つの積み上げに詰めると、どの帯がどれか分からなくなる。
    分けて並べ、色は系統だけに使う。
    """
    out = []
    out.append(text(PLOT_L, SMALL_TOP - 14,
                    "Each layer on the same scale — when it appeared, and how it grew",
                    t["ink"], size=12, weight=600))

    gutter = 12
    grid_w = LABEL_R - PLOT_L
    cell_w = (grid_w - gutter * (SMALL_COLS - 1)) / float(SMALL_COLS)
    vmax = max([p.get("total", 0) for r in runs for p in r["by_name"].values()] or [1])
    top, _ = nice_scale(vmax)

    rows = int(math.ceil(len(order) / float(SMALL_COLS)))
    for k, name in enumerate(order):
        col, row = k % SMALL_COLS, k // SMALL_COLS
        ox = PLOT_L + col * (cell_w + gutter)
        oy = SMALL_TOP + row * SMALL_CELL_H
        base = oy + 14 + SMALL_PLOT_H
        color = t["series"][groups[name]]

        counts = [r["by_name"].get(name, {}).get("total", 0) for r in runs]
        pts = " ".join("{:.1f},{:.1f}".format(
            ox + cell_w * i / float(n - 1),
            base - SMALL_PLOT_H * (c / float(top))) for i, c in enumerate(counts))

        out.append('<g><title>{}</title>'.format(
            esc("{}: {} checks now, first seen {}".format(
                name, counts[-1], _first_seen(runs, counts)))))
        out.append(text(ox, oy + 9, name, t["ink2"], size=10))
        out.append(text(ox + cell_w, oy + 9, comma(counts[-1]), t["muted"], size=10,
                        anchor="end", extra=' font-variant-numeric="tabular-nums"'))
        out.append('<polygon points="{:.1f},{:.1f} {} {:.1f},{:.1f}" fill="{}" '
                   'fill-opacity="{}"/>'.format(
                       ox, base, pts, ox + cell_w, base, color, FILL))
        out.append('<line x1="{:.1f}" y1="{:.1f}" x2="{:.1f}" y2="{:.1f}" stroke="{}" '
                   'stroke-width="1"/>'.format(ox, base, ox + cell_w, base, t["axis"]))
        out.append('</g>')

    bottom = SMALL_TOP + rows * SMALL_CELL_H
    out.append(text(PLOT_L, bottom + 2,
                    "Same vertical scale everywhere: 0 to {} checks.".format(comma(top)),
                    t["muted"], size=10))
    return "\n".join(out), bottom + 6


def _first_seen(runs, counts):
    for i, c in enumerate(counts):
        if c:
            return runs[i]["date"] or "run {}".format(i + 1)
    return "never"


def _x_axis(t, runs, x, n, single=False):
    """横軸。上の2つの面が同じ尺度を使うため、一番下に1度だけ置く。

    全部の日付は置かない。端と、その間のいくつかだけを置く。
    """
    out = []
    if single:
        out.append(text((PLOT_L + PLOT_R) / 2, AXIS_Y, runs[0]["date"] or "—",
                        t["muted"], size=10, anchor="middle"))
        note = "The only run so far. The plots go flat until there is a second one."
    else:
        for i in sorted({0, n - 1} | {round(i * (n - 1) / 4.0) for i in range(5)}):
            anchor = "start" if i == 0 else ("end" if i == n - 1 else "middle")
            out.append(text(x(i), AXIS_Y, runs[i]["date"] or "—", t["muted"],
                            size=10, anchor=anchor))
        note = "One point per run, oldest first. Both plots above share this axis."
    out.append(text(PLOT_L, AXIS_Y + 15, note, t["muted"], size=10))
    return "\n".join(out)


def group_readout(run):
    return "{}  ·  {} checks  ·  {}".format(
        run["date"] or "?", comma(run["total"]),
        ", ".join("{} {}".format(GROUP_LABEL[g], run["groups"].get(g, 0)) for g in GROUPS))


def status_readout(run):
    return "{}  ·  {}".format(
        run["date"] or "?",
        ", ".join("{} {}".format(STATUS_LABEL[s], run["totals"].get(s, 0))
                  for s in ("xfail", "fail", "xpass")))


def _hover(t, runs, x, n, top, bottom, readout):
    """指したところの値を出す層。

    publish の頁には脚本を1行も置いていない。`<title>` なら追加のものは要らず、
    表（History）が同じ値を全件持っているため、これは補助にとどまる。
    """
    out = []
    span = (PLOT_R - PLOT_L) / float(max(n - 1, 1))
    for i, r in enumerate(runs):
        left = max(PLOT_L, x(i) - span / 2)
        right = min(PLOT_R, x(i) + span / 2)
        out.append(
            '<rect x="{:.1f}" y="{:.1f}" width="{:.1f}" height="{:.1f}" fill="transparent">'
            "<title>{}</title></rect>".format(left, top, max(right - left, 1), bottom - top,
                                              esc(readout(r)))
        )
    return "\n".join(out)


# ------------------------------------------------------------------ 書き出し


def document(history, theme_name):
    """単体の SVG。README から画像として参照される版。"""
    t = THEMES[theme_name]
    body, height = render(history, theme_name)
    total = history[-1].get("total", 0) if history else 0
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        'viewBox="0 0 {w} {h}" role="img" '
        'aria-label="{label}" font-family=\'{font}\'>\n'
        "<title>{label}</title>\n"
        '<rect width="{w}" height="{h}" fill="{bg}"/>\n'
        "{body}\n</svg>\n"
    ).format(
        w=W, h=int(height), bg=t["surface"], font=FONT, body=body,
        label=esc("dowel_examples — {} checks over {} run{}, by layer".format(
            comma(total), len(history), "" if len(history) == 1 else "s")),
    )


def inline(history, theme_name):
    """publish の頁へそのまま埋める版。頁の側が明暗を切り替える。"""
    body, height = render(history, theme_name)
    return (
        '<svg class="chart {cls}" xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 {w} {h}" role="img" aria-label="{label}">\n{body}\n</svg>'
    ).format(cls=theme_name, w=W, h=int(height), body=body,
             label=esc("Checks over time, by layer group and by layer"))


def write(history, out_dir):
    """明暗2枚を書き出す。書いた名前を返す。"""
    written = []
    for theme_name, filename in FILES.items():
        path = os.path.join(out_dir, filename)
        with open(path, "w", encoding="utf-8") as f:
            f.write(document(history, theme_name))
        written.append(filename)
    return written


def main():
    if len(sys.argv) != 3:
        print("usage: chart.py <history.json> <out-dir>", file=sys.stderr)
        return 2
    with open(sys.argv[1], encoding="utf-8") as f:
        history = json.load(f)
    os.makedirs(sys.argv[2], exist_ok=True)
    for name in write(history, sys.argv[2]):
        print(os.path.join(sys.argv[2], name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
