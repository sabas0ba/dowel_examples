# apps/blink — 組み込み（ベアメタル）
#
# Cortex-M4F のファームウェア。OS を持たない triple であり、libc も起動
# コードも無い。リセット時、CPU は flash の先頭から2語を読む。[0] が
# スタックポインタの初期値、[1] が最初に実行する番地である。
#
# 対象を増やす（RISC-V など）ときに変わるのは3つだけである。
#
#   1. `[toolchain.<triple>]` を1つ足す
#   2. `ld/<triple>.ld` を置く
#   3. cpu と ABI の指定を `match cfg.target` の腕にする
#
# **リンカスクリプトはこの木から指せない**（docs/10-findings.md F-025）。
# ベアメタルでは省略できないものなので、そこが組み込みの最初の関門になる。

TRIPLE=thumbv7em-none-eabihf
B=".dowel/build/$TRIPLE-debug/bin"
LD="ld/$TRIPLE.ld"

RE=arm-none-eabi-readelf
NM=arm-none-eabi-nm

# ------------------------------------------------------------ 道具立て

# elf_says <readelf の項目> — 成果物の見出しから1行読む。
elf_says() { $RE -h "$B/firmware" 2>/dev/null | sed -n "s/.*$1: *//p" | head -1; }

# first_load — 最初の LOAD セグメントが載る番地。
first_load() {
    $RE -l "$B/firmware" 2>/dev/null |
        sed -n 's/^ *LOAD *0x[0-9a-f]* *\(0x[0-9a-f]*\).*/\1/p' | head -1
}

# says <期待> <実際> <desc>
says() {
    [ "$1" = "$2" ]
    local v=$?
    RC=0; _last_cmd="readelf -h $B/firmware"
    OUT="want: $1"$'\n'"got:  ${2:-(nothing)}"
    fact $v "$3"
}

# with_script <道> — link_flags に -T を足す。空なら外す。
with_script() {
    python3 - "${1:-}" <<'PY'
import re, sys
p = "dowel.build"
t = open(p, encoding="utf-8").read()
t = re.sub(r'\n *"-T", "[^"]*",', "", t)
if sys.argv[1]:
    t = t.replace('    "-Wl,-e,_reset",',
                  '    "-Wl,-e,_reset",\n    "-T", "%s",' % sys.argv[1])
open(p, "w", encoding="utf-8").write(t)
PY
}

# ------------------------------------------------------------ 1. 組める

ok "the bare-metal package passes check" check --target=$TRIPLE
ok "and builds"                          build --no-compdb --target=$TRIPLE

# ------------------------------------------------------------ 2. ベアメタルであること
#
# 「組めた」だけでは足りない。libc が混ざっていないことを成果物から読む。

n=$($RE -d "$B/firmware" 2>/dev/null | grep -c NEEDED)
[ "${n:-1}" = 0 ]
v=$?; RC=0; _last_cmd="readelf -d $B/firmware | grep NEEDED"
OUT="NEEDED entries: ${n:-?}"
fact $v "the artifact needs no shared library at run time"

n=$($NM "$B/firmware" 2>/dev/null | grep -ciE ' (printf|malloc|free|__libc|_start)$')
[ "${n:-1}" = 0 ]
v=$?; RC=0; _last_cmd="nm $B/firmware | grep libc symbols"
OUT="$($NM "$B/firmware" 2>/dev/null | head -20)"
fact $v "and carries no symbol from the standard library or its start-up"

says ARM "$(elf_says Machine)" "the artifact is for the target architecture"

# triple の末尾の `hf` は hard-float を意味する。フラグと triple が食い違うと、
# 呼び出し規約の違う目的ファイルが黙って混ざる。
_last_cmd="readelf -h $B/firmware | Flags"
OUT="$(elf_says Flags)"; RC=0
printf '%s' "$OUT" | grep -q 'hard-float'
fact $? "and its float ABI agrees with the hf in the triple"

# 入口はベクタ表の [1] が指す先である。libc の起動処理ではない。
entry=$(elf_says 'Entry point address')
reset=$($NM "$B/firmware" 2>/dev/null | sed -n 's/^0*\([0-9a-f]*\) [Tt] _reset$/\1/p')
_last_cmd="readelf -h | Entry point  vs  nm | _reset"
OUT="entry: ${entry:-?}"$'\n'"_reset: 0x${reset:-?}  (thumb のため最下位ビットが立つ)"
RC=0
# thumb の分岐先は番地の最下位ビットを 1 にして表す。entry はその形で入る。
[ -n "$entry" ] && [ "$((entry))" = "$((0x$reset + 1))" ]
fact $? "the entry point is the reset handler, not a libc start-up routine"

# ベクタ表は誰も参照しない。属性で残すよう指示してある。消えると、
# 実機はスタックポインタも入口も読めない。
n=$($RE -S "$B/firmware" 2>/dev/null | grep -c '\.vectors')
[ "${n:-0}" -ge 1 ]
v=$?; RC=0; _last_cmd="readelf -S $B/firmware | grep .vectors"
OUT="$($RE -S "$B/firmware" 2>/dev/null | grep -A1 vectors)"
fact $v "the vector table survives into the artifact although nothing calls it"

# ------------------------------------------------------------ 3. 対象の宣言 (F-026)
#
# 道具は3つとも宣言してあるが、宣言してあるのは1つの triple に対してだけで
# ある。ホストには既定があるため、`--target` を付け忘れてもホスト向けの
# 計画が立つ。ベアメタルの木にホストの構成は存在しないので、そこから先は
# 運任せになる。
#
#   - フラグがホストのコンパイラに通らなければ、翻訳の誤りとして落ちる。
#     利用者が見るのは `unrecognized command-line option '-mthumb'` であり、
#     「この木はホスト向けではない」とはどこにも書かれていない
#   - フラグがたまたま通れば、**黙ってホストの成果物ができる**。像まで
#     ホストの objcopy が作る（この形は #71 に記録した）
#
# どちらも dowel は何も言わない。

run build --no-compdb
said=$OUT
[ "$RC" -ne 0 ]
fact $? "leaving out --target is refused, but by the host compiler"

_last_cmd="dowel build  # --target 無し"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q "unrecognized command-line option"
fact $? "the message is about a flag, not about the package's targets"

OUT=$(json_diags build --no-compdb)
RC=0
[ -z "$(printf '%s' "$OUT" | jq -r '.code' 2>/dev/null)" ]
fact $? "and dowel emits no diagnostic of its own about the target"

grep -q '^targets' dowel.toml
verdict=$?
RC=0; _last_cmd="grep '^targets' dowel.toml"; OUT="$(sed -n '1,12p' dowel.toml)"
known_issue F-026
fact $verdict "a package can say which targets it is for"

rm -rf .dowel/build/x86_64-unknown-linux-gnu-debug
"$DOWEL" build --no-compdb --target=$TRIPLE >/dev/null 2>&1

# ------------------------------------------------------------ 4. 書き込み用の像

assert "a raw image is produced"   test -f "$B/firmware.bin"
assert "an Intel HEX is produced"  test -f "$B/firmware.hex"

_last_cmd="head -c 4 $B/firmware.bin"
OUT="$(head -c 4 "$B/firmware.bin" 2>/dev/null | od -An -c | tr -s ' ')"; RC=0
! head -c 4 "$B/firmware.bin" 2>/dev/null | grep -q 'ELF'
fact $? "the raw image is no longer an ELF"

_last_cmd="head -1 $B/firmware.hex"
OUT="$(head -1 "$B/firmware.hex" 2>/dev/null | cut -c1-24)"; RC=0
head -1 "$B/firmware.hex" 2>/dev/null | grep -q '^:'
fact $? "the hex image is in the format the entry asked for"

cmd=$("$DOWEL" graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
      jq -r '.actions[] | select(.kind == "transform") | .command[0]' | head -1)
[ "$cmd" = "arm-none-eabi-objcopy" ]
v=$?; RC=0; _last_cmd="graph --kind=action | select(.kind==\"transform\")"
OUT="tool: ${cmd:-(none)}"
fact $v "the image is made by the objcopy declared for the triple"

# ------------------------------------------------------------ 5. リンカスクリプト (F-025)
#
# ベアメタルでは記憶の配置を自分で決める。`ld/<triple>.ld` を木の中に
# 置いてあるが、`link_flags` は List<Str> であり file() を受けない。フラグの
# 中の相対パスはビルドディレクトリ基準で解決されるため、どう書いても届かない。

# 配置を決めないと、既定のリンカスクリプトが選んだ番地に載る。
# この部品の flash は 0x08000000 から始まるので、そこは flash ではない。
addr=$(first_load)
[ "$addr" = "0x00008000" ]
v=$?; RC=0; _last_cmd="readelf -l $B/firmware | grep LOAD"
OUT="first LOAD at: ${addr:-?}  (this part's flash starts at 0x08000000)"
fact $v "without a script the image is placed where the part has no flash"

with_script "$LD"
run build --no-compdb --target=$TRIPLE
said=$OUT
[ "$RC" -eq 0 ]
verdict=$?
_last_cmd="dowel build  # link_flags に -T $LD を足した"
OUT="$said"; RC=0
known_issue F-025
fact $verdict "a linker script inside the package can be named from the manifest"

printf '%s' "$said" | grep -q 'cannot open linker script'
fact $? "the linker says it cannot open the script, so the path never resolved"

# 絶対パスなら通る。足りないのは道の書き方だけである。
with_script "$PWD/$LD"
ok "the same script does work when named by an absolute path" \
    build --no-compdb --target=$TRIPLE

addr=$(first_load)
[ "$addr" = "0x08000000" ]
v=$?; RC=0; _last_cmd="readelf -l $B/firmware | grep LOAD"
OUT="first LOAD at: ${addr:-?}"
fact $v "and then the image lands at the start of flash, where it can be programmed"

# ベクタ表が先頭に来ていること。[0] と [1] を実際に読む。
sp=$(od -An -tx4 -N4 "$B/firmware.bin" 2>/dev/null | tr -d ' ')
pc=$(od -An -tx4 -j4 -N4 "$B/firmware.bin" 2>/dev/null | tr -d ' ')
_last_cmd="od -tx4 -N8 $B/firmware.bin"
OUT="[0] initial SP: 0x$sp"$'\n'"[1] reset:       0x$pc"
RC=0
[ "$sp" = "20010000" ]
fact $? "the first word of the image is the initial stack pointer"

[ "$((0x$pc))" -ge "$((0x08000000))" ]
v=$?; RC=0; _last_cmd="od -tx4 -j4 -N4 $B/firmware.bin"
OUT="[1] reset: 0x$pc"
fact $v "and the second is a reset handler inside flash"

with_script ""
"$DOWEL" build --no-compdb --target=$TRIPLE >/dev/null 2>&1

# ------------------------------------------------------------ 6. 増分

runs_actions 0 "a second build changes nothing" --target=$TRIPLE --no-compdb

printf '\n/* touched */\n' >>src/gpio.c
build_direct --target=$TRIPLE --no-compdb
rebuilt "gpio.c"  "editing a peripheral source recompiles it"
rebuilt "OBJCOPY" "and the image is derived again"
not_rebuilt "delay.c" "while its neighbour is left alone"
