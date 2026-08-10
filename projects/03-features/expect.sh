# 03-features — 機能フラグと任意の依存
#
# 依存グラフの辺が構成で変わる。現れる側より、消える側の検査が重要である。

cd app || exit 1

standard app

# --------------------------------------------------- 既定の機能

prints "backends=json width=4" "the default features bring the json edge in" "$(artifact app)"
out_has "json:json" "graph shows the json edge" graph

# --------------------------------------------------- 機能を足す

ok "json and xml can both be enabled" build --features=xml
prints "backends=json+xml width=12" "both edges appear" "$(artifact app "app--json+app--xml")"

# --------------------------------------------------- 機能を外す

ok "the default features can be turned off" build --no-default-features
prints "backends=none width=0" \
    "when the edge goes, neither the public defines nor the headers arrive" \
    "$(artifact app gnu-debug)"

# 辺が消えたとき、ライブラリそのものがリンクされないこと。
# 出力の内容だけでは「使っていない」ことしか分からず、
# 「持ち込んでいない」ことはアクショングラフでしか見えない。
out_lacks "libjson.a" "when the edge goes, the archive is not built either" \
    graph --kind=action --no-default-features

# --------------------------------------------------- 選ばれなかった任意の依存
#
# 選ばれなかった依存は読み込まない。依存グラフにも現れない。孤立した節点が
# 残ると、graph を見た利用者に「この構成に含まれる」と読ませる。取得を伴う
# 依存（Phase 5）では「選ばれていない依存を取ってくる」ことになる。

out_lacks "xml:xml" "a dependency behind a disabled feature is absent from the graph" graph
ok "a disabled optional dependency need not exist on disk" -C ../missing-optional check

# --------------------------------------------------- 宣言されていない機能
#
# feature 名前空間は「dowel.toml の [features] で宣言されたもののみ」と
# 定められている（docs/99-open-questions.md Q1 の実装済み語彙の表）。
# 綴り間違いが黙って偽になると、最適化経路や後方互換の分岐が無言で
# 消える。cfg.nosuchkey は unknown-cfg-key で落ちるため、非対称である。

fails "an undeclared feature passed to --features is rejected" check --features=nosuchfeature
fails "an undeclared feature referenced from dowel.build is rejected" \
    -C ../undeclared check

# 綴り間違いに候補が出る。候補が出なければ、利用者は宣言を探しに行くことになる。
out_has "did you mean" "an undeclared feature gets a suggestion" -C ../undeclared check

# --------------------------------------------------- 任意の依存の実体

cd ../json || exit 1
ok "json: builds on its own" check
cd ../xml || exit 1
ok "xml: builds on its own" check
