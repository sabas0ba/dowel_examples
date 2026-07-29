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
PACKAGES="$WORK/packages.tsv"   # 1 パッケージ 1 行: project \t パッケージの相対パス
META="$WORK/meta.tsv"           # key \t value

# 検査手続きの共通部分。ここでは now_ms だけを使う。プロジェクトごとの
# 実行は下の部分シェルで改めて読み込む（そちらが本来の利用者である）。
# shellcheck source=lib/harness.sh
. "$SUITE_ROOT/lib/harness.sh"

# ------------------------------------------------------------ dowel の解決

resolve_dowel() {
    if [ -n "${DOWEL:-}" ]; then
        command -v "$DOWEL" >/dev/null 2>&1 && { command -v "$DOWEL"; return 0; }
        [ -x "$DOWEL" ] && { printf '%s' "$DOWEL"; return 0; }
        printf 'DOWEL=%s is not executable\n' "$DOWEL" >&2
        return 1
    fi
    if command -v dowel >/dev/null 2>&1; then command -v dowel; return 0; fi
    local sibling="$SUITE_ROOT/../dowel/target/release/dowel"
    if [ -x "$sibling" ]; then (cd "$(dirname "$sibling")" && printf '%s/%s' "$PWD" dowel); return 0; fi
    cat >&2 <<'EOF'
cannot find dowel. do one of:

  DOWEL=/path/to/dowel ./run.sh
  cargo build --release   # in ../dowel, next to this repository
EOF
    return 1
}

DOWEL=$(resolve_dowel) || exit 2
export DOWEL

# dowelup と dowel の作業木。09-acquisition だけが使う。
#
# dowelup は取得をソースからのビルドとして行うため（ADR-0013）、検査には
# 上流にあたる git リポジトリが要る。実際の上流には触れず、ここで見つけた
# ものを手元へ複製して相手にする。
#
# 見つからない場合は始めない。環境によって走る検査が変わると、
# 結果を過去の実行と比べられなくなる。
resolve_dowelup() {
    if [ -n "${DOWELUP:-}" ]; then printf '%s' "$DOWELUP"; return 0; fi
    local beside; beside=$(dirname "$DOWEL")/dowelup
    [ -x "$beside" ] && { printf '%s' "$beside"; return 0; }
    command -v dowelup 2>/dev/null && return 0
    return 1
}

resolve_dowel_src() {
    local c
    for c in "${DOWEL_SRC:-}" "$SUITE_ROOT/.dowel-src" "$SUITE_ROOT/../dowel" \
             "$(dirname "$DOWEL")/../.."; do
        [ -n "$c" ] || continue
        [ -d "$c/.git" ] && (cd "$c" && pwd) && return 0
    done
    return 1
}

DOWELUP=$(resolve_dowelup) || {
    cat >&2 <<'EOF'
cannot find dowelup. it is built alongside dowel:

  cargo build --release        # in the dowel checkout
  DOWELUP=/path/to/dowelup ./run.sh
EOF
    exit 2
}
DOWEL_SRC=$(resolve_dowel_src) || {
    cat >&2 <<'EOF'
cannot find the dowel source checkout. 09-acquisition mirrors it locally so
that the acquisition checks never touch the network. do one of:

  DOWEL_SRC=/path/to/dowel ./run.sh
  git clone https://github.com/sabas0ba/dowel ../dowel
EOF
    exit 2
}
export DOWELUP DOWEL_SRC

# ------------------------------------------------------------ 前提の確認

for tool in cc ninja jq; do
    command -v "$tool" >/dev/null 2>&1 || {
        printf '%s is missing. a C compiler, ninja and jq are required.\n' "$tool" >&2
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
        [ "$found" = 1 ] || { printf 'no such project: %s\n' "$pat" >&2; exit 2; }
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
: >"$PACKAGES"

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

    # そのプロジェクトが含むパッケージ。掲示の表から実体へ辿る材料になる。
    (cd "$dst" && find . -name dowel.toml -printf '%h\n' | sed 's|^\./||' | sort) |
        while IFS= read -r pkg; do
            printf '%s\t%s\n' "$name" "$pkg" >>"$PACKAGES"
        done

    if [ ! -f "$dst/expect.sh" ]; then
        printf '  FAIL expect.sh is missing\n'
        printf 'fail\t%s\t%s\n' "$name" "expect.sh is missing" >>"$RESULTS"
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
        printf '  FAIL expect.sh exited abnormally (rc=%s)\n' "$rc"
        printf 'fail\t%s\t%s\n' "$name" "expect.sh exited abnormally (rc=$rc)" >>"$RESULTS"
    fi

    # 実体を汚していないことの確認。dowel 本体の
    # every_fixture_is_left_clean_in_the_repository と同じ趣旨。
    stray=$(find "$src" \( -name '.dowel' -o -name 'compile_commands.json' \) -print -quit)
    if [ -n "$stray" ]; then
        printf '  FAIL build output was left in the source tree: %s\n' "$stray"
        printf 'fail\t%s\t%s\n' "$name" "build output was left in the source tree" >>"$RESULTS"
    fi

    _record_project "$name" "$started" "$before"
    printf '\n'
done

# ------------------------------------------------------------ 文書の検査
#
# 文書の不整合はスイートの実行にもビルドにも影響しないため、検査しない限り
# 検出されない。検査名を変えたのに引用側を直し忘れる、というのがその形である。
#
# 実際の検査名の一覧が要るため、全プロジェクトを走らせたときだけ行う。

if [ $# -eq 0 ]; then
    printf 'docs\n'
    before=$(wc -l <"$RESULTS")
    started=$(now_ms)
    while IFS=$'\t' read -r st desc; do
        [ -n "$st" ] || continue
        printf '%s\t%s\t%s\n' "$st" docs "$desc" >>"$RESULTS"
        case $st in
            pass) printf '  ok   %s\n' "$desc" ;;
            *)    printf '  FAIL %s\n' "$desc" ;;
        esac
    done < <(python3 "$SUITE_ROOT/scripts/check-docs.py" "$RESULTS")
    _record_project docs "$started" "$before"
    printf '\n'
fi

# ------------------------------------------------------------ 要約

pass=$(grep -c '^pass' "$RESULTS")
fail=$(grep -c '^fail' "$RESULTS")
xfail=$(grep -c '^xfail' "$RESULTS")
xpass=$(grep -c '^xpass' "$RESULTS")

printf 'total %s checks: %s passed, %s failed, %s known, %s fixed\n' \
    "$((pass + fail + xfail + xpass))" "$pass" "$fail" "$xfail" "$xpass"

if [ "$fail" -gt 0 ] || [ "$xpass" -gt 0 ]; then
    printf '\nchecks needing attention:\n'
    grep -E '^(fail|xpass)' "$RESULTS" | awk -F'\t' '{ printf "  %-6s %-16s %s\n", $1, $2, $3 }'
fi

[ "$fail" -eq 0 ] && [ "$xpass" -eq 0 ]
