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
#   - **対象ごとにソースを差し替える。** 語彙に対象の OS が無い
#   - **もう1つの族。** MSVC は名指しできるが、出てくる引数は GNU の形である
#
# 3つが未修正である（F-050 / F-051 / F-053）。それぞれ対照を置いて、
# 「組めないから確かめられない」のか「組めるのに使えない」のかを分ける。

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

# 道具立ても対象で変わる。手元の cc が Windows 向けの物を作ってはならない。
prog=$("$DOWEL" -C app graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
       jq -r '.steps[] | select(.kind == "cc") | .program' | sort -u)
_last_cmd="graph --target=$TRIPLE | .program"; OUT="$prog"; RC=0
[ "$prog" = "x86_64-w64-mingw32-gcc" ]
fact $? "and the compiler is the one the triple's toolchain table named"

# ------------------------------------------------------------ 3. 綴りが対象で変わる
#
# Windows のドライバは `bin/wt` と言われても `bin/wt.exe` を書く。
# dowel はその綴りを知らないので、名乗る経路と書かれた経路が食い違う。

d=$(win_build_dir)
_last_cmd="ls $d/bin"; OUT=$(ls "$d/bin" 2>&1); RC=0
[ -f "$d/bin/wt.exe" ]
fact $? "the Windows build really produces an executable"

said=$("$DOWEL" -C app build --target=$TRIPLE --no-compdb 2>&1 |
       sed -n 's/^built: //p' | grep -m1 'bin/wt$\|bin/wt\.exe$')
_last_cmd="dowel build --target=$TRIPLE | built:"
OUT="said:    ${said:-(none)}"$'\n'"on disk: $(ls "$d/bin"/wt* 2>/dev/null | paste -sd' ' -)"
known_issue F-050
[ -n "$said" ] && [ -f "$said" ]
fact $? "the artifact dowel names is the file that was written"

# ------------------------------------------------------------ 4. 走らせる
#
# runner の宣言は足りている。足りていないのは渡される経路の綴りだけである。
# それを分けるために、同じ実行ファイルを手で wine に渡して確かめる。

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

# ここまでが手で渡した場合。宣言した runner を通すと、`.exe` の付かない
# 経路が渡り、wine は起動できない（c0000135 = image not found）。
run test --target=$TRIPLE --no-compdb -C app
_last_cmd="dowel test --target=$TRIPLE"
OUT=$(printf '%s' "$OUT" | grep -m6 'test result\|c0000135\|failed to open')
known_issue F-050
[ "$RC" -eq 0 ]
fact $? "and a Windows target can be tested through its runner"

# ------------------------------------------------------------ 5. もう1つの族
#
# MSVC は名指しできる。`[toolchain.<triple>] c = "cl"` は通り、計画も立つ。
# 出てくるのは GNU の引数である。`-c` `-o` は `cl` の綴りではなく、
# `-MD` に至っては MSVC では**動的 CRT の指定**であり、意味が衝突する。

fake=$(mktemp -d)
for t in cl lib; do printf '#!/bin/sh\nexit 0\n' >"$fake/$t"; chmod +x "$fake/$t"; done

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

_last_cmd="graph --target=x86_64-pc-windows-msvc, with cl and lib on PATH"
OUT="$plan"
RC=0
[ -n "$plan" ]
fact $? "a manifest may name cl as the compiler for the MSVC triple"

# 名乗れるだけである。以下が「宣言できていない」ことの中身になる。
_last_cmd="the planned arguments for cl"; OUT="$plan"; RC=0
known_issue F-051
! printf '%s' "$plan" | grep -q -- '-MD -MF'
fact $? "an MSVC toolchain can be declared, not just named"

# 対照。GNU の族へ向けたときは、同じ引数が正しい綴りである。
gnu=$("$DOWEL" -C app graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc") | .arguments | join(" ")' | head -1)
_last_cmd="graph --target=$TRIPLE | cc arguments"
OUT=$(printf '%s' "$gnu" | tr ' ' '\n' | grep -m6 '^-')
RC=0
printf '%s' "$gnu" | grep -q -- '-MD -MF'
fact $? "the same argument shape is correct for the GNU family, which is what it was written for"

rm -rf "$fake" "$msvc"

# ------------------------------------------------------------ 6. 対象の OS
#
# 書きたいのは「対象が Windows なら」である。語彙にあるのは組む側の OS と、
# 対象の三つ組そのものだけである。

_last_cmd="dowel schema dump | .cfg.keys"
OUT=$("$DOWEL" schema dump 2>/dev/null | jq -r '.cfg.keys[].name' | paste -sd' ' -)
RC=0
known_issue F-053
printf '%s' "$OUT" | grep -qw 'target.os'
fact $? "a manifest can select sources by the target's operating system"

# 今ある綴りは効く。三つ組を数え上げる形は正しく選ぶ。
_last_cmd="graph --target=$TRIPLE | translated plat_*"; OUT="$picked"; RC=0
[ "$picked" = "plat_win.c" ]
fact $? "enumerating triples does select correctly, which is the workaround it forces"

# そして `host.os` は組む側を指す。Windows 向けに組んでも linux のままである。
# 「そういうものである」ことを固定する——値が変わったらこちらが気づけるように。
hos=$("$DOWEL" -C app schema dump 2>/dev/null |
      jq -r '.cfg.keys[] | select(.name == "host.os") | .doc')
_last_cmd="schema dump | host.os"; OUT="$hos"; RC=0
printf '%s' "$hos" | grep -qi 'build host'
fact $? "and host.os is documented as the build machine, not the target"

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
# 宣言された出力 `bin/wt` は永久に存在しない（書かれるのは `bin/wt.exe`）。
# 出力の無いアクションは「まだ作られていない」ので、何を触らなくても
# リンクが毎回やり直される。組む段は成功したように見えるので、手がかりは
# 所要時間しか無い（F-050 の4つ目の面）。

build_direct -C app --target=$TRIPLE --no-compdb
n=$(_ran_actions)
[ "${n:-1}" = 0 ]
verdict=$?
RC=0; _last_cmd="dowel build --target=$TRIPLE, twice, touching nothing"
OUT="ran ${n:-?} steps the second time"
known_issue F-050
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
