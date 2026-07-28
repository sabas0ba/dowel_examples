# shellcheck shell=bash
#
# 検査手続きの共通部分。各プロジェクトの expect.sh から使う。
#
# 呼び出し側（run.sh）が以下を用意している前提で動く。
#
#   DOWEL      dowel バイナリの絶対パス
#   PROJECT    プロジェクト名
#   RESULTS    結果を追記する TSV ファイル
#   カレントディレクトリ  プロジェクトの複製先（.work/<name>/）
#
# 出力は「1 検査 1 行」。落ちた検査のみ直後にコマンドの出力を添える。

# 直前に走らせたコマンドの結果。検査関数から参照する。
RC=0
OUT=""

# ---------------------------------------------------------------- 結果の記録

_c_pass=$'\033[32m'
_c_fail=$'\033[31m'
_c_skip=$'\033[33m'
_c_off=$'\033[0m'
if [ ! -t 1 ] || [ "${NO_COLOR:-}" != "" ]; then
    _c_pass=""; _c_fail=""; _c_skip=""; _c_off=""
fi

# _record <status> <desc>
_record() {
    local status=$1 desc=$2
    printf '%s\t%s\t%s\n' "$status" "$PROJECT" "$desc" >>"$RESULTS"
    case $status in
        pass) printf '  %sok%s   %s\n' "$_c_pass" "$_c_off" "$desc" ;;
        fail) printf '  %sFAIL%s %s\n' "$_c_fail" "$_c_off" "$desc" ;;
        xfail) printf '  %sxfail%s %s\n' "$_c_skip" "$_c_off" "$desc" ;;
        xpass) printf '  %sXPASS%s %s\n' "$_c_fail" "$_c_off" "$desc" ;;
    esac
}

# 落ちた検査の材料を出す。期待値と実際、そして実行した出力。
_report_failure() {
    [ -n "$_last_cmd" ] || return 0
    printf '       command: %s\n' "$_last_cmd"
    printf '       exit:    %s\n' "$RC"
    if [ -n "$OUT" ]; then
        printf '       output:\n'
        printf '%s\n' "$OUT" | sed 's/^/         /'
    fi
}

# 既知の未修正事項に対する検査は xfail で登録する。
# 修正されると XPASS として落ち、この宣言を外すべきことが分かる。
# 使い方:  known_issue F-003 ; ok "..." check
_pending_issue=""
known_issue() { _pending_issue=$1; }

# 検査1件の判定。expected=0 なら成功を期待、1 なら失敗を期待。
_verdict() {
    local good=$1 desc=$2
    local issue=$_pending_issue
    _pending_issue=""

    if [ -n "$issue" ]; then
        desc="$desc  [$issue]"
        if [ "$good" = 0 ]; then
            _record xpass "$desc"
            printf '       this check is declared xfail against %s, but it passed.\n' "$issue"
            printf '       update docs/10-findings.md and drop the known_issue declaration.\n'
        else
            _record xfail "$desc"
        fi
        return 0
    fi

    if [ "$good" = 0 ]; then
        _record pass "$desc"
    else
        _record fail "$desc"
        _report_failure
    fi
    # 直前の実行の残骸を次の検査へ持ち越さない。
    _last_cmd=""
    OUT=""
}

# ---------------------------------------------------------------- 実行

_last_cmd=""

# run <args...> — dowel を走らせる。stdout と stderr をまとめて OUT に入れる。
run() {
    _last_cmd="dowel $*"
    OUT=$("$DOWEL" "$@" 2>&1)
    RC=$?
    return 0
}

# sh_run <cmd...> — dowel 以外のコマンド。
sh_run() {
    _last_cmd="$*"
    OUT=$("$@" 2>&1)
    RC=$?
    return 0
}

# ---------------------------------------------------------------- 検査

# ok <desc> <dowel args...> — 終了状態 0 を期待する。
ok() {
    local desc=$1; shift
    run "$@"
    [ "$RC" -eq 0 ]; _verdict $? "$desc"
}

# fails <desc> <dowel args...> — 終了状態 0 以外を期待する。
fails() {
    local desc=$1; shift
    run "$@"
    [ "$RC" -ne 0 ]; _verdict $? "$desc"
}

# 機械可読の診断は stdout に出る。stderr は進行とログである
# （docs/60-cli.md）。混ぜて読むと、ログに現れた語をコードと誤認する。
json_diags() {
    _last_cmd="dowel $* --message-format=json"
    "$DOWEL" "$@" --message-format=json 2>/dev/null
}

# diag <code> <desc> <dowel args...> — 指定した診断コードが機械可読形式で
# 出ることを期待する。診断が利用者まで届くかどうかを、利用者と同じ経路で見る。
diag() {
    local code=$1 desc=$2; shift 2
    OUT=$(json_diags "$@")
    RC=0
    if printf '%s' "$OUT" | jq -e --arg c "$code" 'select(.code == $c)' >/dev/null 2>&1; then
        _verdict 0 "$desc"
    else
        _verdict 1 "$desc (diagnostic $code was not emitted)"
    fi
}

# no_diag <code> <desc> <dowel args...> — 指定した診断コードが出ないこと。
no_diag() {
    local code=$1 desc=$2; shift 2
    OUT=$(json_diags "$@")
    RC=0
    if printf '%s' "$OUT" | jq -e --arg c "$code" 'select(.code == $c)' >/dev/null 2>&1; then
        _verdict 1 "$desc (diagnostic $code was emitted)"
    else
        _verdict 0 "$desc"
    fi
}

# any_diag <desc> <dowel args...> — 機械可読な診断が1件以上出ること。
# 失敗したのに診断が1件も無い場合、利用者は下流の道具の出力しか手にできず、
# マニフェストのどこを直せばよいかが分からない。
any_diag() {
    local desc=$1; shift
    OUT=$(json_diags "$@")
    RC=0
    if printf '%s' "$OUT" | jq -e '.code' >/dev/null 2>&1; then
        _verdict 0 "$desc"
    else
        _verdict 1 "$desc"
    fi
}

# diag_where <code> <jq式> <desc> <dowel args...> — 指定した診断の中身を見る。
# 文面は互換性の対象ではないが、位置・注記・修正提案の有無は構造であり、
# 利用者に届く情報の量そのものである。
diag_where() {
    local code=$1 filter=$2 desc=$3; shift 3
    OUT=$(json_diags "$@")
    RC=0
    if printf '%s' "$OUT" | jq -e --arg c "$code" "select(.code == \$c) | $filter" >/dev/null 2>&1
    then
        _verdict 0 "$desc"
    else
        _verdict 1 "$desc"
    fi
}

# out_has <text> <desc> <dowel args...> — 出力に部分文字列を期待する。
out_has() {
    local text=$1 desc=$2; shift 2
    run "$@"
    printf '%s' "$OUT" | grep -qF -- "$text"; _verdict $? "$desc"
}

# out_lacks <text> <desc> <dowel args...>
out_lacks() {
    local text=$1 desc=$2; shift 2
    run "$@"
    ! printf '%s' "$OUT" | grep -qF -- "$text"; _verdict $? "$desc"
}

# prints <expected> <desc> <cmd...> — 任意のコマンドの stdout を完全一致で見る。
# 成果物の実行結果を確かめるのに使う。
prints() {
    local want=$1 desc=$2; shift 2
    _last_cmd="$*"
    OUT=$("$@" 2>&1)
    RC=$?
    if [ "$RC" -eq 0 ] && [ "$OUT" = "$want" ]; then
        _verdict 0 "$desc"
    else
        _verdict 1 "$desc (want \"$want\", got \"$OUT\")"
    fi
}

# apply_fix <パッケージ> [dowel args...] — 修正提案を実際に適用する。
# 提案が「機械適用可能」であることは、適用した結果がもう一度受理されるか
# どうかでしか確かめられない。範囲か置換文字列が誤っていれば、適用後の
# マニフェストは通らなくなる。
apply_fix() {
    local dir=$1; shift
    "$DOWEL" -C "$dir" "${@:-check}" --message-format=json 2>/dev/null |
        python3 "$SUITE_ROOT/lib/apply_fix.py"
}

# assert <desc> <cmd...> — 任意のシェルコマンドの終了状態で判定する。
assert() {
    local desc=$1; shift
    sh_run "$@"
    [ "$RC" -eq 0 ]; _verdict $? "$desc"
}

# fact <good> <desc> — 呼び出し側で組み立てた条件の判定。
# good が 0 なら成功。付帯情報は desc に含めること。
fact() { _verdict "$1" "$2"; }

# ---------------------------------------------------------------- 実引数
#
# 「なぜこの引数になったのか」を追う材料はアクショングラフにある。
# compile_commands.json は同じ内容を言語サーバ向けに整えたものであり、
# ターゲットごとに見たい場合はグラフの方が扱いやすい。

# cc_args <target> [dowel args...] — 指定したターゲットのコンパイル引数。
# ソースが複数ある場合は全アクション分を改行区切りで返す。
cc_args() {
    local t=$1; shift
    "$DOWEL" graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r --arg t "$t" '.actions[] | select(.kind == "cc" and .target == $t) | .command | join(" ")'
}

# args_have <target> <text> <desc> — 引数に部分文字列があること。
args_have() {
    local t=$1 text=$2 desc=$3
    _last_cmd="cc_args $t | grep -F -- $text"
    OUT=$(cc_args "$t")
    RC=0
    printf '%s' "$OUT" | grep -qF -- "$text"; _verdict $? "$desc"
}

# args_lack <target> <text> <desc> — 引数に部分文字列が無いこと。
# 伝播しないことの検査は、値の不在でしか観測できない。
args_lack() {
    local t=$1 text=$2 desc=$3
    _last_cmd="cc_args $t | grep -vF -- $text"
    OUT=$(cc_args "$t")
    RC=0
    ! printf '%s' "$OUT" | grep -qF -- "$text"; _verdict $? "$desc"
}

# ---------------------------------------------------------------- 増分の計数
#
# 「何を計算しなかったか」は実行回数でしか観測できない（docs/51-testing.md）。
# direct 実行器は判定理由を debug ログに出すため、これを数える。

# _ran_actions — 直前の run の出力から実行したアクション数を取り出す。
_ran_actions() {
    printf '%s' "$OUT" | sed -n 's/.*ran \([0-9]*\) actions.*/\1/p' | tail -1
}

# build_direct <dowel args...> — direct 実行器と debug ログでビルドする。
build_direct() {
    run build --executor=direct --log-level=debug "$@"
}

# runs_actions <n> <desc> <dowel build args...> — direct 実行器で走った
# アクション数を期待する。n が空文字なら「1 件以上」を意味する。
runs_actions() {
    local want=$1 desc=$2; shift 2
    build_direct "$@"
    local got; got=$(_ran_actions)
    if [ "$RC" -ne 0 ]; then
        _verdict 1 "$desc (the build failed)"
    elif [ -z "$got" ]; then
        _verdict 1 "$desc (no action count in the log)"
    elif [ "$want" = "+" ]; then
        [ "$got" -gt 0 ]; _verdict $? "$desc ($got actions)"
    elif [ "$got" = "$want" ]; then
        _verdict 0 "$desc"
    else
        _verdict 1 "$desc (want $want actions, got $got)"
    fi
}

# ---------------------------------------------------------------- 成果物

# artifact <name> [構成識別子の末尾] — ビルドした実行ファイルのパス。
# 第2引数はビルドディレクトリ名の末尾に一致させる。省くと構成を問わない
# （構成が1つだけのとき）。`debug` は `debug-json` に一致しない。
artifact() {
    local p
    p=$(find .dowel/build -type f -path "*${2:-}/bin/$1" 2>/dev/null | sort | head -1)
    if [ -z "$p" ]; then
        printf '%s' "/nonexistent/$1"
    else
        printf '%s' "$PWD/$p"
    fi
}

# build_dir_id — ビルドディレクトリの構成識別子（複数ある場合は改行区切り）。
build_dir_ids() {
    find .dowel/build -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

# ---------------------------------------------------------------- 既定の手順
#
# 何も特別なことがないパッケージに対する標準の並び。
# check → build（ninja）→ direct で最新性を確認する。
#
# 3 段目は 2 つのことを同時に見ている。再ビルドが空振りすることと、
# 実行器をまたいでも最新性の判定が一致することである。両者は記録を
# 共有しており、片方が組んだ成果をもう片方が作り直してはならない。

# standard <desc-prefix> — カレントディレクトリのパッケージに対して行う。
standard() {
    local name=$1
    ok    "$name: check passes" check
    ok    "$name: build passes" build
    runs_actions 0 "$name: a second build runs nothing, across executors too"
}

# has_tests — パッケージが test ターゲットを持つか。
has_tests() { grep -q '^\[test\.' dowel.build 2>/dev/null; }
