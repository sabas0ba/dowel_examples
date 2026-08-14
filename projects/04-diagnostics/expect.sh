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
duplicate-target
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
# 1つのパッケージに `[lib.foo]` と `[bin.foo]` を両方書ける状態だった
# （F-052）。`check` は通り、`public` はどこへも伝播せず、ソースを共有すると
# オブジェクトの経路が衝突して **ninja の言葉で**落ちた。
#
# いまは `duplicate-target` で拒まれる。上の一覧に入れてあるので、報告される
# こと・非零で終わること・位置を指すことはそちらで見ている。ここで見るのは、
# **この診断が名前の衝突に固有に持つべきもの**である。

# 衝突は2つの宣言の間にある。片方だけ指しても、どちらを直せばよいか決まらない。
diag_where duplicate-target '.labels | length >= 2' \
    "duplicate-target carries the location of both declarations" \
    -C cases/duplicate-target check

run -C cases/duplicate-target check
said=$OUT
_last_cmd="dowel check  # [lib.foo] と [bin.foo]"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'declared here first'
fact $? "naming which of the two came first, so the later one is the one to rename"

# なぜ一意でなければならないかを言う。名前は3か所で鍵として使われている。
_last_cmd="dowel check | note"; OUT=$(printf '%s' "$said" | grep -m2 'note'); RC=0
printf '%s' "$said" | grep -q 'object directory'
fact $? "and why the name has to be unique, naming the object directory that keys on it"

# 助言は**別の綴り**を出す。かつて `dowel build foo` の助言は
# `pkg:foo, pkg:foo` と同じ綴りを2つ挙げていた（F-052）。
suggest=$(printf '%s' "$said" | sed -n 's/.*rename one, for example `\[\(.*\)\]`.*/\1/p')
_last_cmd="dowel check | rename one, for example ..."; OUT="suggested: ${suggest:-(none)}"; RC=0
[ -n "$suggest" ] && [ "$suggest" != "bin.foo" ] && [ "$suggest" != "lib.foo" ]
fact $? "and the suggestion offers a spelling that differs from both"

# 対照。名前を割れば、同じ木がそのまま通る。差はターゲット名だけである。
rm -rf renamed && cp -r cases/duplicate-target renamed
sed -i 's/^\[lib\.foo\]/[lib.foolib]/; s/^\[lib\.foo\./[lib.foolib./; s/target("foo")/target("foolib")/' \
    renamed/dowel.build
ok "renaming one of them makes the same tree build" -C renamed build --no-compdb

# そして `public` が届く。かつてはここが届かず、翻訳が落ちていた。
got=$("$DOWEL" -C renamed graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc") | .arguments | join(" ")' | head -1)
_last_cmd="graph | cc の引数（renamed）"; OUT="$got"; RC=0
printf '%s' "$got" | grep -q -- '-I'
fact $? "with the library's public include directory reaching the sources that need it"

# ------------------------------------------------------- check は的を取らない
#
# `check` は「評価と診断のみ」の入口であり、**全部**を見る。目標の名前を
# 渡すのは使い方の誤りであって、黙って無視してよい引数ではない——無視すると
# 「その目標だけ見た」と読んだ利用者が、見ていない誤りを見たつもりになる。

fails "check refuses a target name" -C cases/type-mismatch check app
out_has "takes no target" "and says that it checks everything" \
        -C cases/type-mismatch check app

# ------------------------------------------------------- 語彙は閉じている（ADR-0034）
#
# `cfg` / `host` / `target` / `tc` は閉じた集合であり、ADR 1つにつき鍵1つ、
# 領域つきでしか増えない。プロジェクト自身の軸は `[features]` の側に置く
# ——dowel が知っていることを dowel が宣言し、残りをパッケージが宣言する、
# という二層である。
#
# ここで見るのは、**拒むことより導くこと**である。語彙に無い鍵を書いた
# 利用者が次に何をすればよいかは、閉じていると言うだけでは決まらない。

probe=$(mktemp -d)
mkdir -p "$probe/src"
cat >"$probe/dowel.toml" <<'TOML'
[package]
name = "vocab"
version = "0.1.0"
edition = "2026"
TOML
printf 'int main(void){ return 0; }\n' >"$probe/src/main.c"
printf '[bin.app]\nsources = [file("src/main.c")]\n\n[bin.app.private]\nflags = ["-DX" when cfg.sanitizer == "asan"]\n' \
    >"$probe/dowel.build"

diag unknown-cfg-key "a key outside the vocabulary is refused" -C "$probe" check

run -C "$probe" check
said=$OUT
_last_cmd="dowel check  # cfg.sanitizer"; OUT=$(printf '%s' "$said" | grep -m5 'note\|error'); RC=0
printf '%s' "$said" | grep -qi 'vocabulary is closed'
fact $? "saying the vocabulary is closed, rather than that this name is merely unrecognised"

_last_cmd="同じ診断"; OUT=$(printf '%s' "$said" | grep -m5 'note'); RC=0
printf '%s' "$said" | grep -q 'cfg accepts\|`cfg` accepts'
fact $? "listing what that namespace does accept"

# ここが要点である。自分の軸は機能フラグの側にある、と行き先を言う。
_last_cmd="同じ診断"; OUT=$(printf '%s' "$said" | grep -m5 'note'); RC=0
printf '%s' "$said" | grep -q '\[features\]' && printf '%s' "$said" | grep -q 'feature.sanitizer'
fact $? "and where a project's own axis belongs, spelled with the name that was written"

rm -rf "$probe"

# 語彙の状態は機械可読の側にも出る。`schema dump` は文書が「the live
# version」と呼ぶものであり、言語サーバもここを読む。決定と食い違っていると、
# 読んだ側の合理的な判断は「当てにしない」になる
# （[F-059](../../docs/10-findings.md#f-059)）。
got=$("$DOWEL" schema dump 2>/dev/null | jq -r '.cfg.status')
_last_cmd="dowel schema dump | .cfg.status"; OUT="$got"; RC=0
printf '%s' "$got" | grep -qi 'closed'
fact $? "the schema says the configuration vocabulary is closed, as the decision did"

# 同じ手続きが ABI 札の成分にも及ぶ（ADR-0042）。開いた集合にすると、
# 綴り違いの成分は「誰も名指していない成分」になり、それは「制約ではない」
# の形そのものである——受理され、何とも比べられず、何も意味しない。

abi_probe=$(mktemp -d)
mkdir -p "$abi_probe/src"
cat >"$abi_probe/dowel.toml" <<'TOML'
[package]
name = "abivocab"
version = "0.1.0"
edition = "2026"
TOML
printf 'int lib(void){ return 0; }\n' >"$abi_probe/src/lib.c"

# abi_decl <札> — 1つのライブラリの public.abi を書き換える。
abi_decl() {
    printf '[lib.l]\nsources = [file("src/lib.c")]\n\n[lib.l.public]\nabi = %s\n' \
        "$1" >"$abi_probe/dowel.build"
}

abi_decl '{ libcc = "musl" }'
diag unknown-abi-component "a component outside the vocabulary is refused" \
     -C "$abi_probe" check
run -C "$abi_probe" check
said=$OUT
_last_cmd="dowel check  # abi = { libcc = ... }"
OUT=$(printf '%s' "$said" | grep -m5 'note\|error'); RC=0
printf '%s' "$said" | grep -q 'abi. accepts'
fact $? "listing the components abi does accept"
_last_cmd="同じ診断"; OUT=$(printf '%s' "$said" | grep -m5 'note'); RC=0
printf '%s' "$said" | grep -qi 'closed'
fact $? "and saying that this vocabulary is closed too"
_last_cmd="同じ診断"; OUT=$(printf '%s' "$said" | grep -m5 'note'); RC=0
printf '%s' "$said" | grep -q 'did you mean'
fact $? "and offering the component that was probably meant"

# 成分の値も領域を持つ。名前だけ閉じて値を開けば、`libc = "glibc"` が
# 受理されて `libc = "gnu"` と食い違い続ける。
abi_decl '{ libc = "glibc" }'
diag unknown-abi-component "a value outside a component's domain is refused" \
     -C "$abi_probe" check
out_has "accepts: gnu, musl" "and the domain is listed" -C "$abi_probe" check

# 語彙に在るものは通る。上の拒否が「成分の集合を書くと落ちる」ではないこと
# は、これが無いと言えない。
abi_decl '{ libc = "gnu", cxx_stdlib = "libc++" }'
ok "a label made of known components is accepted" -C "$abi_probe" check

# 1語の札は今までの意味を保つ。語は分解できないので、成分の集合と比べる
# 手立てが無い——だから片方ずつが出会うのは食い違いである。
abi_decl '"gnu11"'
ok "a label written as one word is still accepted" -C "$abi_probe" check

rm -rf "$abi_probe"

# 構成の語彙も1つ増えた。`target.os` はこの軸に答えない——`linux-gnu` と
# `linux-musl` は同じ OS で、繋がらない2つの実行時である（ADR-0042）。
keys=$("$DOWEL" schema dump 2>/dev/null | jq -r '.cfg.keys[].name' | paste -sd' ' -)
_last_cmd="dowel schema dump | .cfg.keys"; OUT="$keys"; RC=0
printf '%s' "$keys" | grep -qw 'target.env'
fact $? "the configuration vocabulary carries the runtime axis the triple names"
dom=$("$DOWEL" schema dump 2>/dev/null | jq -r '.cfg.keys[] | select(.name=="target.env") | .values | join(",")')
_last_cmd="dowel schema dump | target.env values"; OUT="$dom"; RC=0
printf '%s' "$dom" | grep -q 'musl'
fact $? "with a domain, as every key in a closed vocabulary has"

# 閉じていることだけでは、道具の側は「二度と増えない」とも読める。増え方まで
# 述べて初めて、当てにしてよい理由になる——ADR 1本につき鍵1つ、領域つき。
_last_cmd="dowel schema dump | .cfg.status"; OUT="$got"; RC=0
printf '%s' "$got" | grep -qi 'adr' && printf '%s' "$got" | grep -qi 'domain'
fact $? "and says how the vocabulary grows, which is what makes it dependable"

# 語彙そのものは正しい。壊れているのは報せ方の1行だけである。
keys=$("$DOWEL" schema dump 2>/dev/null | jq -r '.cfg.keys[].name' | paste -sd' ' -)
_last_cmd="dowel schema dump | .cfg.keys"; OUT="$keys"; RC=0
printf '%s' "$keys" | grep -qw 'cfg.opt' && printf '%s' "$keys" | grep -qw 'target.os' &&
    ! printf '%s' "$keys" | grep -qw 'cfg.sanitizer'
fact $? "while the vocabulary it lists is the one the diagnostic enforces"
