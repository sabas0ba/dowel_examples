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

# ------------------------------------------------------------ 下ごしらえ

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

# `check` は雛形を「組むもの」として数えない（[F-058](../../docs/10-findings.md#f-058)）。
# 何も名指ししていないのだから、名指ししたときの `not-a-target` は出ない。
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

# 配置を決めないと何が起きるかを、外して確かめる。
#
# 起動コードは `.bss` の両端と `.data` の載せ先をリンカスクリプトから
# 受け取る。スクリプトが無ければその名前は誰も定義しないので、
# **像が置かれる前に、そもそも繋がらない。**
with_script ""
run build --no-compdb --target=$TRIPLE
said=$OUT; rc=$RC
[ "$rc" -ne 0 ]
_verdict $? "without a memory map the firmware does not link at all"
_last_cmd="dowel build --target=$TRIPLE   # -T を外した"
OUT=$(printf '%s' "$said" | grep -m4 'undefined\|error'); RC=0
printf '%s' "$said" | grep -q '__bss_start__\|__data_load__'
fact $? "the link names the section bounds the script was to define"

# 起動コードを自分で持つ側——`test.onhw` は C だけで書かれており、節の
# 両端を要らない——は繋がる。そちらで「置き場所を決めないと何が起きるか」
# が見える。既定のリンカスクリプトが選ぶ番地には何も割り当てられていない。
on_hardware
_last_cmd="dowel test --target=$TRIPLE   # -T を外した"
OUT="$SAID"; RC=0
printf '%s' "$SAID" | grep -q 'Lockup'
fact $? "and a target that does link locks up at reset, having read no vector table"

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

# ------------------------------------------------------------ 6.5 デバッグ
#
# qemu-system は `-gdb tcp::<port>` でスタブを開き、`-S` で最初の命令の前に
# 止まる。runner に保持する側（debug_args）と繋ぐ側（debug_connect）を
# 宣言してあるので、`dowel debug firmware --target=...` で**電源投入直後の
# 実機**に繋がる。
#
# スタブの引数は `args` の**前**に挿し込まれる（F-046 の修正）。この runner は
# 成果物を取るフラグ（-kernel）を args の末尾に置く——ADR-0008 が勧める形——
# ので、後ろに挿し込むと `-kernel -gdb tcp::13579 -S <elf>` になり、qemu は
# `-gdb` という名前のファイルをカーネルとして読もうとしていた。

launch=$("$DOWEL" debug firmware --target=$TRIPLE --dap 2>/dev/null)
_last_cmd="dowel debug firmware --target=... --dap | .debugServerArgs"
OUT=$(printf '%s' "$launch" | jq -c '.debugServerArgs')
RC=0
printf '%s' "$launch" | jq -e '.miDebuggerServerAddress == "localhost:13579"' >/dev/null 2>&1
fact $? "the firmware's debug launch attaches at the declared stub address"

got=$(printf '%s' "$launch" | jq -r '.miDebuggerPath')
[ "$got" = "gdb-multiarch" ]
v=$?; RC=0; _last_cmd="dap | .miDebuggerPath"
OUT="debugger: ${got:-(none)}"
fact $v "with the debugger the bare-metal triple declares"

# -kernel の直後に成果物が来ること。来なければ、qemu はスタブの旗を
# カーネルとして読む。宣言は正しいのに、組まれたコマンドが壊れている。
after_kernel=$(printf '%s' "$launch" |
    jq -r '.debugServerArgs | .[(index("-kernel") + 1)] // "(nothing)"')
case $after_kernel in */bin/firmware) verdict=0 ;; *) verdict=1 ;; esac
RC=0; _last_cmd="dap | debugServerArgs の -kernel の直後"
OUT="after -kernel: $after_kernel"$'\n'"$(printf '%s' "$launch" | jq -c '.debugServerArgs')"
fact $verdict "the stub arguments do not break a runner that ends with the flag taking the artifact"

# 挿し込みが前であること自体を見る。上の検査は「-kernel の直後が成果物」で
# あり、宣言の順序が別の形で壊れても通りうる。ここでは順序そのものを固定する。
order=$(printf '%s' "$launch" |
    jq -r '.debugServerArgs | "\(index("-gdb")) \(index("-M")) \(index("-kernel"))"')
set -- $order
_last_cmd="dap | debugServerArgs の -gdb / -M / -kernel の位置"
OUT="-gdb: $1  -M: $2  -kernel: $3"$'\n'"$(printf '%s' "$launch" | jq -c '.debugServerArgs')"
RC=0
[ "$1" != "null" ] && [ "$2" != "null" ] && [ "$1" -lt "$2" ] && [ "$2" -lt "$3" ]
fact $? "because they are inserted before the runner's own arguments, not after them"

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

# ------------------------------------------------------------ 8. 設定を束ねる（ADR-0035）
#
# 機械の旗はこの木の3つの目標すべてに要る。以前は3か所へ書き写していた——
# 同じ値でなければ呼び出し規約の違うものが混ざるのに、揃っていることを
# 確かめる手立ては無かった。`template` がそれを1か所にする。

_last_cmd="grep template dowel.build"; RC=0
OUT=$(grep -n 'template\|^use' dowel.build | head -6)
[ -n "$OUT" ]
fact $? "the machine flags are declared once, in a template"

# 3つの目標すべてに、同じ旗が届いていること。束ねたことが**効いている**
# ことは、束ねた宣言ではなく出てきた引数で見る。
mflags() {
    "$DOWEL" graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
        jq -r --arg t "$1" '.steps[] | select(.kind == "cc" and .target == $t)
               | [.arguments[] | select(startswith("-mcpu") or startswith("-mfpu")
                 or . == "-mthumb" or . == "-ffreestanding")] | join(" ")' | sort -u
}
a=$(mflags "blink:bl"); b=$(mflags "blink:firmware"); c=$(mflags "blink:onhw")
_last_cmd="graph | 3つの目標の機械の旗"
OUT="lib.bl:        ${a:-(none)}"$'\n'"bin.firmware:  ${b:-(none)}"$'\n'"test.onhw:     ${c:-(none)}"
RC=0
[ -n "$a" ] && [ "$a" = "$b" ] && [ "$b" = "$c" ]
fact $? "and every target that uses it is compiled with exactly those flags"

# リンクする2つだけが、リンクの側の雛形も使う。archive を作るだけの lib には
# 要らない——束ねるとは「同じものを配る」ことであって「全部に配る」ことでは
# ない。
lf=$("$DOWEL" graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
     jq -r '[.steps[] | select(.kind == "link") | .arguments[] | select(. == "-nostdlib")] | length')
_last_cmd="graph | link の -nostdlib の数"; OUT="links carrying -nostdlib: $lf"; RC=0
[ "$lf" = 2 ]
fact $? "while the link-side template reaches only the two targets that link"

# 雛形は目標ではない。成果物を出さず、グラフにも現れない。
n=$("$DOWEL" graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
    jq -r '[.steps[] | select(.target | test("cortex"))] | length')
_last_cmd="graph | 雛形の名前を持つ手順"; OUT="steps: $n"; RC=0
[ "$n" = 0 ]
fact $? "and the template itself produces nothing, being settings and not a target"

# 目標の宣言は雛形に勝つ。展開は目標自身の値の**前**に置かれるので、
# `append` は順序を保ち、`replace` は目標が勝つ。
cp dowel.build dowel.build.keep
sed -i 's|^\[test.onhw.private\]|[test.onhw.private]\nflags = ["-DFROM_TARGET"]|' dowel.build
got=$("$DOWEL" graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc" and .target == "blink:onhw") | .arguments | join(" ")' | head -1)
_last_cmd="graph | onhw の引数（目標側にも flags を足した）"
OUT=$(printf '%s' "$got" | tr ' ' '\n' | grep -E '^-(m|f|D)' | paste -sd' ' -)
RC=0
printf '%s' "$got" | grep -q -- '-mcpu=cortex-m4' && printf '%s' "$got" | grep -q -- '-DFROM_TARGET'
fact $? "a target's own values are merged with the template's, not replaced by them"

pos_t=$(printf '%s' "$got" | tr ' ' '\n' | grep -n -- '-mthumb' | head -1 | cut -d: -f1)
pos_o=$(printf '%s' "$got" | tr ' ' '\n' | grep -n -- '-DFROM_TARGET' | head -1 | cut -d: -f1)
_last_cmd="graph | 雛形の旗と目標の旗の位置"
OUT="template flag at $pos_t, target flag at $pos_o"; RC=0
[ -n "$pos_t" ] && [ -n "$pos_o" ] && [ "$pos_t" -lt "$pos_o" ]
fact $? "with the template's placed first, which is what lets the target win a replace"
mv dowel.build.keep dowel.build

# 雛形は目標ではないので、目標の骨格は書けない。
cp dowel.build dowel.build.keep
sed -i 's|^\[template.cortex_m4f\]$|[template.cortex_m4f]\nsources = [file("src/gpio.c")]|' dowel.build
fails "a template may not declare sources, the root block saying what a target is" \
    build --target=$TRIPLE
mv dowel.build.keep dowel.build

# `check` はいま雛形があるだけで落ちるので、上は `build` で見ている。
# 対照として、`build` と `test` は雛形があっても通ることを固定しておく——
# 壊れているのが機構ではなく `check` の数え方であることが読める。
ok "while build itself is untroubled by the templates beside it" \
    build --target=$TRIPLE --no-compdb
ok "and so is test"  test --target=$TRIPLE --no-compdb

# ------------------------------------------------------------ 9. 起動コード（ADR-0048）
#
# ここはアセンブリでしか書けない層である。SP を載せる前に C の関数へは
# 入れず（引数も戻り番地も置く先が無い）、`.bss` を 0 で埋める前に C の
# 大域変数は読めない。libc も起動コードも無い triple では、この段を誰かが
# 書く必要がある。
#
# 以前はベクタ表を C の配列として書き、`_reset` も C の関数だった。組めて
# はいたが、`.bss` は誰も 0 にしておらず、SP はベクタ表の [0] を CPU が
# 読むことだけに頼っていた。アセンブリを第3の言語として扱えるようになった
# ので、本来の形へ移してある。

asm_line=$("$DOWEL" graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
           jq -r '.steps[] | select(.kind == "cc") | "\(.description) \(.arguments | join(" "))"' |
           grep 'vectors\.S')

_last_cmd="graph --kind=action | the vectors.S action"; OUT=$asm_line; RC=0
printf '%s' "$asm_line" | grep -q '^AS '
fact $? "the start-up code is built as assembly, not as C that happens to assemble"

# C の方言はアセンブラへ渡らない。**これはこの木の書き方を変えさせた。**
# 以前は `-std=gnu11` を `flags`（言語に依らない一覧）に混ぜていた——
# ソースが C だけのうちは同じことだったからである。起動コードを `.S` へ
# 移した時点で、それは C でないファイルに C の方言を告げる指定になった。
# 言語ごとの置き場が在るのは、このためである。
_last_cmd="graph --kind=action | the vectors.S action"; OUT=$asm_line; RC=0
! printf '%s' "$asm_line" | grep -q '\-std=gnu11'
fact $? "and the C dialect the template declares does not reach it"

c_line=$("$DOWEL" graph --kind=action --format=json --target=$TRIPLE 2>/dev/null |
         jq -r '.steps[] | select(.kind == "cc") | (.arguments | join(" "))' | grep 'main\.c')
_last_cmd="graph --kind=action | the main.c action"; OUT=$c_line; RC=0
printf '%s' "$c_line" | grep -q '\-std=gnu11'
fact $? "while C still gets it, which is what makes the separation a placement and not a loss"

# 機械の旗は渡る。cpu も浮動小数点 ABI も、アセンブラにとっても要る。
_last_cmd="graph --kind=action | the vectors.S action"; OUT=$asm_line; RC=0
printf '%s' "$asm_line" | grep -q '\-mcpu=cortex-m4' &&
    printf '%s' "$asm_line" | grep -q '\-mfloat-abi=hard'
fact $? "while the machine flags do, being what the assembler needs too"

# 前処理を通る綴りを選んである。スタックの頂きを C と共有する見出しから
# 取り込むためであり、`.s` では `#include` が届かない。
_last_cmd="graph --kind=action | the vectors.S action"; OUT=$asm_line; RC=0
printf '%s' "$asm_line" | grep -q '\-MD'
fact $? "a preprocessed start-up file records what it includes"

# 宣言が在るだけでは依存が辿られたことにならない。共有している見出しを
# 書き換えて、組み直されることを見る。
"$DOWEL" build --no-compdb --target=$TRIPLE >/dev/null 2>&1
sed -i 's/0x20400000/0x20300000/' include/bl/mem.h
build_direct --no-compdb --target=$TRIPLE
rebuilt "vectors.S" "editing the header it shares with C rebuilds the start-up code"

# そして値が本当に届いている。像の先頭の語が初期スタックポインタである。
sp=$(od -An -tx4 -N4 "$B/firmware.bin" 2>/dev/null | tr -d ' ')
_last_cmd="od -tx4 -N4 $B/firmware.bin"; OUT="[0] initial SP: 0x$sp"; RC=0
[ "$sp" = "20300000" ]
fact $? "and the value it took from that header is the first word of the image"

sed -i 's/0x20300000/0x20400000/' include/bl/mem.h
"$DOWEL" build --no-compdb --target=$TRIPLE >/dev/null 2>&1

# ベクタ表はアセンブリの側に移った。C の配列だった頃と同じく、誰も
# 参照しないので `KEEP()` が残している。
_last_cmd="$NM $B/firmware | vectors"
OUT=$($NM "$B/firmware" 2>/dev/null | grep -i ' vectors$'); RC=0
printf '%s' "$OUT" | grep -q 'vectors'
fact $? "the vector table is a symbol the assembly file defines"

# thumb の記号は下位ビットが 1 でなければならない。`.thumb_func` を書き
# 忘れると、表の [1] は偶数のままになり、CPU は ARM 状態へ移ろうとして
# 起動直後に落ちる。**組み上がり、書き込め、起動だけしない**形である。
pc=$(od -An -tx4 -j4 -N4 "$B/firmware.bin" 2>/dev/null | tr -d ' ')
_last_cmd="od -tx4 -j4 -N4 $B/firmware.bin"; OUT="[1] reset: 0x$pc"; RC=0
case $pc in
    *[13579bdf]) fact 0 "and the reset entry it points at is marked as a thumb function" ;;
    *)           fact 1 "and the reset entry it points at is marked as a thumb function" ;;
esac

# 起動コードが本当に働いていること。`.bss` を 0 で埋める段は、埋めない
# 限り観測できない——初期化していない大域変数を装置の上で読ませる。
on_hardware
[ "$RC" -eq 0 ]
v=$?; OUT="$SAID"; RC=0
fact $v "the firmware still runs on emulated hardware with the assembly start-up"
