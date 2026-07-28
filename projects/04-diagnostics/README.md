# 04-diagnostics — 誤ったマニフェストに対する応答

`cases/<code>/` が1事例。ディレクトリ名がそのまま期待する診断コードである。

dowel 本体の `crates/dowel-cli/tests/diagnostics.rs` は、診断が CLI まで
届くことを内側から見て、コードの網羅を追跡している。ここで見るのは
同じものが**利用者の入口から**届くかどうか、および届いた診断が
**利用者にとって使えるか**どうかである。後者が本プロジェクトの主題である。

コードは互換性の対象であるが、文面はそうではない。したがって検査するのは
コード、位置の有無、ラベルの本数、修正提案の適用可能性に限る。

## 何を固定するか

### 1. 診断コードが利用者の入口から届く

`--message-format=json` の stdout に、期待するコードが1行として出ること。
評価の段で決まるものは `check` で、glob 展開とパス解決を伴うものは
`build` で確かめる。

| 段 | コード |
|---|---|
| 評価 | `unknown-property` `unknown-kind` `unknown-function` `unknown-cfg-key` `non-exhaustive-match` `type-mismatch` `undeclared-dependency` `unknown-target` `dependency-cycle` `missing-manifest` |
| 併合 | `merge-conflict` `abi-mismatch` |
| 計画 | `invalid-source` `unresolved-path` `empty-glob` |

### 2. 終了状態が診断の重大度と一致する

誤りは 0 以外で終わる。`empty-glob` は警告であり、それ自体では落とさない
（同じ入力で `no-sources` が別に出る）。

### 3. 診断が原因の位置を持つ

「全ての値が型とソース位置と来歴を持つ」ことが設計の主張である。
位置を持たない診断は、利用者にどこを直せばよいかを伝えない。

### 4. 併合の衝突は2つの値の位置を持つ

`error_on_conflict` と `must_equal` の失敗では、衝突する2つの値が
必ず別のパッケージから来る。片側だけでは相手が分からない。

### 5. 修正提案が実際に適用できる

「機械適用可能」であることは、適用した結果がもう一度受理されるかどうかで
しか確かめられない。`lib/apply_fix.py` が JSON の提案を書き戻し、
もう一度 `check` を掛ける。

### 6. 下流の道具に流さない

不整合を検出せず下流へ流し、原因の箇所を示さない誤りとして出すことは、
本体が既存システムの失敗様式として挙げているものである。
同じ形の経路が `.cpp` のソースと実在しないツールチェーンの2つに残っている。

## 既知の未修正事項

詳細は [docs/10-findings.md](../../docs/10-findings.md)。

| # | 内容 | 事例 |
|---|---|---|
| F-004 | `check` が計画段の誤りを見つけない | `invalid-source` `unresolved-path` |
| F-005 | `missing-manifest` に位置情報が無い | `missing-manifest` |
| F-006 | 修正提案の範囲が誤っており、適用すると壊れる | `unknown-property` |
| F-007 | 併合衝突の人間向け描画が片側の位置しか出さない | `merge-conflict` `abi-mismatch` |
| F-008 | C++ のソースが黙って受理される | `cpp-source` |
| F-009 | 宣言したツールチェーンの実在を確認しない | `missing-toolchain` |

## 事例を足すとき

1. `cases/<code>/` に、その診断だけを起こす最小のパッケージを置く
2. `dowel.build` の先頭に、なぜその入力が誤りなのかを1〜2行で書く
3. `expect.sh` の該当する一覧に `<code>` を足す

事例が誤りとして妥当かどうかは、この検査では分からない。
その判断は `dowel.build` に書いた理由による。
