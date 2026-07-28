#!/usr/bin/env bash
#
# 検査結果を掲示用の枝へ押し込む。
#
#   scripts/publish-pages.sh <枝> <results.json>
#
# 枝が無ければ作る。既にあれば履歴（history.json）へ追記し、index.html を
# 作り直す。表の実体は履歴であり、index.html はその描画にすぎない。
#
# 掲示用の枝は生成物だけを持つ。ソースは持たない。掲示を作り直したい場合は
# 枝を消して、次の実行を待てばよい（history.json は失われる）。
#
# 押し込みが競合した場合は、履歴を取り直してから積み直す。掲示の内容は
# 「取り直した履歴 + 今回の結果」であり、他の実行の記録を捨てない。

set -euo pipefail

BRANCH=${1:?掲示用の枝を指定する}
RESULTS=${2:?results.json のパスを指定する}

SUITE_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=${RUNNER_TEMP:-/tmp}/publish-pages
ATTEMPTS=3

[ -f "$RESULTS" ] || { printf '%s が無い\n' "$RESULTS" >&2; exit 1; }
RESULTS=$(cd "$(dirname "$RESULTS")" && printf '%s/%s' "$PWD" "$(basename "$RESULTS")")

# PAGES_REMOTE は手元で経路を確かめるための差し替え口である。
# CI では設定しない。
if [ -n "${PAGES_REMOTE:-}" ]; then
    REMOTE=$PAGES_REMOTE
else
    : "${GITHUB_TOKEN:?GITHUB_TOKEN が要る}"
    : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY が要る}"
    REMOTE="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}"
fi

for attempt in $(seq 1 "$ATTEMPTS"); do
    rm -rf "$WORK"

    # 既にあれば取ってくる。無ければその枝で新しく始める。
    if git clone --quiet --depth 1 --branch "$BRANCH" "$REMOTE" "$WORK" 2>/dev/null; then
        printf '掲示用の枝 %s を取得した\n' "$BRANCH"
    else
        printf '掲示用の枝 %s が無いので作る\n' "$BRANCH"
        git init --quiet --initial-branch="$BRANCH" "$WORK"
        git -C "$WORK" remote add origin "$REMOTE"
    fi

    git -C "$WORK" config user.name  "github-actions[bot]"
    git -C "$WORK" config user.email "41898282+github-actions[bot]@users.noreply.github.com"

    # 履歴へ積み、表を作り直す。表の実体は履歴であり、index.html は描画にすぎない。
    cp "$RESULTS" "$WORK/latest.json"
    python3 "$SUITE_ROOT/scripts/report.py" append \
        --results "$RESULTS" --history "$WORK/history.json"
    python3 "$SUITE_ROOT/scripts/report.py" site \
        --history "$WORK/history.json" --latest "$WORK/latest.json" --out "$WORK"

    # GitHub Pages が下線で始まる名前を落とさないようにする。
    : >"$WORK/.nojekyll"

    git -C "$WORK" add -A
    if git -C "$WORK" diff --cached --quiet; then
        printf '掲示に差分が無い\n'
        exit 0
    fi

    git -C "$WORK" commit --quiet -m "$(printf 'chore: 検査結果を掲示する (%s)\n\n%s' \
        "$(python3 -c 'import json,sys;r=json.load(open(sys.argv[1]));print(r.get("commit","")[:12] or "local")' "$RESULTS")" \
        "run ${GITHUB_RUN_ID:-local} / attempt ${GITHUB_RUN_ATTEMPT:-1}")"

    if git -C "$WORK" push --quiet origin "$BRANCH"; then
        printf '掲示用の枝 %s へ押し込んだ\n' "$BRANCH"
        exit 0
    fi

    printf '押し込みに失敗した（%s/%s）。履歴を取り直して積み直す\n' "$attempt" "$ATTEMPTS" >&2
    sleep $(( attempt * 3 ))
done

printf '%s 回試したが押し込めなかった\n' "$ATTEMPTS" >&2
exit 1
