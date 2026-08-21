# apps/winapp — Windows
#
# ここまでのクロスは、対象が違っても**同じ族のコンパイラ**だった
# （gcc とその aarch64 版、arm-none-eabi 版）。Windows は違う軸を持ち込む。
# 実行ファイルの綴りが変わり（`.exe`）、行末が変わり（CRLF）、経路の区切りが
# 変わり（`\`）、そして族がもう1つある（MSVC）。
#
#   app/   1つのパッケージで手元と Windows の両方へ組む。可搬な規則は
#          共有し、答だけを構成ごとに差し替える
#
# この層でしか問われないもの。
#
#   - **成果物の綴りが対象で変わる。** `bin/wt` と `bin/wt.exe` は
#     別の名前である。dowel が名乗る経路が、書かれた経路と一致するか
#   - **走らせる側。** wine を runner に据えて、組んだものを実際に起動できるか
#   - **対象ごとにソースを差し替える。** `target.os` で書けるか
#   - **もう1つの族。** MSVC の綴りで組めるか
#
# この3つは当初いずれも壊れていた（F-050 / F-051 / F-053）。いまはどれも
# 直っており、検査は**直った機構を実際に使う形**へ書き換えてある。

WINE=wine
export WINEDEBUG=-all

TRIPLE=x86_64-pc-windows-gnu

# win_build_dir — Windows 向けのビルドディレクトリ。
win_build_dir() { printf 'app/.dowel/build/%s-debug' "$TRIPLE"; }

# wine_run <実行ファイル> <引数...> — wine を通して走らせる。
#
# 出力から CR を落とす。Windows の実行時は stdout を text mode で開くので、
# `\n` は `\r\n` になって出てくる。比較の前にここで揃えないと、答が合って
# いても文字列としては一致しない——これも「対象が変わると綴りが変わる」
# 系統の話であり、行末の検査そのものは `norm` の側で見ている。
wine_run() { timeout 300 $WINE "$@" 2>/dev/null | tr -d '\r'; }

# ------------------------------------------------------------ 1. 手元で組む
#
# 同じパッケージが手元の機械へも組める。可搬な規則の検査はここで済ませる——
# wine を通すより速く、落ちたときに読みやすい。

ok "the package passes check"              -C app check
ok "it builds for the host"                -C app build --no-compdb
ok "and its cases pass there"              -C app test --no-compdb

host=$(cd app && ./.dowel/build/*-unknown-linux-gnu-debug/bin/wt 2>&1)
_last_cmd="wt (host)"; OUT="$host"; RC=0
printf '%s' "$host" | grep -q 'eol=lf sep=/'
fact $? "the host build reports the host's line ending and separator"

# ------------------------------------------------------------ 2. Windows へ組む
#
# 同じマニフェスト、同じソース。違うのは `--target` と、そこから選ばれる
# 構成ごとの実装1つだけである。

ok "the same package builds for Windows" -C app build --target=$TRIPLE --no-compdb

# 対象ごとの差し替えが効いていること。可搬な側は共有され、答だけが変わる。
picked=$("$DOWEL" -C app graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
         jq -r '.steps[] | select(.kind == "cc") | .arguments[] | select(test("src/plat"))' |
         sed 's|.*/||' | sort -u)
_last_cmd="graph --target=$TRIPLE | translated plat_*"; OUT="$picked"; RC=0
[ "$picked" = "plat_win.c" ]
fact $? "the Windows implementation is the one translated, and only it"

shared=$("$DOWEL" -C app graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
         jq -r '.steps[] | select(.kind == "cc") | .arguments[] | select(test("src/text.c"))' | head -1)
_last_cmd="graph --target=$TRIPLE | text.c"; OUT="${shared:-(absent)}"; RC=0
[ -n "$shared" ]
fact $? "while the portable source is shared, not duplicated per target"

# toolchain も対象で変わる。手元の cc が Windows 向けの物を作ってはならない。
prog=$("$DOWEL" -C app graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
       jq -r '.steps[] | select(.kind == "cc") | .program' | sort -u)
_last_cmd="graph --target=$TRIPLE | .program"; OUT="$prog"; RC=0
[ "$prog" = "x86_64-w64-mingw32-gcc" ]
fact $? "and the compiler is the one the triple's toolchain table named"

# ------------------------------------------------------------ 3. 綴りが対象で変わる
#
# Windows のドライバは `bin/wt` と言われても `bin/wt.exe` を書く。
# 成果物の綴りは `target.os` に従う（F-050 の修正）。以前は dowel が
# その綴りを知らず、名乗る経路と書かれた経路が食い違っていた。

d=$(win_build_dir)
_last_cmd="ls $d/bin"; OUT=$(ls "$d/bin" 2>&1); RC=0
[ -f "$d/bin/wt.exe" ]
fact $? "the Windows build really produces an executable"

said=$("$DOWEL" -C app build --target=$TRIPLE --no-compdb 2>&1 |
       sed -n 's/^built: //p' | grep -m1 'bin/wt$\|bin/wt\.exe$')
_last_cmd="dowel build --target=$TRIPLE | built:"
OUT="said:    ${said:-(none)}"$'\n'"on disk: $(ls "$d/bin"/wt* 2>/dev/null | paste -sd' ' -)"
[ -n "$said" ] && [ -f "$said" ]
fact $? "the artifact dowel names is the file that was written"

# 綴りは対象に従う（`target.os`）。手元向けには `.exe` が付かない。
h=$("$DOWEL" -C app build --no-compdb 2>&1 | sed -n 's/^built: //p' | grep -m1 'bin/wt')
_last_cmd="dowel build | built:   （手元向け）"
OUT="windows: ${said:-(none)}"$'\n'"host:    ${h:-(none)}"
RC=0
case $said in *.exe) case $h in *.exe) v=1 ;; *) v=0 ;; esac ;; *) v=1 ;; esac
fact $v "and the suffix follows the target, so the host build keeps none"

# ------------------------------------------------------------ 4. 走らせる
#
# 手で wine に渡した場合と、宣言した runner を通した場合の両方を見る。
# 以前は前者だけが通り、後者は `.exe` の付かない経路が渡って起動できなかった。

got=$(wine_run "$d/bin/wt.exe")
_last_cmd="wine wt.exe"; OUT="$got"; RC=0
printf '%s' "$got" | grep -q 'eol=crlf'
fact $? "run under wine by hand, the Windows build reports CRLF"

_last_cmd="wine wt.exe"; OUT="$got"; RC=0
printf '%s' "$got" | grep -q 'sep=\\'
fact $? "and the Windows path separator"

# Win32 を本当に呼んでいること。可搬な代わりでは答えられない値を出す。
_last_cmd="wine wt.exe"; OUT="$got"; RC=0
printf '%s' "$got" | grep -qE 'page=[0-9]+'
fact $? "and a value only the Win32 API could have given it"

# 混ざった経路。Windows では '/' も区切りである。
got=$(wine_run "$d/bin/wt.exe" base 'C:\a/b.txt')
_last_cmd="wine wt.exe base 'C:\\a/b.txt'"; OUT="$got"; RC=0
[ "$got" = "b.txt" ]
fact $? "a path mixing both separators is split the way Windows splits it"

got=$(wine_run "$d/bin/wt.exe" norm 'a
b')
_last_cmd="wine wt.exe norm"; OUT="$got"; RC=0
[ "$got" = 'a\r\nb' ]
fact $? "and a bare LF is normalised to the Windows line ending"

# ここまでが手で渡した場合。宣言した runner を通しても同じである。
run test --target=$TRIPLE --no-compdb -C app
_last_cmd="dowel test --target=$TRIPLE"
OUT=$(printf '%s' "$OUT" | grep -m6 'test result\|c0000135\|failed to open')
[ "$RC" -eq 0 ]
fact $? "and a Windows target can be tested through its runner"

# 事例のラベルまで届く。走ったのが4件であること——`.exe` の付かない道を
# 渡していた頃は、ここが4件とも起動できずに落ちていた。
_last_cmd="dowel test --target=$TRIPLE | 事例"; RC=0
OUT=$("$DOWEL" -C app test --target=$TRIPLE --no-compdb 2>&1 | grep -c '^test winapp:unit/')
[ "$OUT" = 4 ]
fact $? "with each declared case launched in its own right"

# ------------------------------------------------------------ 5. もう1つの族
#
# MSVC は名指しできるだけでなく、**その綴りで組める**（ADR-0027、F-051 の
# 修正）。道具の名前と、dowel が組み立てる引数の様式は別のものであり、
# 後者を `style` として宣言できる。triple からも導かれる（`*-msvc` → msvc）。
#
# 本物の MSVC は手元に無い。確かめたいのは「MSVC が使えるか」ではなく
# **引数の形が族に合っているか**であり、それは計画を読めば分かる。
# 偽の cl / lib / link を PATH に置いて、組まずに計画だけを読む。

fake=$(mktemp -d)
for t in cl lib link; do printf '#!/bin/sh\nexit 0\n' >"$fake/$t"; chmod +x "$fake/$t"; done

msvc=$(mktemp -d)
mkdir -p "$msvc/src"
cat >"$msvc/dowel.toml" <<'TOML'
[package]
name = "msvc"
version = "0.1.0"
edition = "2026"

[toolchain.x86_64-pc-windows-msvc]
c  = "cl"
ar = "lib"
TOML
cat >"$msvc/dowel.build" <<'BUILD'
[bin.app]
sources = [file("src/main.c")]
BUILD
printf 'int main(void){ return 0; }\n' >"$msvc/src/main.c"

plan=$(PATH="$fake:$PATH" "$DOWEL" -C "$msvc" graph --kind=action --format=json \
         --target=x86_64-pc-windows-msvc 2>/dev/null |
       jq -r '.steps[] | "\(.program) \(.arguments | join(" "))"' |
       sed "s|$msvc/||g; s|\.dowel/build/[^ ]*/||g")

_last_cmd="graph --target=x86_64-pc-windows-msvc, with cl / lib / link on PATH"
OUT="$plan"
RC=0
[ -n "$plan" ]
fact $? "a manifest may name cl as the compiler for the MSVC triple"

# 引数が MSVC の綴りであること。ここが「宣言できている」の中身である。
_last_cmd="the planned arguments for cl"; OUT="$plan"; RC=0
printf '%s' "$plan" | grep -q -- '/c ' && printf '%s' "$plan" | grep -q -- '/Fo:'
fact $? "an MSVC toolchain can be declared, not just named"

# `-MD` が出ないこと。MSVC ではそれは**動的 CRT の指定**であり、依存の
# 記録を頼んだつもりが結合の指定になる。この衝突が、様式を利用者に
# 任せられない理由そのものである。
_last_cmd="the planned arguments | -MD"; OUT="$plan"; RC=0
! printf '%s' "$plan" | grep -q -- '-MD'
fact $? "without asking for a dependency record in a spelling that means the dynamic CRT there"

_last_cmd="the planned arguments | /showIncludes"; OUT="$plan"; RC=0
printf '%s' "$plan" | grep -q -- '/showIncludes'
fact $? "using the spelling that does mean it under this style"

# リンクは別の実行ファイルである。GNU の族ではドライバが兼ねる。
prog=$(printf '%s' "$plan" | sed -n '2p' | cut -d' ' -f1)
_last_cmd="the planned link step"; OUT="$plan"; RC=0
[ "$prog" = "link" ]
fact $? "and the link runs through a separate program, as that toolchain has it"

# 成果物の綴りも様式に従う。`.obj` と `.exe`、`lib<name>.a` ではなく。
_last_cmd="the planned outputs"; OUT="$plan"; RC=0
printf '%s' "$plan" | grep -q '\.obj' && printf '%s' "$plan" | grep -q '/OUT:'
fact $? "with the object and output spellings that toolchain writes"

# 対照。GNU の族へ向けたときは、同じ引数が GNU の綴りである。
gnu=$("$DOWEL" -C app graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc") | .arguments | join(" ")' | head -1)
_last_cmd="graph --target=$TRIPLE | cc arguments"
OUT=$(printf '%s' "$gnu" | tr ' ' '\n' | grep -m6 '^-')
RC=0
printf '%s' "$gnu" | grep -q -- '-MD -MF'
fact $? "while the GNU family still gets the spelling that is correct for it"

rm -rf "$fake" "$msvc"

# ------------------------------------------------------------ 6. 対象の OS
#
# 書きたいのは「対象が Windows なら」である。それが `target.os` として
# 語彙に入った（F-053 の修正）。以前あったのは組む側の OS（`host.os`）と
# 対象の triple そのもの（`cfg.target`）だけで、素直に `match host.os` と
# 書くと、Windows 向けに組んでも POSIX 側が選ばれていた。

keys=$("$DOWEL" schema dump 2>/dev/null | jq -r '.cfg.keys[].name' | paste -sd' ' -)
_last_cmd="dowel schema dump | .cfg.keys"; OUT="$keys"; RC=0
printf '%s' "$keys" | grep -qw 'target.os'
fact $? "a manifest can select sources by the target's operating system"

# 有限領域であること。ここが数え上げとの本質的な差である——腕の網羅性が
# 検査されるので、対象が増えたときに**マニフェストが落ちて教えてくれる**。
# `cfg.target` は開いた領域なので `_` が要り、書き忘れは静かに落ちる。
dom=$("$DOWEL" schema dump 2>/dev/null |
      jq -r '.cfg.keys[] | select(.name == "target.os") | "\(.domain) \(.values | join(","))"')
_last_cmd="schema dump | target.os"; OUT="$dom"; RC=0
printf '%s' "$dom" | grep -q '^finite' && printf '%s' "$dom" | grep -q 'none'
fact $? "and that key has a finite domain, so a match on it is checked for exhaustiveness"

# 実際に効いていること。マニフェストは `match target.os` で書いてある。
_last_cmd="grep target.os app/dowel.build"; RC=0
OUT=$(grep -n 'target\.os' app/dowel.build)
[ -n "$OUT" ]
fact $? "which is how this application actually spells the choice"

_last_cmd="graph --target=$TRIPLE | translated plat_*"; OUT="$picked"; RC=0
[ "$picked" = "plat_win.c" ]
fact $? "and it selects the Windows implementation when the target is Windows"

# そして `host.os` は組む側を指したままである。両方が要る——走らせられるか、
# その機械にしか無い道具があるか、を見たい場面は実在する。
hos=$("$DOWEL" schema dump 2>/dev/null |
      jq -r '.cfg.keys[] | select(.name == "host.os") | .doc')
_last_cmd="schema dump | host.os"; OUT="$hos"; RC=0
printf '%s' "$hos" | grep -qi 'build host'
fact $? "while host.os still means the build machine, so the pair is complete"

# ------------------------------------------------------------ 7. 二つの対象が混ざらない
#
# 同じ木を両方へ組んだあと、それぞれの成果物が相手の答を持っていないこと。

hb=$(cd app && ls -d .dowel/build/*-unknown-linux-gnu-debug 2>/dev/null | head -1)
_last_cmd="ls app/.dowel/build"; RC=0
OUT=$(cd app && ls -d .dowel/build/*/ | sed 's|.*/build/||')
[ -n "$hb" ] && [ -d "$(win_build_dir)" ]
fact $? "the two targets keep separate build directories"

kind=$(file -b "$(win_build_dir)/bin/wt.exe" 2>/dev/null)
_last_cmd="file wt.exe"; OUT="$kind"; RC=0
printf '%s' "$kind" | grep -qi 'PE32+\|MS Windows'
fact $? "and what the Windows directory holds is a Windows executable"

kind=$(file -b "app/$hb/bin/wt" 2>/dev/null)
_last_cmd="file wt (host)"; OUT="$kind"; RC=0
printf '%s' "$kind" | grep -qi 'ELF'
fact $? "while the host directory holds an ELF one, from the same sources"

# ------------------------------------------------------------ 8. 増分
#
# 綴りが揃うと、増分も収束する。宣言された出力が実在しない間は、出力の
# 無いアクションが「まだ作られていない」ままになり、何を触らなくても
# リンクが毎回やり直されていた（F-050 の4つ目の面）。組む段は成功して
# 見えるので、手がかりは所要時間しか無かった。

build_direct -C app --target=$TRIPLE --no-compdb
n=$(_ran_actions)
[ "${n:-1}" = 0 ]
verdict=$?
RC=0; _last_cmd="dowel build --target=$TRIPLE, twice, touching nothing"
OUT="ran ${n:-?} steps the second time"
fact $verdict "a second Windows build runs nothing"

# 対照。同じ木を手元へ組めば 0 件に収束する。差は対象だけである。
runs_actions 0 "while a second host build of the same tree runs nothing" -C app --no-compdb

printf '\n/* touched */\n' >>app/src/plat_win.c
build_direct -C app --target=$TRIPLE --no-compdb
rebuilt "plat_win.c" "editing the Windows implementation recompiles it"
not_rebuilt "text.c" "and leaves the portable source alone"

# 手元の側は、Windows 側の実装を触っても組み直らない。選ばれていないため
# 依存にすら入っていない。
runs_actions 0 "and the host build is untouched by it, because it never used that source" \
    -C app --no-compdb
