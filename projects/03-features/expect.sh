# 03-features — 機能フラグと任意の依存
#
# 依存グラフの辺が構成で変わる。現れる側より、消える側の検査が重要である。

cd app || exit 1

standard app

# --------------------------------------------------- 既定の機能

prints "backends=json width=4" "既定の機能で json の辺が現れる" "$(artifact app)"
out_has "json:json" "graph に json の辺が出る" graph

# --------------------------------------------------- 機能を足す

ok "json と xml の両方を有効にできる" build --features=xml
prints "backends=json+xml width=12" "両方の辺が現れる" "$(artifact app json+xml)"

# --------------------------------------------------- 機能を外す

ok "既定の機能を外せる" build --no-default-features
prints "backends=none width=0" "辺が消えると公開定義もヘッダも届かない" \
    "$(artifact app gnu-debug)"

# 辺が消えたとき、ライブラリそのものがリンクされないこと。
# 出力の内容だけでは「使っていない」ことしか分からず、
# 「持ち込んでいない」ことはアクショングラフでしか見えない。
out_lacks "libjson.a" "辺が消えるとアーカイブも作らない" \
    graph --kind=action --no-default-features

# --------------------------------------------------- 選ばれなかった任意の依存
#
# アクショングラフからは正しく消えるが、パッケージとしては読み込まれる。
# 依存グラフには孤立した節点として残り、実体が無ければ読み込みが失敗する。
# path 依存では実害が小さいが、取得を伴う依存（Phase 5）では
# 「選ばれていない依存を取ってくる」ことになる。

known_issue F-003
out_lacks "xml:xml" "有効でない機能の依存は依存グラフに現れない" graph

known_issue F-003
ok "有効でない任意の依存は実体が無くても check できる" -C ../missing-optional check

# --------------------------------------------------- 宣言されていない機能
#
# feature 名前空間は「dowel.toml の [features] で宣言されたもののみ」と
# 定められている（docs/99-open-questions.md Q1 の実装済み語彙の表）。
# 綴り間違いが黙って偽になると、最適化経路や後方互換の分岐が無言で
# 消える。cfg.nosuchkey は unknown-cfg-key で落ちるため、非対称である。

known_issue F-001
fails "宣言されていない機能を --features に渡すと落ちる" check --features=nosuchfeature

known_issue F-002
fails "dowel.build から宣言されていない機能を参照すると落ちる" \
    -C ../undeclared check

# --------------------------------------------------- 任意の依存の実体

cd ../json || exit 1
ok "json: 単体でも組める" check
cd ../xml || exit 1
ok "xml: 単体でも組める" check
