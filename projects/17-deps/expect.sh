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

# ------------------------------------------------------------ 道具立て

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
        jq -r '.actions[] | select(.kind == "link") | .command | join(" ")'
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
          jq -r '.actions[] | select(.kind == "cc") | .command | join(" ")')
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

# ------------------------------------------------------------ 6. リンクの閉包 (F-018)
#
# 静的な書庫は自分のリンク要件を運べない。したがって lib が private に持つ
# リンク要件も、依存元の最終リンクへ届かなければ解けない。
#
# 書庫の側は既に閉包を辿っている。届いていないのは link_flags だけである。

# 前提。private のままでも、demokit の書庫は top のリンク行に現れる。
printf '%s' "$(link_command chain/top)" | grep -q 'libdemokit.a'
fact $? "the archive of a private system dependency reaches the final link"

# そして、private のままなら見出しは依存元へ漏れない。これは正しい。
cxx=$("$DOWEL" -C chain/top graph --kind=action --format=json 2>/dev/null |
      jq -r '.actions[] | select(.kind == "cc" and .target == "top:top") | .command | join(" ")')
_last_cmd="cc_args top:top"
OUT=$cxx
RC=0
! printf '%s' "$cxx" | grep -q 'DEMOKIT'
fact $? "keeping a system dependency private does not leak its includes"

# だが、リンクフラグも一緒に落ちる。
printf '%s' "$(link_command chain/top)" | grep -q -- '-lm'
verdict=$?
known_issue F-018
fact $verdict "the link flags of a private system dependency reach the final link"

built=$("$DOWEL" -C chain/top build --no-compdb 2>&1)
case $built in *"undefined reference"*) v=1 ;; *) v=0 ;; esac
_last_cmd="dowel -C chain/top build"
OUT=$built
RC=0
known_issue F-018
fact $v "a library that keeps a system dependency private still links its dependent"

# public にすると通る。ただし見出しも一緒に届く。両立できないことが
# この所見の中身である。
sed -i 's/\[lib\.mid\.private\]/[lib.mid.public]/' chain/mid/dowel.build
rm -rf chain/top/.dowel/build
ok "declaring the same dependency public does link" -C chain/top build --no-compdb

printf '%s' "$(link_command chain/top)" | grep -q -- '-lm'
fact $? "a public system dependency puts its link flags on the final link"

cxx=$("$DOWEL" -C chain/top graph --kind=action --format=json 2>/dev/null |
      jq -r '.actions[] | select(.kind == "cc" and .target == "top:top") | .command | join(" ")')
_last_cmd="cc_args top:top"
OUT=$cxx
RC=0
printf '%s' "$cxx" | grep -q 'DEMOKIT'
fact $? "but a public system dependency also hands its defines to the dependent"
