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
# 対象は MPS2-AN386（Cortex-M4）。qemu-system-arm がこの機械を持つため、
# **組んだものを実際に走らせられる**。結果は semihosting で返す。
#
# **リンカスクリプトはこの木から指せない**（docs/10-findings.md F-025）。
# ベアメタルでは省略できないものなので、そこが組み込みの最初の関門になる。
# しかもその実害は、置き場所ではなく**起動できないこと**に出る。

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

# on_hardware — qemu の上でテストを走らせ、出力を SAID に、状態を RC に置く。
#
# `--nocapture` を付ける。付けないと、通ったときの出力は握り潰される。
# ここで見たいのは合否ではなく**装置が何と言ったか**であり、それは
# semihosting で返ってくる文字列でしかない。
SAID=""
on_hardware() {
    SAID=$("$DOWEL" test --target=$TRIPLE --nocapture 2>&1)
    RC=$?
    _last_cmd="dowel test --target=$TRIPLE --nocapture   # qemu-system-arm 経由"
    return 0
}

# with_script <道> — link_flags の -T を張り替える。空なら外す。
# 既定の木は指してある。外すのは「指さないと何が起きるか」を見るためだけ。
with_script() {
    python3 - "${1:-}" <<'PY'
import re, sys
p = "dowel.build"
t = open(p, encoding="utf-8").read()
t = re.sub(r'\n *"-T", file\("[^"]*"\),', "", t)
if sys.argv[1]:
    # bin と test の両方に効かせる。書き方が違うため綴りを短く取る。
    t = t.replace('"-Wl,-e,_reset",',
                  '"-Wl,-e,_reset",\n    "-T", file("%s"),' % sys.argv[1])
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
# ベアメタルの木にホストの構成は存在しない。`targets` を宣言しておくと、
# `--target` を付け忘れたときに**パッケージの側が断る**。
#
# 宣言が無かった頃は、そこから先が運任せだった。フラグがホストのコンパイラに
# 通らなければ翻訳の誤りとして落ち（利用者が見るのは `unrecognized
# command-line option '-mthumb'` であり、この木がホスト向けでないとは
# どこにも書かれていない）、たまたま通れば黙ってホストの成果物ができた。
# F-026 / #71 として報告し、`targets` が入った。

grep -q '^targets' dowel.toml
v=$?
RC=0; _last_cmd="grep '^targets' dowel.toml"; OUT="$(sed -n '1,10p' dowel.toml)"
fact $v "a package can say which targets it is for"

run build --no-compdb
said=$OUT
[ "$RC" -ne 0 ]
fact $? "and leaving out --target is refused"

diag unsupported-target "by the package itself, with a diagnostic of its own" \
    build --no-compdb

_last_cmd="dowel build  # --target 無し"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'unsupported-target'
fact $? "the message is about the package's targets, not about a flag"

_last_cmd="dowel build  # --target 無し"; OUT="$said"; RC=0
! printf '%s' "$said" | grep -q "unrecognized command-line option"
fact $? "and the host compiler is never reached"

# 宣言を外すと、以前の形に戻る。断っているのが `targets` であることを、
# 外して確かめる。
cp dowel.toml dowel.toml.keep
sed -i '/^targets/d' dowel.toml
run build --no-compdb
said=$OUT
_last_cmd="dowel build  # targets を外した"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q "unrecognized command-line option"
fact $? "without the declaration the host compiler is what complains"
mv dowel.toml.keep dowel.toml

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
      jq -r '.steps[] | select(.kind == "transform") | .program' | head -1)
[ "$cmd" = "arm-none-eabi-objcopy" ]
v=$?; RC=0; _last_cmd="graph --kind=action | select(.kind==\"transform\")"
OUT="tool: ${cmd:-(none)}"
fact $v "the image is made by the objcopy declared for the triple"

# ------------------------------------------------------------ 5. リンカスクリプト (F-025)
#
# ベアメタルでは記憶の配置を自分で決める。`link_flags` は `List<Str | Path>`
# であり、`file()` の要素は絶対パスへ展開される。したがって木の中の
# `ld/<triple>.ld` をそのまま指せる。
#
# 指せなかった頃は、この1点で組み込みの構成がマニフェストに書けなかった。
# F-025 / #70 として報告し、`Path` を受けるようになった。実害が置き場所では
# なく**起動しないこと**に出るのは、下で外して確かめている。

grep -q 'file("ld/' dowel.build
v=$?
RC=0; _last_cmd="grep 'file(\"ld/' dowel.build"
OUT="$(grep -n 'file("ld/' dowel.build)"
fact $v "a linker script inside the package can be named from the manifest"

addr=$(first_load)
[ "$addr" = "0x00000000" ]
v=$?; RC=0; _last_cmd="readelf -l $B/firmware | grep LOAD"
OUT="first LOAD at: ${addr:-?}"
fact $v "and the image lands at the start of flash, where it can be programmed"

# そして走る。ベアメタルで「動く」を確かめる唯一の形である。
on_hardware
[ "$RC" -eq 0 ]
v=$?; OUT="$SAID"; RC=0
fact $v "and the firmware runs on emulated hardware and its test passes"

printf '%s' "$SAID" | grep -q 'blink: ok'
fact $? "the firmware reports through semihosting, so the result comes from the device"

# 配置を決めないと何が起きるかを、外して確かめる。既定のリンカスクリプトが
# 選ぶ番地には何も割り当てられていない。
with_script ""
"$DOWEL" build --no-compdb --target=$TRIPLE >/dev/null 2>&1
addr=$(first_load)
[ "$addr" = "0x00008000" ]
v=$?; RC=0; _last_cmd="readelf -l $B/firmware | grep LOAD   # -T を外した"
OUT="first LOAD at: ${addr:-?}  (the vector table must sit at 0x00000000)"
fact $v "without the script the image is placed where the vector table cannot be"

on_hardware
_last_cmd="dowel test --target=$TRIPLE   # -T を外した"
OUT="$SAID"; RC=0
printf '%s' "$SAID" | grep -q 'Lockup'
fact $? "and then the processor locks up at reset, having read no vector table"

with_script "$LD"
"$DOWEL" build --no-compdb --target=$TRIPLE >/dev/null 2>&1

# ベクタ表が先頭に来ていること。[0] と [1] を実際に読む。
sp=$(od -An -tx4 -N4 "$B/firmware.bin" 2>/dev/null | tr -d ' ')
pc=$(od -An -tx4 -j4 -N4 "$B/firmware.bin" 2>/dev/null | tr -d ' ')
_last_cmd="od -tx4 -N8 $B/firmware.bin"
OUT="[0] initial SP: 0x$sp"$'\n'"[1] reset:       0x$pc"
RC=0
[ "$sp" = "20400000" ]
fact $? "the first word of the image is the initial stack pointer"

[ "$((0x$pc))" -gt 0 ] && [ "$((0x$pc))" -lt "$((0x00400000))" ]
v=$?; RC=0; _last_cmd="od -tx4 -j4 -N4 $B/firmware.bin"
OUT="[1] reset: 0x$pc"
fact $v "and the second is a reset handler inside flash"

# 以降はスクリプトを当てたまま進める。外すと立ち上がらないため、
# 走らせる検査そのものが成り立たない。

# ------------------------------------------------------------ 6. 実行の宣言 (F-027)
#
# `[runner.<triple>]` は dowel.build の表である。`[toolchain.<triple>]` は
# dowel.toml の表であり、組み込みの構成ではこの2つを続けて書く。同じ triple を
# 鍵に持ち名前も対になっているため、片方の隣にもう片方を書くのは自然な
# 間違いである。

# 成果物の道は実装が末尾に付ける（ADR-0008）。だから `-kernel` を args の
# 最後に置くだけで `qemu-system-arm ... -kernel <artifact>` になる。
_last_cmd="grep -A3 'runner\.' dowel.build"
OUT=$(grep -A3 'runner\.' dowel.build)
RC=0
printf '%s' "$OUT" | grep -q '"-kernel"\]'
fact $? "the runner ends its args with -kernel, and dowel appends the artifact"

# dowel.toml へ移すと拒まれる。以前は黙って無視され、宣言してあるのに
# `missing-runner`（宣言が無い）と言われた。F-027 / #74 として報告し、
# `dowel.toml` の未知の最上位テーブルが拒まれるようになった。
cp dowel.build dowel.build.keep
cp dowel.toml  dowel.toml.keep
python3 -c '
p = "dowel.build"
t = open(p, encoding="utf-8").read()
# 表そのものを探す。同じ綴りが上の注釈にも出るため、行頭で取る。
i = t.index("\n[runner.thumbv7em")
open(p, "w", encoding="utf-8").write(t[:i] + "\n")
open("dowel.toml", "a", encoding="utf-8").write("\n" + t[i:])
'
diag unknown-table "a runner written into dowel.toml is not silently ignored" \
    check --target=$TRIPLE

run test --target=$TRIPLE
said=$OUT
_last_cmd="dowel test  # runner を dowel.toml へ移した"; OUT="$said"; RC=0
! printf '%s' "$said" | grep -q 'missing-runner'
fact $? "and the failure is about the misplaced table, not about a missing declaration"

mv dowel.build.keep dowel.build
mv dowel.toml.keep  dowel.toml
ok "putting the runner back where it belongs makes the tests run again" \
    test --target=$TRIPLE

# ------------------------------------------------------------ 7. 増分

# 直前に `test` を挟んでいるため、まず組み直してから測る。挟まないと
# F-024 の分が乗って、ここが見たい性質と混ざる。
"$DOWEL" build --no-compdb --target=$TRIPLE >/dev/null 2>&1
runs_actions 0 "a second build changes nothing" --target=$TRIPLE --no-compdb

printf '\n/* touched */\n' >>src/gpio.c
build_direct --target=$TRIPLE --no-compdb
rebuilt "gpio.c"  "editing a peripheral source recompiles it"
rebuilt "OBJCOPY" "and the image is derived again"
not_rebuilt "delay.c" "while its neighbour is left alone"
