# 17-deps — システムパッケージへの依存と dowel.lock
#
# `version = "..."` はシステムの pkg-config へ委譲して解決される（ADR-0015）。
# `path` と `git` と違い、**何が来るかは環境が決める**。だから記録が要る。
# ここで固定するのは3つ。
#
#   1. 解決の結果が翻訳とリンクへ正しく届くか
#   2. 解決できないときに、直し方の分かる形で拒むか
#   3. 環境が変わったときに、黙って別のものを使わないか
#
# 相手にするシステムは system/ に置いた .pc である。実際のシステムには
# 触れない。機械に入っているものを相手にすると、検査が落ちたときに直すのが
# dowel なのか機械なのかを判断できなくなる（docs/00-design.md 6節）。

export PKG_CONFIG_PATH="$PWD/system"

# ------------------------------------------------------------ 下ごしらえ

# lock <パッケージ> — そのパッケージの dowel.lock の中身。
lock() { cat "$1/dowel.lock" 2>/dev/null; }

# lock_has <パッケージ> <文字列> <desc> — 記録に1行があること。
lock_has() {
    _last_cmd="cat $1/dowel.lock"
    OUT=$(lock "$1")
    RC=0
    printf '%s' "$OUT" | grep -qF -- "$2"; _verdict $? "$3"
}

# without_pkg_config <dowel args...> — pkg-config だけが無い PATH で走らせる。
# PATH を丸ごと消すとコンパイラも消え、観測しているものが混ざる。
_shim=""
shim_path() {
    [ -n "$_shim" ] && { printf '%s' "$_shim"; return 0; }
    _shim="$PWD/.nopkgconfig"
    mkdir -p "$_shim"
    local t p
    for t in cc gcc g++ ar ninja sh env uname; do
        p=$(command -v "$t" 2>/dev/null) && ln -sf "$p" "$_shim/$t"
    done
    printf '%s' "$_shim"
}

# link_command <パッケージ> — その木の link アクションの引数（改行区切り）。
link_command() {
    "$DOWEL" -C "$1" graph --kind=action --format=json 2>/dev/null |
        jq -r '.steps[] | select(.kind == "link") | ([.program] + .arguments) | join(" ")'
}

# ------------------------------------------------------------ 1. 解決

ok "a version dependency resolves through pkg-config" -C app check

# 解決したモジュールは合成のノードとして木に入る。数に出るのは、
# 「解決したことにして何もしていない」状態と区別するためである。
out_has "2 packages" "the resolved module enters the graph as a package" \
    -C app check

ok "a package with a resolved system dependency builds" -C app build --no-compdb

# --cflags が翻訳に届かなければ app/src/main.c の #error で止まる。
# --libs が最終リンクに届かなければ demokit_root が解けない。
# どちらも組めた時点で通っているが、走らせるまでが1つの事実である。
prints "42 42" "the module's cflags and libs both reach the build" \
    "$PWD/$(find app/.dowel/build -type f -path '*/bin/app' | head -1)"

args_have_app() {
    _last_cmd="cc_args app:app | grep -F -- $1"
    OUT=$("$DOWEL" -C app graph --kind=action --format=json 2>/dev/null |
          jq -r '.steps[] | select(.kind == "cc") | ([.program] + .arguments) | join(" ")')
    RC=0
    printf '%s' "$OUT" | grep -qF -- "$1"; _verdict $? "$2"
}
args_have_app '-DDEMOKIT=1' "the module's --cflags become compile flags"

printf '%s' "$(link_command app)" | grep -q -- '-lm'
fact $? "the module's --libs become link flags"

# ------------------------------------------------------------ 2. 版は下限
#
# 宣言した版は最小値である。比較は pkg-config 自身が行い、dowel は
# 大小の判定を持たない（ADR-0015）。system/demokit.pc は 2.4.0 である。

declare_version() { sed -i "s/^version *= *\"[0-9.]*\"$/version = \"$1\"/" app/dowel.toml; }
app_version_line() { grep -c 'version = ' app/dowel.toml; }

# [package] にも version があるため、依存の側だけを書き換える。
set_dep_version() {
    python3 - "$1" <<'PY'
import re, sys
p = "app/dowel.toml"
text = open(p, encoding="utf-8").read()
head, sep, dep = text.partition("[[dependencies]]")
dep = re.sub(r'version\s*=\s*"[^"]*"', 'version = "%s"' % sys.argv[1], dep, count=1)
open(p, "w", encoding="utf-8").write(head + sep + dep)
PY
}

set_dep_version 2.4.0
ok "a version equal to what the system has is satisfied" -C app check

set_dep_version 1.0
ok "a version below what the system has is satisfied" -C app check

set_dep_version 9.9
fails "a version above what the system has is refused" -C app check
diag unsatisfied-dependency \
    "the refusal carries the unsatisfied-dependency code" -C app check
diag_where unsatisfied-dependency '.message | test("does not satisfy")' \
    "the refusal names the constraint that was not met" -C app check
diag_where unsatisfied-dependency '.notes | join(" ") | test("minimum")' \
    "the refusal says the constraint is a minimum" -C app check
diag_where unsatisfied-dependency '.labels[0].file | test("dowel.toml$")' \
    "the refusal points at the declaration in dowel.toml" -C app check
diag_where unsatisfied-dependency '.labels[0].byte_end > .labels[0].byte_start' \
    "the refusal spans the declaration, not the whole file" -C app check

set_dep_version 2.0

# ------------------------------------------------------------ 3. 解決できないとき

sed -i 's/^name *= *"demokit"$/name    = "nosuchmodule"/' app/dowel.toml
sed -i 's/dep("demokit")/dep("nosuchmodule")/' app/dowel.build
fails "a module the system does not have is refused" -C app check
diag unsatisfied-dependency \
    "an unknown module is refused with the same code as a version mismatch" \
    -C app check
diag_where unsatisfied-dependency '.notes | join(" ") | test("path|git")' \
    "the refusal names path and git as the way out" -C app check
sed -i 's/^name *= *"nosuchmodule"$/name    = "demokit"/' app/dowel.toml
sed -i 's/dep("nosuchmodule")/dep("demokit")/' app/dowel.build
ok "putting the module name back makes it resolve again" -C app check

# pkg-config そのものが無い場合。委譲先が居ないことは、モジュールが
# 無いこととは別の状況だが、利用者にとっての行き先は同じである。
# _verdict は次の検査へ持ち越さないよう OUT を消すため、2つの判定に使う
# 出力は先に控える。
said=$(PATH=$(shim_path) "$DOWEL" -C app check --message-format=json 2>/dev/null)
_last_cmd="PATH=<no pkg-config> dowel -C app check --message-format=json"
OUT=$said
RC=0
printf '%s' "$said" | jq -e 'select(.code == "unsatisfied-dependency")' >/dev/null 2>&1
fact $? "a version dependency is refused when pkg-config cannot be run"

_last_cmd="PATH=<no pkg-config> dowel -C app check --message-format=json"
OUT=$said
RC=0
printf '%s' "$said" | jq -e 'select(.code == "unsatisfied-dependency")
    | .notes | join(" ") | test("cannot run pkg-config")' >/dev/null 2>&1
fact $? "the refusal says that pkg-config itself could not be run"

# ------------------------------------------------------------ 4. dowel.lock
#
# 記録の目的は復元ではなく漂流の検出である。システムパッケージは取得
# できないため、約束できるのは「前回と違うものを黙って使わない」ことだけ。

lock_has app 'name    = "demokit"' "the resolution is recorded in dowel.lock"
lock_has app 'version = "2.4.0"' \
    "the lock records the version that was resolved, not the one declared"
lock_has app 'source  = "pkg-config"' "the lock names where the resolution came from"
lock_has app 'changed environment is noticed' \
    "the lock says it detects a change rather than restoring one"

# 一致している記録は触らない。毎回書き換わると、版管理の差分が
# 「解決したこと」ではなく「走らせたこと」を表すようになる。
before=$(lock app)
ok "a second check with a matching lock passes" -C app check
[ "$(lock app)" = "$before" ]
fact $? "a matching lock is left byte for byte alone"

no_diag lockfile-drift "a matching lock says nothing" -C app check

# 漂流。記録と違う版が来たときは警告し、書き換えない。
sed -i 's/^version = "2.4.0"$/version = "2.3.0"/' app/dowel.lock
drifted=$(lock app)
diag lockfile-drift "a lock that disagrees with the system warns" -C app check
diag_where lockfile-drift '.severity == "warning"' \
    "the drift is a warning, not an error" -C app check
diag_where lockfile-drift '.message | test("2.4.0") and test("2.3.0")' \
    "the warning names both the resolved version and the recorded one" -C app check
diag_where lockfile-drift '.notes | join(" ") | test("delete")' \
    "the warning says how to accept the new resolution" -C app check

ok "a drifted lock does not fail the build" -C app check
[ "$(lock app)" = "$drifted" ]
fact $? "a drifted lock is never rewritten on its own"

# 受け入れる操作は、記録を消すことである。
python3 - <<'PY'
p = "app/dowel.lock"
text = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(text.split("[[package]]")[0])
PY
ok "removing the entry lets the resolution be recorded again" -C app check
lock_has app 'version = "2.4.0"' "the freshly recorded entry holds what the system has"
no_diag lockfile-drift "and the drift warning is gone" -C app check

# 他人の記録を巻き添えにしない。
python3 - <<'PY'
p = "app/dowel.lock"
open(p, "a", encoding="utf-8").write(
    '\n[[package]]\nname    = "someone-else"\nversion = "0.1"\nsource  = "pkg-config"\n')
PY
ok "an unrelated entry does not disturb the check" -C app check
lock_has app 'name    = "someone-else"' "an unrelated entry in the lock is kept"

# ------------------------------------------------------------ 5. 無効な optional
#
# 無効な optional 依存は辺もノードも作らない。解決も行われないはずである
# （ADR-0015）。pkg-config を引けなくしても通ることで観測する。

_last_cmd="PATH=<no pkg-config> dowel -C gated check"
OUT=$(PATH=$(shim_path) "$DOWEL" -C gated check 2>&1)
RC=$?
[ "$RC" -eq 0 ]
fact $? "an inactive optional version dependency is not resolved at all"

[ ! -f gated/dowel.lock ]
fact $? "an inactive optional version dependency is not recorded either"

ok "enabling the feature resolves the optional module" -C gated check --features=quiet
lock_has gated 'name    = "quiet"' "and then it is recorded"

ok "a module with no link flags builds all the same" \
    -C gated build --features=quiet --no-compdb

# ------------------------------------------------------------ 6. リンクの閉包
#
# 静的な archive は自分のリンク要件を運べない。したがって lib が private に持つ
# リンク要件も、依存元の最終リンクへ届かなければ解けない。
#
# かつては archive だけが閉包を辿り、link_flags は落ちていた（F-018）。
# public/private が制御するのは**翻訳**の伝播であり、リンクの到達可能性では
# ない。ライブラリはシステム依存の見出しを private に保ったまま、なお
# リンクできなければならない。

# 前提。private のままでも、demokit の archive は top のリンク行に現れる。
printf '%s' "$(link_command chain/top)" | grep -q 'libdemokit.a'
fact $? "the archive of a private system dependency reaches the final link"

# そして、private のままなら見出しは依存元へ漏れない。これは正しい。
cxx=$("$DOWEL" -C chain/top graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc" and .target == "top:top") | ([.program] + .arguments) | join(" ")')
_last_cmd="cc_args top:top"
OUT=$cxx
RC=0
! printf '%s' "$cxx" | grep -q 'DEMOKIT'
fact $? "keeping a system dependency private does not leak its includes"

# だが、リンクフラグも一緒に落ちる。
printf '%s' "$(link_command chain/top)" | grep -q -- '-lm'
fact $? "the link flags of a private system dependency reach the final link"

built=$("$DOWEL" -C chain/top build --no-compdb 2>&1)
case $built in *"undefined reference"*) v=1 ;; *) v=0 ;; esac
_last_cmd="dowel -C chain/top build"
OUT=$built
RC=0
fact $v "a library that keeps a system dependency private still links its dependent"

# 翻訳の側は従来どおり private のままである。両方を同時に満たすことが
# 期待値であり、片方だけを満たす直し方（全部 public 扱いにする）は通らない。
cxx=$("$DOWEL" -C chain/top graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc" and .target == "top:top") | ([.program] + .arguments) | join(" ")')
_last_cmd="cc_args top:top"
OUT=$cxx
RC=0
! printf '%s' "$cxx" | grep -q 'DEMOKIT'
fact $? "and its includes are still not leaked to the dependent"

# public にすると通る。ただし見出しも一緒に届く。両立できないことが
# この所見の中身である。
sed -i 's/\[lib\.mid\.private\]/[lib.mid.public]/' chain/mid/dowel.build
rm -rf chain/top/.dowel/build
ok "declaring the same dependency public does link" -C chain/top build --no-compdb

printf '%s' "$(link_command chain/top)" | grep -q -- '-lm'
fact $? "a public system dependency puts its link flags on the final link"

cxx=$("$DOWEL" -C chain/top graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc" and .target == "top:top") | ([.program] + .arguments) | join(" ")')
_last_cmd="cc_args top:top"
OUT=$cxx
RC=0
printf '%s' "$cxx" | grep -q 'DEMOKIT'
fact $? "but a public system dependency also hands its defines to the dependent"

# ------------------------------------------------------------ tarball の依存（ADR-0029）
#
# `url` + `sha256` で、tarball を取ってきて展開する依存が書ける。`version` が
# 環境に委ねるのに対し、こちらは**内容そのもの**で固定する。
#
# 相手にする tarball は手元で作る。実際の網には触れない——落ちたときに直すのが
# dowel なのか回線なのかを判断できなくなる。`file://` で取れるので、
# 取得の経路そのものは本物のまま通せる。
#
# ここで見るのは3つ。
#
#   1. 取れて、展開されて、公開の面が届くこと
#   2. **固定されていなければ拒むこと。** URL は名前であり、名前の後ろの
#      バイトは明日変わりうる
#   3. 一度取ったら網に触らないこと

ARCHIVE=$PWD/greet-1.0.tar.gz
(cd packed && tar czf "$ARCHIVE" greet-1.0)
SUM=$(sha256sum "$ARCHIVE" | cut -d' ' -f1)

# pin <sha256> [url] — archived/dowel.toml の依存を書き換える。
# sha256 が空なら省く。
pin() {
    local sum=$1 url=${2:-file://$ARCHIVE}
    {
        printf '[package]\nname    = "archived"\nversion = "0.1.0"\nedition = "2026"\n\n'
        printf '[[dependencies]]\nname = "greet"\nurl  = "%s"\n' "$url"
        [ -n "$sum" ] && printf 'sha256 = "%s"\n' "$sum"
    } >archived/dowel.toml
    rm -rf archived/.dowel
}

pin "$SUM"
ok "a package declared as a pinned archive builds"        -C archived build --no-compdb
prints "" "and what it built runs" "$(cd archived && artifact archived)"

# 展開先は内容の指紋で名づけられる。版の名前ではない——同じ版の名前で
# 中身が変われば、別のものとして置かれてほしい。
d=$(find archived/.dowel/deps -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)
_last_cmd="ls archived/.dowel/deps"; OUT="${d:-(none)}"; RC=0
printf '%s' "$d" | grep -q "greet-${SUM:0:12}"
fact $? "unpacked into a directory named for the digest of what was fetched"

# tarball の中の唯一の最上位ディレクトリは剥がれる。`name-version/` で包むのが
# 慣習であり、剥がさなければ利用者が毎回その1階層を書くことになる。
_last_cmd="ls \$deps/greet-*"; OUT=$(ls "$d" 2>&1 | paste -sd' ' -); RC=0
[ -f "$d/dowel.toml" ]
fact $? "with the single top-level directory stripped, as the usual wrapper is"

# 公開の面が届く。取ってきたものが依存として本当に効いていること。
# （`args_have` は `-C` を渡さないので、ここは `cc_args` を直に使う。
# ソースの側にも `#error` を置いてあるので、届かなければ翻訳でも落ちる。）
got=$(cc_args archived:archived -C archived)
_last_cmd="cc_args archived:archived -C archived"; OUT="$got"; RC=0
printf '%s' "$got" | grep -q 'GREET_FROM_ARCHIVE'
fact $? "the fetched package's public defines reach the dependent"

# ------------------------------------------------------------ 固定されていなければ拒む

pin ""
diag unpinned-dependency "an archive without a digest is refused" -C archived check
run -C archived check
_last_cmd="dowel check  # sha256 が無い"; OUT=$(printf '%s' "$OUT" | grep -m4 'note\|error'); RC=0
printf '%s' "$OUT" | grep -qi 'different bytes tomorrow'
fact $? "saying why a URL alone is not a pin"

pin "abc123"
diag unpinned-dependency "a digest that is not 64 hex digits is refused too" -C archived check
run -C archived check
_last_cmd="dowel check  # 短い sha256"; OUT=$(printf '%s' "$OUT" | grep -m3 'expected\|error'); RC=0
printf '%s' "$OUT" | grep -q '64 hexadecimal'
fact $? "naming the shape it wanted"

# 指紋が合わなければ、展開する前に止まる。両方の値を出す——片方だけでは
# 「どちらが正しいのか」を利用者が決められない。
pin "0000000000000000000000000000000000000000000000000000000000000000"
run -C archived build --no-compdb
said=$OUT
_last_cmd="dowel build  # 指紋が合わない"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'expected 0000' && printf '%s' "$said" | grep -q "received $SUM"
fact $? "a digest that does not match reports both what was expected and what arrived"

_last_cmd="ls archived/.dowel/deps"; RC=0
OUT=$(ls archived/.dowel/deps 2>&1)
[ ! -d "archived/.dowel/deps" ] || [ -z "$(ls -A archived/.dowel/deps 2>/dev/null)" ]
fact $? "and nothing is unpacked, because the check happens before the archive is opened"

# 取れない先も、直し方の分かる形で拒む。
pin "$SUM" "file://$PWD/no-such-archive.tar.gz"
diag unfetchable-dependency "an archive that cannot be fetched is refused" -C archived check

# ------------------------------------------------------------ 一度取ったら触らない

pin "$SUM"
ok "the archive is fetched once" -C archived build --no-compdb

mv "$ARCHIVE" "$ARCHIVE.moved"
ok "and a later build never reaches for it again" -C archived build --no-compdb
runs_actions 0 "which is a build that runs nothing, having everything already" \
    -C archived --no-compdb
mv "$ARCHIVE.moved" "$ARCHIVE"

# 展開したものを消すと、また取りに行く。消しても壊れないことの対照であり、
# 「触らない」が「二度と取れない」ではないことの確認でもある。
rm -rf archived/.dowel/deps
ok "removing what was unpacked makes the next build fetch it again" \
    -C archived build --no-compdb

# ------------------------------------------------------------ 6. offline（ADR-0045）
#
# 取ってきたものは一度きりで、以降は完了の印を読む。だから「全部揃っている
# 木は、たまたまネットワーク無しでも通る」。誰もそう言っておらず、誰も
# 確かめておらず、そうでなくなったときに誰も教えない。3つが従う。
#
#   ・入力が足りないことが、ネットワークの故障として読める
#   ・備える手立てが無い。全部組んでみる以外に確かめようがない
#   ・保証が無い。「触れなかった」が性質ではなく、たぶんそうだった、になる
#
# 決定は「offline は、そうであるよう告げられる様式であって、たまたま
# そうなっている状態ではない」。

pin "$SUM"
rm -rf archived/.dowel

# 足りないものは `needs-fetch` である。取りに行って失敗した
# `unfetchable-dependency` とは原因が違い、直し方も違う。
diag needs-fetch "a dependency that is not fetched is refused under --offline" \
    -C archived check --offline
out_has "would come from" "and says where it would have come from" \
    -C archived check --offline
out_has "dowel fetch" "and how to get it" -C archived check --offline

# 環境変数でも同じこと。隔離した容器や CI の仕事は一度だけ置きたい——
# 全ての呼び出しに旗を足す形だと、足し忘れた1つが網を破る。
_last_cmd="DOWEL_OFFLINE=1 dowel check"
OUT=$(DOWEL_OFFLINE=1 "$DOWEL" -C archived check 2>&1); RC=$?
printf '%s' "$OUT" | grep -q 'needs-fetch'
fact $? "the environment variable does the same as the flag"

# `dowel fetch` は取ってきて止まる。「offline へ行ける」ことを、
# 推し量るのではなく見られるようにするための入口である。
ok "fetch acquires what the build needs" -C archived fetch
out_has "ready:" "and lists what is now present" -C archived fetch
out_has "--offline" "and says that the build can now run offline" -C archived fetch

n=$(find archived/.dowel -name '*.o' 2>/dev/null | wc -l)
_last_cmd="find archived/.dowel -name '*.o'"; OUT="$n object files"; RC=0
[ "$n" -eq 0 ]
fact $? "fetch compiles nothing"

ok "the build then runs with --offline"       -C archived build --offline --no-compdb
ok "and so does check"                        -C archived check --offline

# 取ってきた先が消えても、取りに行かない。offline は「無い物は無い」で
# あって、「無ければ取りに行く」ではない。
rm -rf archived/.dowel/deps
diag needs-fetch "removing what was unpacked brings needs-fetch back" \
    -C archived check --offline
ok "and fetching once makes it work again" -C archived fetch

# offline はネットワークについての様式であり、「することを減らす」ことでは
# ない。システムの依存の解決は手元の処理を起こして手元のファイルを読む。
# これを拒むと、旗の意味が変わってしまう。
ok "--offline says nothing about resolving a system dependency" \
    -C app check --offline

# 取りに行って失敗したものとは、別の符号で分ける。前者は上流や経路の話で
# あり、後者は「何も試していない」である。自動化した側が、再試行すべきか
# どうかをここで判断する。
pin "$SUM" "file://$PWD/no-such-archive.tar.gz"
rm -rf archived/.dowel
diag unfetchable-dependency "a fetch that was tried and failed has its own code" \
    -C archived check
diag needs-fetch "while the same tree under --offline reports nothing was tried" \
    -C archived check --offline
fails "fetch fails when it cannot acquire what it was asked for" -C archived fetch
pin "$SUM"
