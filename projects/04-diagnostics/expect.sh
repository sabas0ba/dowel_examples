# 04-diagnostics — 誤ったマニフェストに対する応答
#
# dowel 本体の diagnostics.rs は「診断が CLI まで届くこと」を内側から見る。
# ここで見るのは、利用者が普段使う入口から同じものが届くかどうかである。
# 見る対象は安定コードに限る。文面は互換性の対象ではない。
#
# cases/<code>/ が1事例。ディレクトリ名がそのまま期待する診断コードである。

# check が報告する診断。マニフェストの読み取り・型検査・併合・パス解決の
# いずれで決まるものであっても、利用者から見れば入口はひとつである。
CODES="
unknown-property
unknown-kind
unknown-function
unknown-cfg-key
unknown-feature
non-exhaustive-match
type-mismatch
undeclared-dependency
unknown-target
dependency-cycle
missing-manifest
missing-toolchain
unsupported-language
invalid-source
unresolved-path
incomplete-runner
missing-field
"

# ------------------------------------------------------- 利用者の入口へ届く

for code in $CODES; do
    diag  "$code" "check reports $code"           -C "cases/$code" check
    fails         "check exits non-zero on $code" -C "cases/$code" check
done

# 2パッケージの併合で出るもの。根から見る必要がある。
for code in merge-conflict abi-mismatch; do
    diag  "$code" "check reports $code"           -C "cases/$code/app" check
    fails         "check exits non-zero on $code" -C "cases/$code/app" check
done

# 警告。それ自体では落とさないが、黙って進みもしない。
diag empty-glob "check reports empty-glob" -C cases/empty-glob check

# ------------------------------------------------------- check と build の一致
#
# 「評価と診断のみ。ビルドしない」（docs/60-cli.md）を利用者は、編集中や
# commit 前に誤りを洗い出す入口として使う。check を通ったものが build で
# 落ちるなら、その用途を満たさない。glob 展開とパス解決を伴う3件は、
# かつて build まで出てこなかった（docs/10-findings.md F-004）。

for code in invalid-source unresolved-path empty-glob; do
    diag "$code" "build reports $code as well" -C "cases/$code" build
done

fails "build exits non-zero on invalid-source"  -C cases/invalid-source build
fails "build exits non-zero on unresolved-path" -C cases/unresolved-path build

# ------------------------------------------------------- 下流の道具に流さない
#
# 「既存システムの失敗様式」として本体が挙げているのは、不整合を検出せず
# 下流へ流し、原因の箇所を示さない誤りとして出すことである
# （docs/00-overview.md 1節、docs/51-testing.md の invalid-source の経緯）。
# 組めない言語と、実在しないツールチェーンが同じ形で残っていた。

out_lacks "undefined reference" "a C++ source never reaches the linker" \
    -C cases/unsupported-language build
out_lacks "not found" "a missing toolchain never reaches the shell" \
    -C cases/missing-toolchain build

# ------------------------------------------------------- 位置情報
#
# 「全ての値が型とソース位置と来歴を持つ」ことが設計の主張である。
# 位置を持たない診断は、利用者にどの記述を直せばよいかを伝えない。

for code in $CODES; do
    diag_where "$code" '.labels | length > 0' "$code points at the offending source" \
        -C "cases/$code" check
done

# ------------------------------------------------------- 衝突の両側
#
# 「異なる値が到達したら両方の来歴を提示して失敗する」と定められている
# （docs/10-manifest.md 3節）。併合の衝突では、2つの値は必ず別の
# パッケージから来る。したがって2つの位置は必ず別のファイルにある。

for c in merge-conflict abi-mismatch; do
    diag_where "$c" '.labels | length >= 2' "$c carries the location of both values" \
        -C "cases/$c/app" check
    out_has "app/dowel.build" "$c renders the dependent side of the conflict too" \
        -C "cases/$c/app" check
done

# ------------------------------------------------------- 修正提案の適用
#
# 修正提案は「機械適用可能」と称している（docs/91-implementation-status.md）。
# 適用した結果がもう一度受理されなければ、その主張は成立しない。
# 範囲か置換文字列が誤っていれば、適用後のマニフェストは通らなくなる。

rm -rf fixed && cp -r cases/unknown-property fixed
sh_run apply_fix fixed check
fact $? "unknown-property carries a suggestion"
ok "the manifest still passes check after applying the suggestion" -C fixed check

# 提案は誤った鍵だけを覆う。値まで覆っていると、適用で値が消える。
if grep -q 'includes = \[dir("src")\]' fixed/dowel.build; then
    fact 0 "applying the suggestion keeps the value intact"
else
    fact 1 "applying the suggestion keeps the value intact (got: $(sed -n '6p' fixed/dowel.build))"
fi
