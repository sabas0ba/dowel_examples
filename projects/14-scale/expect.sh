# 14-scale — 規模
#
# ここまでのプロジェクトは、どれも数個のソースと数個のターゲットで組んである。
# 増分の性質はそこでも観測できるが、**増分の costs が木の大きさに比例して
# いないこと**は、木が小さいと分からない。1つ編集して2つ組み直すのと、
# 1つ編集して全部組み直すのとが、5ファイルの木では同じに見える。
#
# 見るのは時間ではなく件数である。「走らせた数」と「飛ばした数」の両方が
# 出るため、**全部を考慮したうえで必要な分だけ実行したこと**が分かる。
# 飛ばした数を見ないと、単に知らなかっただけの場合と区別できない。
#
# 木はリポジトリに置かず生成する。中身に意味は無く数だけが意味を持つため、
# 100 を超えるファイルを置くと差分も一覧も読めなくなる。

SOURCES=120
TARGETS=8
DEPTH=6

# wide の総アクション数。
#   コンパイル = SOURCES + 1（sum.c）+ TARGETS（各 bin）
#   書庫       = 1
#   リンク     = TARGETS
COMPILES=$(( SOURCES + 1 + TARGETS ))
WIDE_TOTAL=$(( COMPILES + 1 + TARGETS ))
# 連鎖の総アクション数。各段が1コンパイル+1書庫、top が1コンパイル+1リンク。
CHAIN_TOTAL=$(( DEPTH * 2 + 2 ))

python3 generate.py tree "$SOURCES" "$TARGETS" "$DEPTH" || {
    fact 1 "the generated tree can be created"
    return 0
}
WIDE=$PWD/tree/wide
TOP=$PWD/tree/chain/top

# counts <パッケージ> — direct 実行器で組み、RAN と SKIPPED を置く。
#
# 実行器は direct で通す。数えるために要るうえ、ninja と跨ぐと依存の記録が
# 引き継がれない（docs/10-findings.md F-014）。
RAN=0; SKIPPED=0
counts() {
    OUT=$("$DOWEL" -C "$1" build --executor=direct --log-level=debug 2>&1)
    RC=$?
    _last_cmd="dowel -C $(basename "$1") build --executor=direct"
    RAN=$(printf '%s' "$OUT" | sed -n 's/.*ran \([0-9]*\) actions.*/\1/p' | tail -1)
    SKIPPED=$(printf '%s' "$OUT" | sed -n 's/.*skipped \([0-9]*\) already.*/\1/p' | tail -1)
    : "${RAN:=-1}" "${SKIPPED:=-1}"
}

# did <走った数> <飛ばした数> <desc> — 直前の counts の結果を判定する。
did() {
    [ "$RC" -eq 0 ] && [ "$RAN" = "$1" ] && [ "$SKIPPED" = "$2" ]
    local v=$?
    OUT="ran $RAN, skipped $SKIPPED (wanted ran $1, skipped $2)"
    _verdict $v "$3"
}

# ------------------------------------------------------- 全部を見ていること

ok "check passes on a package with $SOURCES sources and $TARGETS targets" -C tree/wide check

counts "$WIDE"
did "$WIDE_TOTAL" 0 "the first build runs one action per source, archive and link"

counts "$WIDE"
did 0 "$WIDE_TOTAL" "a second build runs nothing and accounts for every action"

# 飛ばした数が総数に等しいことが要点である。0 と報告されるだけなら、
# 「知らなかった」のか「知っていて飛ばした」のか区別できない。

# ------------------------------------------------------- 費用は変更の大きさに比例する
#
# ここが規模でしか見えない性質である。木が5ファイルなら、
# 「2つ組み直す」と「全部組み直す」は同じに見える。

printf '\n/* touched */\n' >> "$WIDE/src/u0050.c"
counts "$WIDE"
did $(( 1 + 1 + TARGETS )) $(( WIDE_TOTAL - 1 - 1 - TARGETS )) \
    "editing one source of $SOURCES rebuilds only it, the archive and the dependents"

printf '\n/* touched */\n' >> "$WIDE/bins/b003.c"
counts "$WIDE"
did 2 $(( WIDE_TOTAL - 2 )) "editing one dependent rebuilds only that dependent"

# 公開ヘッダは別である。伝播するのだから全部組み直すのが正しい。
# 変更の大きさに比例するとは「常に少ない」ことではない。
printf '\n/* touched */\n' >> "$WIDE/include/wide.h"
counts "$WIDE"
did "$WIDE_TOTAL" 0 "editing the public header rebuilds everything that includes it"

# ------------------------------------------------------- 集合の出入り

# 足したぶん総数がひとつ増える。飛ばした数は新しい総数から引く。
printf '#include "wide.h"\nint extra(void) { return 1; }\n' > "$WIDE/src/extra.c"
counts "$WIDE"
did $(( 1 + 1 + TARGETS )) $(( WIDE_TOTAL + 1 - 1 - 1 - TARGETS )) \
    "adding one source compiles only the new one"

rm -f "$WIDE/src/extra.c"
counts "$WIDE"
did $(( 1 + TARGETS )) $(( WIDE_TOTAL - 1 - TARGETS )) \
    "removing one source recompiles nothing and relinks the dependents"

ok "the tests of the wide package still pass" -C tree/wide build

# ------------------------------------------------------- 深い連鎖
#
# 依存が $DEPTH 段。波及が段数ではなく**実際の include** で決まることを見る。
# 宣言した依存の深さで決めていると、使っていない段まで組み直す。

ok "check passes through a $DEPTH level dependency chain" -C tree/chain/top check
counts "$TOP"
did "$CHAIN_TOTAL" 0 "the first build of the chain runs every action"
counts "$TOP"
did 0 "$CHAIN_TOTAL" "a second build of the chain runs nothing"

printf '\n/* touched */\n' >> "$PWD/tree/chain/level5/src/level5.c"
counts "$TOP"
[ "$RC" -eq 0 ] && [ "$RAN" -lt "$CHAIN_TOTAL" ] && [ "$RAN" -gt 0 ]
OUT="ran $RAN of $CHAIN_TOTAL"
_verdict $? "editing the nearest level does not rebuild the whole chain"

printf '\n/* touched */\n' >> "$PWD/tree/chain/level0/include/level0.h"
counts "$TOP"
[ "$RC" -eq 0 ] && [ "$RAN" -lt "$CHAIN_TOTAL" ] && [ "$RAN" -gt 0 ]
OUT="ran $RAN of $CHAIN_TOTAL"
_verdict $? "editing the deepest header rebuilds only what includes it"

ok "the chain still builds after the edits" -C tree/chain/top build

# ------------------------------------------------------- 評価が木の大きさで潰れないこと
#
# 上限は非常に緩く取る。ここで捕まえたいのは機械の速さではなく、
# 木の大きさに対して二乗以上で効く経路が入り込むことである
# （docs/00-design.md 6節）。手元では $SOURCES ソースの check が 10ms 前後で
# 終わる。10 秒は 1000 倍の余裕であり、どの機械でも同じ側に倒れる。

t0=$(now_ms)
run -C tree/wide check
t1=$(now_ms)
elapsed=$(( t1 - t0 ))
[ "$RC" -eq 0 ] && [ "$elapsed" -lt 10000 ]
OUT="check took ${elapsed}ms"
_verdict $? "check on a large package stays far below the budget"

# 計画段の内訳も出る。評価だけでなく計画も大きさに潰れないこと。
run -C tree/wide check --log-level=debug
printf '%s' "$OUT" | grep -q 'phase.*plan'
fact $? "the plan phase is reported for a large package"
