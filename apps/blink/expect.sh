# apps/blink — 組み込み（freestanding）
#
# libc も起動コードも無い対象。入口はベクタ表の先の `_reset` であり、
# 記憶の配置はリンカスクリプトが決める。
#
# 実機は aarch64 の freestanding にしてある。Cortex-M ではなく aarch64 なのは、
# 本スイートが既に要求している道具立てで足りるためである。dowel に効かせる
# 性質（freestanding のフラグ、ベクタ表の配置、生イメージの生成、道具の
# トリプルごとの選択）はどちらでも同じである。
#
# **リンカスクリプトはこの木から指せない**（docs/10-findings.md F-025）。
# ベアメタルでは省略できないものなので、そこが組み込みの最初の関門になる。

TRIPLE=aarch64-unknown-linux-gnu
B=".dowel/build/$TRIPLE-debug/bin"

# ------------------------------------------------------------ 道具立て

RE=aarch64-linux-gnu-readelf
NM=aarch64-linux-gnu-nm

# elf_says <readelf の項目> — 成果物の見出しから1行読む。
elf_says() { $RE -h "$B/firmware" 2>/dev/null | sed -n "s/.*$1: *//p" | head -1; }

# says <期待> <実際> <desc>
says() {
    [ "$1" = "$2" ]
    local v=$?
    RC=0; _last_cmd="readelf -h $B/firmware"
    OUT="want: $1"$'\n'"got:  ${2:-(nothing)}"
    fact $v "$3"
}

# ------------------------------------------------------------ 1. 組める

ok "the freestanding package passes check" check --target=$TRIPLE
ok "and builds"                            build --no-compdb --target=$TRIPLE

# 道具は3つとも宣言してあるが、宣言してあるのは1つの triple に対してだけ
# である。ホストには既定があるため、`--target` を付け忘れると**ホスト向けに
# 組み上がる**。ベアメタルの木にホストの構成は存在しないので、出来上がる
# ものに意味は無い（docs/10-findings.md F-026）。
ok "leaving out --target still builds, because the host has defaults" \
    build --no-compdb

host=$(find .dowel/build -type f -path '*x86_64*/bin/firmware' | head -1)
_last_cmd="find .dowel/build -path '*x86_64*/bin/firmware'"
OUT="built: ${host:-(nothing)}"
RC=0
[ -n "$host" ]
fact $? "and what it builds is a host binary, not firmware"

# 派生まで作られる。書き込み器に食わせるつもりのファイルが、ホストの
# objcopy が作った別物になる。
_last_cmd="find .dowel/build -path '*x86_64*/bin/firmware.bin'"
OUT="$(find .dowel/build -type f -path '*x86_64*/bin/firmware.bin' | head -1)"
RC=0
[ -n "$OUT" ]
fact $? "the raw image is derived for the host too, with nothing to say so"

# 対象を宣言できれば、この取り違えは診断になる。
grep -q '^targets' dowel.toml
verdict=$?
RC=0; _last_cmd="grep '^targets' dowel.toml"
OUT="$(sed -n '1,12p' dowel.toml)"
known_issue F-026
fact $verdict "a package can say which targets it is for"

rm -rf .dowel/build/x86_64-unknown-linux-gnu-debug
"$DOWEL" build --no-compdb --target=$TRIPLE >/dev/null 2>&1

# ------------------------------------------------------------ 2. freestanding
#
# 「組めた」だけでは足りない。libc が混ざっていないことを成果物から読む。

n=$($RE -d "$B/firmware" 2>/dev/null | grep -c NEEDED)
[ "${n:-1}" = 0 ]
v=$?; RC=0; _last_cmd="readelf -d $B/firmware | grep NEEDED"
OUT="NEEDED entries: ${n:-?}"
fact $v "the artifact needs no shared library at run time"

n=$($NM "$B/firmware" 2>/dev/null | grep -ciE ' (printf|malloc|free|__libc)')
[ "${n:-1}" = 0 ]
v=$?; RC=0; _last_cmd="nm $B/firmware | grep libc symbols"
OUT="libc symbols: ${n:-?}"
fact $v "and carries no symbol from the standard library"

says AArch64 "$(elf_says Machine)" "the artifact is for the target architecture"

# 入口はベクタ表の先である。既定の `main` ではない。
entry=$(elf_says 'Entry point address')
reset=$($NM "$B/firmware" 2>/dev/null | sed -n 's/^0*\([0-9a-f]*\) T _reset$/0x\1/p')
[ -n "$entry" ] && [ "$entry" = "$reset" ]
v=$?; RC=0; _last_cmd="readelf -h | Entry point  vs  nm | _reset"
OUT="entry: ${entry:-?}"$'\n'"_reset: ${reset:-?}"
fact $v "the entry point is the reset handler, not a libc start-up routine"

# ベクタ表は誰も参照しない。属性で残すよう指示してある。消えると、
# 実機は立ち上がらない。
n=$($RE -S "$B/firmware" 2>/dev/null | grep -c '\.vectors')
[ "${n:-0}" -ge 1 ]
v=$?; RC=0; _last_cmd="readelf -S $B/firmware | grep .vectors"
OUT="sections named .vectors: ${n:-?}"
fact $v "the vector table survives into the artifact although nothing calls it"

# ------------------------------------------------------------ 3. 書き込み用の像
#
# ELF のままでは書き込み器が読めない。`artifacts` がグラフの内側で変える。

assert "a raw image is produced"   test -f "$B/firmware.bin"
assert "an Intel HEX is produced"  test -f "$B/firmware.hex"

_last_cmd="head -c 4 $B/firmware.bin"
OUT="$(head -c 4 "$B/firmware.bin" 2>/dev/null | od -An -c | tr -s ' ')"
RC=0
! head -c 4 "$B/firmware.bin" 2>/dev/null | grep -q 'ELF'
fact $? "the raw image is no longer an ELF"

_last_cmd="grep -a DOWEL-BLINK $B/firmware.bin"; OUT=""; RC=0
grep -qa 'DOWEL-BLINK' "$B/firmware.bin" 2>/dev/null
fact $? "and it carries what the firmware put in the artifact"

_last_cmd="head -1 $B/firmware.hex"
OUT="$(head -1 "$B/firmware.hex" 2>/dev/null | cut -c1-24)"; RC=0
head -1 "$B/firmware.hex" 2>/dev/null | grep -q '^:'
fact $? "the hex image is in the format the entry asked for"

# 変換はクロスの道具で行われる。ホストの objcopy が別アーキテクチャの ELF を
# 扱うと、黙って誤った像が出うる。
cmd=$("$DOWEL" graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
      jq -r '.actions[] | select(.kind == "transform") | .command[0]' | head -1)
[ "$cmd" = "aarch64-linux-gnu-objcopy" ]
v=$?; RC=0; _last_cmd="graph --kind=action | select(.kind==\"transform\")"
OUT="tool: ${cmd:-(none)}"
fact $v "the image is made by the objcopy declared for the triple"

# ------------------------------------------------------------ 4. リンカスクリプト (F-025)
#
# ベアメタルでは記憶の配置を自分で決める。`ld/app.ld` を木の中に置いてあるが、
# `link_flags` は List<Str> であり file() を受けない。フラグの中の相対パスは
# ビルドディレクトリ基準で解決されるため、どう書いても届かない。

cp dowel.build dowel.build.bak
python3 - <<'PY'
p = "dowel.build"
t = open(p, encoding="utf-8").read()
t = t.replace('    "-Wl,-e,_reset",        # 入口はベクタ表の先の _reset',
              '    "-Wl,-e,_reset",\n    "-T", "ld/app.ld",      # 記憶の配置')
open(p, "w", encoding="utf-8").write(t)
PY
run build --no-compdb --target=$TRIPLE
said=$OUT
[ "$RC" -eq 0 ]
verdict=$?
_last_cmd="dowel build  # link_flags に -T ld/app.ld を足した"
OUT="$said"; RC=0
known_issue F-025
fact $verdict "a linker script inside the package can be named from the manifest"

# 届かない理由が「見つからない」であること。書き方の誤りと区別する。
printf '%s' "$said" | grep -q 'cannot open linker script'
fact $? "the linker says it cannot open the script, so the path never resolved"

# 絶対パスなら通る。足りないのは道の書き方だけである。
python3 - "$PWD" <<'PY'
import sys
p = "dowel.build"
t = open(p, encoding="utf-8").read()
t = t.replace('"-T", "ld/app.ld",', '"-T", "%s/ld/app.ld",' % sys.argv[1])
open(p, "w", encoding="utf-8").write(t)
PY
ok "the same script does work when named by an absolute path" \
    build --no-compdb --target=$TRIPLE

# そして効く。FLASH の番地に載る。
load=$($RE -l "$B/firmware" 2>/dev/null | sed -n 's/.*LOAD *0x[0-9a-f]* *\(0x[0-9a-f]*\).*/\1/p' | head -1)
[ "$load" = "0x0000000008000000" ]
v=$?; RC=0; _last_cmd="readelf -l $B/firmware | grep LOAD"
OUT="first LOAD at: ${load:-?}"
fact $v "and the layout it describes is what the artifact gets"

# 配置を決めないことの実害。`objcopy -O binary` は最初と最後の節の間を
# すべて埋めるため、既定の配置では像が桁違いに膨らむ。
with=$(stat -c %s "$B/firmware.bin" 2>/dev/null)
mv dowel.build.bak dowel.build
"$DOWEL" build --no-compdb --target=$TRIPLE >/dev/null 2>&1
without=$(stat -c %s "$B/firmware.bin" 2>/dev/null)
[ -n "$with" ] && [ -n "$without" ] && [ "$with" -lt "$((without / 10))" ]
v=$?; RC=0; _last_cmd="stat -c %s firmware.bin  # スクリプトの有無で比べる"
OUT="with a script:    ${with:-?} bytes"$'\n'"without a script: ${without:-?} bytes"
fact $v "without a script the raw image is more than ten times larger"

# ------------------------------------------------------------ 5. 増分

runs_actions 0 "a second build changes nothing" --target=$TRIPLE --no-compdb

printf '\n/* touched */\n' >>src/gpio.c
build_direct --target=$TRIPLE --no-compdb
rebuilt "gpio.c"  "editing a peripheral source recompiles it"
rebuilt "OBJCOPY" "and the image is derived again"
not_rebuilt "delay.c" "while its neighbour is left alone"
