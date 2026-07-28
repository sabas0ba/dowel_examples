# 04-diagnostics — 誤ったマニフェストに対する応答
#
# dowel 本体の diagnostics.rs は「診断が CLI まで届くこと」を内側から見る。
# ここで見るのは、利用者が普段使う入口から同じものが届くかどうかである。
# 見る対象は安定コードに限る。文面は互換性の対象ではない。
#
# cases/<code>/ が1事例。ディレクトリ名がそのまま期待する診断コードである。

# ------------------------------------------------------- 評価の段で出るもの
#
# マニフェストの読み取りと型検査で決まる誤り。ファイルシステムを
# 見ないため、check だけで判定できる。

for code in \
    unknown-property \
    unknown-kind \
    unknown-function \
    unknown-cfg-key \
    non-exhaustive-match \
    type-mismatch \
    undeclared-dependency \
    unknown-target \
    dependency-cycle \
    missing-manifest
do
    diag  "$code" "check reports $code"                -C "cases/$code" check
    fails         "check exits non-zero on $code"      -C "cases/$code" check
done

# 2パッケージの併合で出るもの。根から見る必要がある。
for code in merge-conflict abi-mismatch; do
    diag  "$code" "check reports $code"           -C "cases/$code/app" check
    fails         "check exits non-zero on $code" -C "cases/$code/app" check
done

# ------------------------------------------------------- 計画の段で出るもの
#
# glob 展開とパス解決は評価では行わない。評価時に走査すると、その時点の
# ファイルシステムという記録されない入力が結果に混ざるためである
# （docs/10-manifest.md）。したがってこれらは build まで出てこない。

for code in invalid-source unresolved-path empty-glob; do
    diag "$code" "build reports $code" -C "cases/$code" build
done

# 誤りの2件は 0 以外で終わる。empty-glob は警告であり、
# それ自体では落とさない（同じ入力で no-sources が別に出る）。
fails "build exits non-zero on invalid-source"  -C cases/invalid-source build
fails "build exits non-zero on unresolved-path" -C cases/unresolved-path build

# ------------------------------------------------------- check の守備範囲
#
# check は「評価と診断のみ。ビルドしない」と定められている（docs/60-cli.md）。
# 利用者はこれを、編集中や commit 前にマニフェストの誤りを洗い出す入口として
# 使う。ところが上記3件は check を素通りし、「check passed」と表示される。
# ビルドできないマニフェストに対して check が通ることになる。

for code in invalid-source unresolved-path; do
    known_issue F-004
    fails "check finds $code as well" -C "cases/$code" check
done

# ------------------------------------------------------- 位置情報
#
# 「全ての値が型とソース位置と来歴を持つ」ことが設計の主張である。
# 診断が位置を持たなければ、利用者はどの記述を直せばよいか分からない。
# ここでは代表として、他の事例が全て位置を持つことを確かめたうえで、
# missing-manifest だけが持たないことを既知の未修正として記録する。

for code in unknown-property undeclared-dependency dependency-cycle type-mismatch; do
    diag_where "$code" '.labels | length > 0' "$code points at the offending source" \
        -C "cases/$code" check
done

known_issue F-005
diag_where missing-manifest '.labels | length > 0' \
    "missing-manifest points at the offending source" -C cases/missing-manifest check

# ------------------------------------------------------- 下流の道具に流す誤り
#
# 「既存システムの失敗様式」として本体が挙げているのは、不整合を検出せず
# 下流へ流し、原因の箇所を示さない誤りとして出すことである
# （docs/00-overview.md 1節、docs/51-testing.md の invalid-source の経緯）。
# 同じ形の経路が2つ残っている。

# 組めない言語のソースが受理され、リンカの undefined reference になる。
# build 自体は 0 以外を返すが、返しているのは ninja であり、
# 診断は1件も出ない。
fails "building a C++ source fails" -C cases/cpp-source build

known_issue F-008
any_diag "building a C++ source produces a diagnostic of dowel's own" \
    -C cases/cpp-source build

# 宣言したツールチェーンの実在を確かめないため、ninja の
# 「command not found」になる。再現性のために固定した対象そのものである。
known_issue F-009
diag_where unknown-toolchain '.labels | length > 0' \
    "declaring a toolchain that does not exist fails with a source location" \
    -C cases/missing-toolchain check

# 下流へ流れていること自体は、いま観測できる事実として固定しておく。
# 直ったときにこの2件が XPASS になり、上の xfail と対で動く。
known_issue F-008
out_lacks "undefined reference" "the C++ failure is not reported in the linker's words" \
    -C cases/cpp-source build

known_issue F-009
out_lacks "not found" "the toolchain failure is not reported in the shell's words" \
    -C cases/missing-toolchain build

# ------------------------------------------------------- 衝突の両側
#
# 「異なる値が到達したら両方の来歴を提示して失敗する」と定められている
# （docs/10-manifest.md 3節）。併合の衝突では、2つの値は必ず別の
# パッケージから来る。したがって2つの位置は必ず別のファイルにある。

for c in merge-conflict abi-mismatch; do
    diag_where "$c" '.labels | length >= 2' "$c carries the location of both values" \
        -C "cases/$c/app" check
done

# 機械可読形式には両方あるが、人間向けの描画に出るのは主ラベルだけである。
# 利用者が最初に見るのはこちらであり、片側だけでは衝突の相手が分からない。
for c in merge-conflict abi-mismatch; do
    known_issue F-007
    out_has "app/dowel.build" "$c renders the dependent side of the conflict too" \
        -C "cases/$c/app" check
done

# ------------------------------------------------------- 修正提案の適用
#
# 修正提案は「機械適用可能」と称している（docs/91-implementation-status.md）。
# 適用した結果がもう一度受理されなければ、その主張は成立しない。

rm -rf fixed && cp -r cases/unknown-property fixed
sh_run apply_fix fixed check
fact $? "unknown-property carries a suggestion"

known_issue F-006
ok "the manifest still passes check after applying the suggestion" -C fixed check
