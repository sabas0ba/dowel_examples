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
#
# C++ の側は `unsupported-language` で拒む形をいったん経てから、
# 組めるようにする側で決着した（docs/10-findings.md F-008）。
# したがってここに残るのはツールチェーンだけである。C++ が本当に
# 組めることは projects/15-cpp が見る。

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

# ------------------------------------------------------- 同名のターゲット
#
# 1つのパッケージに `[lib.foo]` と `[bin.foo]` を両方書ける。ライブラリと
# その CLI に同じ名前を付けるのは避けるべき書き方ではなく、自然な書き方で
# ある——成果物の綴りは `libfoo.a` と `foo` で衝突しない。
#
# 受理された先が壊れている（F-052）。現れ方は2つある。
#
#   duplicate-target         `public` がどこへも伝播せず、翻訳が落ちる
#   duplicate-target-shared  オブジェクトの経路が衝突し、**ninja** が落ちる
#
# 後者は `docs/00-overview.md` 1節が「既存システムの失敗様式」として挙げて
# いる形そのものである。マニフェストの誤りが、下流の道具の語彙で、利用者が
# 書いていない行番号を指して出る。

known_issue F-052
fails "check refuses two targets that share a name in one package" \
    -C cases/duplicate-target check

# dowel は2つあることを知っている。助言がその事実を使えていないだけである。
run build foo --no-compdb -C cases/duplicate-target
_last_cmd="dowel build foo"
printf '%s' "$OUT" | grep -q 'duplicate_target:foo, duplicate_target:foo'
fact $? "and the advice for naming it offers the same spelling twice"

# `public` が伝播しない。依存する側にも、宣言した側自身のソースにも。
run build --no-compdb -C cases/duplicate-target
_last_cmd="dowel build"; OUT=$(printf '%s' "$OUT" | grep -m3 'fatal error\|error:')
known_issue F-052
[ "$RC" -eq 0 ]
fact $? "and the library's public include directory reaches the sources that need it"

# オブジェクトの経路に種別が入らないので、同名の2つは同じ場所を共有する。
objs=$("$DOWEL" -C cases/duplicate-target-shared graph --kind=action --format=json 2>/dev/null |
       jq -r '.steps[] | select(.kind == "cc") | .arguments[-1]' | sed 's|.*/obj/|obj/|')
dupes=$(printf '%s\n' "$objs" | sort | uniq -d)
_last_cmd="graph --kind=action | the object each translation writes"
OUT="$objs"$'\n'"---"$'\n'"written twice: ${dupes:-(none)}"
RC=0
known_issue F-052
[ -z "$dupes" ]
fact $? "and a shared source does not collide in the object directory"

# その結果は ninja の語彙で出る。dowel の診断ではない。
run build --no-compdb -C cases/duplicate-target-shared
_last_cmd="dowel build"
OUT=$(printf '%s' "$OUT" | grep -m2 'ninja:\|error:')
known_issue F-052
! printf '%s' "$OUT" | grep -q 'multiple rules generate'
fact $? "so the manifest's mistake is not reported in the downstream tool's words"

# 対照。名前を割れば、同じ木がそのまま通る。差はターゲット名だけである。
for c in duplicate-target duplicate-target-shared; do
    rm -rf "renamed-$c" && cp -r "cases/$c" "renamed-$c"
    sed -i 's/^\[lib\.foo\]/[lib.foolib]/; s/^\[lib\.foo\./[lib.foolib./; s/target("foo")/target("foolib")/' \
        "renamed-$c/dowel.build"
done
ok "renaming one of them makes the same tree build"        -C renamed-duplicate-target        build --no-compdb
ok "and makes the tree that shares a source build as well" -C renamed-duplicate-target-shared build --no-compdb

built=$(cd renamed-duplicate-target-shared && find .dowel/build -name 'libfoolib.a' | head -1)
_last_cmd="find libfoolib.a (renamed)"; OUT="${built:-(absent)}"; RC=0
[ -n "$built" ]
fact $? "producing the archive that the colliding names could not, on the same sources"
