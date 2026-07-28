#!/usr/bin/env bash
#
# テストスイートの入口。
#
#   ./run.sh                 全プロジェクトを走らせる
#   ./run.sh 02-config       名前（または接頭辞）で絞る
#
# dowel バイナリの探索順。
#
#   1. 環境変数 DOWEL
#   2. PATH 上の dowel
#   3. ../dowel/target/release/dowel（隣に本体を clone している場合）
#
# プロジェクトの実体は変更しない。.work/ へ複製してから走らせる
# （dowel 本体の規約に合わせる。docs/00-design.md 4節）。

set -uo pipefail

SUITE_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK="$SUITE_ROOT/.work"
RESULTS="$WORK/results.tsv"     # 1 検査 1 行: status \t project \t desc
PROJECTS="$WORK/projects.tsv"   # 1 プロジェクト 1 行: name \t ms \t pass \t fail \t xfail \t xpass
META="$WORK/meta.tsv"           # key \t value

# 経過時間。bash 5 の EPOCHREALTIME を使い、無い場合は秒に落とす。
now_ms() {
    if [ -n "${EPOCHREALTIME:-}" ]; then
        local t=${EPOCHREALTIME/,/.}
        printf '%s' "$(( ${t%.*} * 1000 + 10#${t#*.} / 1000 ))"
    else
        printf '%s' "$(( $(date +%s) * 1000 ))"
    fi
}

# ------------------------------------------------------------ dowel の解決

resolve_dowel() {
    if [ -n "${DOWEL:-}" ]; then
        command -v "$DOWEL" >/dev/null 2>&1 && { command -v "$DOWEL"; return 0; }
        [ -x "$DOWEL" ] && { printf '%s' "$DOWEL"; return 0; }
        printf 'DOWEL=%s は実行できない\n' "$DOWEL" >&2
        return 1
    fi
    if command -v dowel >/dev/null 2>&1; then command -v dowel; return 0; fi
    local sibling="$SUITE_ROOT/../dowel/target/release/dowel"
    if [ -x "$sibling" ]; then (cd "$(dirname "$sibling")" && printf '%s/%s' "$PWD" dowel); return 0; fi
    cat >&2 <<'EOF'
dowel が見つからない。次のいずれかを行う。

  DOWEL=/path/to/dowel ./run.sh
  cargo build --release   # 隣の ../dowel で
EOF
    return 1
}

DOWEL=$(resolve_dowel) || exit 2
export DOWEL

# ------------------------------------------------------------ 前提の確認

for tool in cc ninja jq; do
    command -v "$tool" >/dev/null 2>&1 || {
        printf '%s が無い。C コンパイラ・ninja・jq が要る。\n' "$tool" >&2
        exit 2
    }
done

# ------------------------------------------------------------ 対象の決定

cd "$SUITE_ROOT"
mapfile -t all < <(find projects -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

selected=()
if [ $# -eq 0 ]; then
    selected=("${all[@]}")
else
    for pat in "$@"; do
        found=0
        for p in "${all[@]}"; do
            case $p in "$pat"*) selected+=("$p"); found=1 ;; esac
        done
        [ "$found" = 1 ] || { printf 'そのようなプロジェクトは無い: %s\n' "$pat" >&2; exit 2; }
    done
fi

# ------------------------------------------------------------ 実行

# _record_project <name> <開始時刻ms> <この節の開始行>
# そのプロジェクトが積んだ結果だけを数え、1行にまとめる。
_record_project() {
    local name=$1 started=$2 before=$3
    local slice p f xf xp
    slice=$(tail -n "+$((before + 1))" "$RESULTS" | cut -f1)
    p=$(printf '%s\n'  "$slice" | grep -c '^pass$')
    f=$(printf '%s\n'  "$slice" | grep -c '^fail$')
    xf=$(printf '%s\n' "$slice" | grep -c '^xfail$')
    xp=$(printf '%s\n' "$slice" | grep -c '^xpass$')
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$name" "$(( $(now_ms) - started ))" "$p" "$f" "$xf" "$xp" >>"$PROJECTS"
}

rm -rf "$WORK"
mkdir -p "$WORK"
: >"$RESULTS"
: >"$PROJECTS"

dowel_version=$("$DOWEL" --version)
cc_version=$(cc --version 2>/dev/null | head -1)
{
    printf 'dowel_version\t%s\n' "$dowel_version"
    printf 'dowel_path\t%s\n'    "$DOWEL"
    printf 'cc\t%s\n'            "$cc_version"
    printf 'ninja\t%s\n'         "$(ninja --version 2>/dev/null)"
    printf 'started_at\t%s\n'    "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'commit\t%s\n'        "$(git -C "$SUITE_ROOT" rev-parse HEAD 2>/dev/null)"
    printf 'branch\t%s\n'        "$(git -C "$SUITE_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
} >"$META"

printf 'dowel: %s (%s)\n' "$DOWEL" "$dowel_version"
printf 'cc:    %s\n\n' "$cc_version"

for name in "${selected[@]}"; do
    src="$SUITE_ROOT/projects/$name"
    dst="$WORK/$name"
    printf '%s\n' "$name"

    before=$(wc -l <"$RESULTS")
    started=$(now_ms)

    cp -r "$src" "$dst"

    if [ ! -f "$dst/expect.sh" ]; then
        printf '  FAIL expect.sh が無い\n'
        printf 'fail\t%s\t%s\n' "$name" "expect.sh が無い" >>"$RESULTS"
        _record_project "$name" "$started" "$before"
        continue
    fi

    (
        export PROJECT="$name" RESULTS="$RESULTS" SUITE_ROOT="$SUITE_ROOT"
        cd "$dst" || exit 1
        # shellcheck source=lib/harness.sh
        . "$SUITE_ROOT/lib/harness.sh"
        # shellcheck disable=SC1091
        . ./expect.sh
    )
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf '  FAIL expect.sh が異常終了した (rc=%s)\n' "$rc"
        printf 'fail\t%s\t%s\n' "$name" "expect.sh が異常終了した (rc=$rc)" >>"$RESULTS"
    fi

    # 実体を汚していないことの確認。dowel 本体の
    # every_fixture_is_left_clean_in_the_repository と同じ趣旨。
    stray=$(find "$src" \( -name '.dowel' -o -name 'compile_commands.json' \) -print -quit)
    if [ -n "$stray" ]; then
        printf '  FAIL 実体に成果物が残っている: %s\n' "$stray"
        printf 'fail\t%s\t%s\n' "$name" "実体に成果物が残っている" >>"$RESULTS"
    fi

    _record_project "$name" "$started" "$before"
    printf '\n'
done

# ------------------------------------------------------------ 要約

pass=$(grep -c '^pass' "$RESULTS")
fail=$(grep -c '^fail' "$RESULTS")
xfail=$(grep -c '^xfail' "$RESULTS")
xpass=$(grep -c '^xpass' "$RESULTS")

printf '合計 %s 件: 成功 %s / 失敗 %s / 既知の未修正 %s / 修正済み %s\n' \
    "$((pass + fail + xfail + xpass))" "$pass" "$fail" "$xfail" "$xpass"

if [ "$fail" -gt 0 ] || [ "$xpass" -gt 0 ]; then
    printf '\n落ちた検査:\n'
    grep -E '^(fail|xpass)' "$RESULTS" | awk -F'\t' '{ printf "  %-6s %-16s %s\n", $1, $2, $3 }'
fi

[ "$fail" -eq 0 ] && [ "$xpass" -eq 0 ]
