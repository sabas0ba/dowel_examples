#!/usr/bin/env bash
#
# 検証に用いる dowel の版を進める。
#
#   scripts/bump-dowel.sh            # 本家の main の先端へ
#   scripts/bump-dowel.sh <commit>   # 指定した版へ
#
# `dowel-ref` を書き換え、文書が引用している版も併せて置き換える。
# 両者が一致することは `docs` の段が検査しており、片方だけ直すと落ちる
# （scripts/check-docs.py の `the dowel revision quoted in the documentation
# matches dowel-ref`）。
#
# 変更が要らない場合は何も書かずに終わる。呼び出し側は `git diff --quiet` で
# 判断できる。
#
# 版を進めること自体は機械にできるが、進めてよいかは検査の結果で決まる。
# したがって本スクリプトはコミットも push もしない。CI はこれを走らせた結果を
# pull request にするだけであり、合否はその pull request の検査が決める。

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
UPSTREAM=${DOWEL_REPO_URL:-https://github.com/sabas0ba/dowel}
REF_FILE="$ROOT/dowel-ref"

current=$(grep -v '^[[:space:]]*#' "$REF_FILE" | grep -v '^[[:space:]]*$' | tail -1 | tr -d '[:space:]')

if [ $# -ge 1 ]; then
    wanted=$1
else
    wanted=$(git ls-remote "$UPSTREAM" HEAD | cut -f1)
fi

case $wanted in
    [0-9a-f]*) [ ${#wanted} -eq 40 ] || { printf 'not a full commit: %s\n' "$wanted" >&2; exit 2; } ;;
    *) printf 'not a commit: %s\n' "$wanted" >&2; exit 2 ;;
esac

if [ "$current" = "$wanted" ]; then
    printf 'already at %s\n' "$current"
    exit 0
fi

printf '%s -> %s\n' "$current" "$wanted"

# `dowel-ref` の版そのもの。
python3 - "$REF_FILE" "$current" "$wanted" <<'PY'
import pathlib, sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(path)
p.write_text(p.read_text(encoding="utf-8").replace(old, new), encoding="utf-8")
PY

# 文書が引用している版。追跡している Markdown だけを対象にする
# （作業ディレクトリに置かれた別のものを書き換えないため）。
git -C "$ROOT" ls-files -z '*.md' | while IFS= read -r -d '' f; do
    python3 - "$ROOT/$f" "$current" "$wanted" <<'PY'
import pathlib, sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(path)
s = p.read_text(encoding="utf-8")
if old in s:
    p.write_text(s.replace(old, new), encoding="utf-8")
    print(f"  {path}")
PY
done
