# apps/dsp — 1つのライブラリを複数の三つ組で
#
# ここまでのアプリは、1つのアプリが1つの対象を持っていた。実務でよくある
# のはその逆で、**算法は1つ、走る機械が何種類もある**。手元で書いて試し、
# 同じものを ARM の基板と RISC-V の基板で動かし、さらに OS の無いマイコン
# にも載せる。そのとき問われるのは「組めるか」ではなく、
# **どの機械でも同じ答が出るか**である。
#
#   core/   算法。整数だけで書いてあり、4つの三つ組へ組まれる
#   cli/    使う側。ホストの載っている3つ
#   gui/    使う側。cairo を引く。手元のみ
#   fw/     使う側。Cortex-M4F。OS も libc も無い
#
#   x86_64-unknown-linux-gnu       手元
#   aarch64-unknown-linux-gnu      ARM       qemu-user
#   riscv64gc-unknown-linux-gnu    RISC-V    qemu-user
#   thumbv7em-none-eabihf          Cortex-M  qemu-system-arm（semihosting）
#
# この層でしか問われないもの。
#
#   - **同じ答**。期待値は tests/golden.h の1枚で、4つすべてがそれを読む
#   - **機械は本当に違う**。語長も命令集合も違うのに答だけが同じ、を見る
#   - **道具立てが三つ組ごとに効く**。手元の cc が別の対象の物を作らない
#   - **ライブラリが自分の道具立てを持てない**。設計としてそうであり、
#     診断がその理由を言う（F-054 の修正）
#   - **目標を三つ組で絞る**。ライブラリが自分の検査を持てる（F-055 の修正）

ARM_T=aarch64-unknown-linux-gnu
RV_T=riscv64gc-unknown-linux-gnu
FW_T=thumbv7em-none-eabihf

# bin_for <パッケージ> <名前> <三つ組> — 組んだ実行ファイルの道。
bin_for() {
    find "$1/.dowel/build/$3-debug/bin/$2" -type f 2>/dev/null | head -1
}

# say <三つ組> <実行ファイル> <引数...> — その三つ組の走らせ方で走らせる。
say() {
    local t=$1 b=$2; shift 2
    case $t in
        "$ARM_T") timeout 300 qemu-aarch64-static -L /usr/aarch64-linux-gnu "$b" "$@" 2>&1 ;;
        "$RV_T")  timeout 300 qemu-riscv64-static -L /usr/riscv64-linux-gnu "$b" "$@" 2>&1 ;;
        *)        timeout 300 "$b" "$@" 2>&1 ;;
    esac
}

HOST_T=x86_64-unknown-linux-gnu

# ------------------------------------------------------------ 1. 4つへ組める

ok "the algorithm passes check" -C core check

ok "it builds for the host"   -C core build --no-compdb
ok "and for ARM"              -C core build --no-compdb --target=$ARM_T
ok "and for RISC-V"           -C core build --no-compdb --target=$RV_T

# ベアメタルは使う側（fw）から組む。名指しは要らない——依存の検査は
# 集められず、ライブラリ側の検査は自分の `targets` でこの三つ組から外れて
# いる（F-055 の修正。6節で両方を見る）。
ok "and for a machine with no operating system" \
    -C fw build --no-compdb --target=$FW_T

# ------------------------------------------------------------ 2. 同じ答
#
# ここが本題である。期待値は tests/golden.h の1枚であり、4つの三つ組が
# すべてそれを読む。三つ組ごとに期待値を分けた瞬間、この検査は
# 「機械が違えば答も違う」を追認するだけのものになる。

ok "the vectors pass on the host" -C core test --no-compdb
ok "and on ARM"                   -C core test --no-compdb --target=$ARM_T
ok "and on RISC-V"                -C core test --no-compdb --target=$RV_T

# ベアメタルの側は libc が無いので実体が別になる。読む期待値は同じ1枚で
# あり、結果は semihosting で返る。
run test --no-compdb --target=$FW_T -C fw
_last_cmd="dowel test --target=$FW_T"
OUT=$(printf '%s' "$OUT" | grep -m4 'test result\|onhw:\|dsp-fw:')
[ "$RC" -eq 0 ]
fact $? "and on bare metal, against the same golden header, reported over semihosting"

# 数そのものを並べる。検査が通ったことより、**同じ行が出ること**が読める。
"$DOWEL" -C cli build --no-compdb            >/dev/null 2>&1
"$DOWEL" -C cli build --no-compdb --target=$ARM_T >/dev/null 2>&1
"$DOWEL" -C cli build --no-compdb --target=$RV_T  >/dev/null 2>&1

h=$(say "$HOST_T" "$(bin_for cli dsp $HOST_T)")
a=$(say "$ARM_T"  "$(bin_for cli dsp $ARM_T)")
r=$(say "$RV_T"   "$(bin_for cli dsp $RV_T)")
_last_cmd="dsp (host)   vs   dsp (ARM)   vs   dsp (RISC-V)"
OUT="host:   $h"$'\n'"ARM:    $a"$'\n'"RISC-V: $r"
RC=0
[ -n "$h" ] && [ "$h" = "$a" ] && [ "$a" = "$r" ]
fact $? "the same executable source prints byte-identical numbers on all three"

# ------------------------------------------------------------ 3. 機械は本当に違う
#
# 上が通る理由が「実は全部ホストで組んでいた」でないことを示す。
# 答が同じであることと、機械が同じであることは別である。

w_h=$(say "$HOST_T" "$(bin_for cli dsp $HOST_T)" width)
w_r=$(say "$RV_T"   "$(bin_for cli dsp $RV_T)" width)
_last_cmd="dsp width (host)   vs   dsp width (RISC-V)"
OUT="host:   $w_h"$'\n'"RISC-V: $w_r"; RC=0
[ -n "$w_h" ] && [ "$w_h" = "$w_r" ]
fact $? "the word size is the same on both, so it is not what makes the answers agree"

for pair in "$ARM_T:ARM aarch64" "$RV_T:RISC-V RISC-V" "$HOST_T:the host x86-64"; do
    t=${pair%%:*}; rest=${pair#*:}; label=${rest% *}; want=${rest##* }
    kind=$(file -b "$(bin_for cli dsp "$t")" 2>/dev/null)
    _last_cmd="file dsp ($label)"; OUT="$kind"; RC=0
    printf '%s' "$kind" | grep -qi -- "$want"
    fact $? "but what was built for $label really is a $want image"
done

# ベアメタルの側は ELF ですらない形（生の像）も出している。
_last_cmd="ls fw build dir"; RC=0
OUT=$(ls "fw/.dowel/build/$FW_T-debug/bin" 2>&1)
[ -f "fw/.dowel/build/$FW_T-debug/bin/onhw.bin" ]
fact $? "and the bare-metal target also yields the raw image a programmer would take"

kind=$(file -b "fw/.dowel/build/$FW_T-debug/bin/onhw" 2>/dev/null)
_last_cmd="file onhw"; OUT="$kind"; RC=0
printf '%s' "$kind" | grep -qi 'ARM'
fact $? "whose ELF form is an ARM image, from the same algorithm source"

# ------------------------------------------------------------ 4. 道具立てが三つ組ごとに効く
#
# 手元の cc が別の対象の物を作ってはならない。計画の段で見る。

for pair in "$ARM_T:aarch64-linux-gnu-gcc" "$RV_T:riscv64-linux-gnu-gcc"; do
    t=${pair%%:*}; want=${pair#*:}
    got=$("$DOWEL" -C core graph --kind=action --format=json --target="$t" 2>/dev/null |
          jq -r '.steps[] | select(.kind == "cc") | .program' | sort -u | paste -sd' ' -)
    _last_cmd="graph --target=$t | .program"; OUT="$got"; RC=0
    [ "$got" = "$want" ]
    fact $? "the compiler for $t is the one its toolchain table named"
done

# ベアメタルの側だけが freestanding の旗を受け取る。同じソース、違う腕。
got=$("$DOWEL" -C fw graph --kind=action --format=json --target=$FW_T 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc" and (.arguments | join(" ") | test("biquad")))
             | .arguments | join(" ")')
_last_cmd="graph --target=$FW_T | biquad.c の引数"; OUT="$got"; RC=0
printf '%s' "$got" | grep -q -- '-ffreestanding' && printf '%s' "$got" | grep -q -- '-mcpu=cortex-m4'
fact $? "the library's own source is compiled freestanding only for the machine that has no libc"

got=$("$DOWEL" -C core graph --kind=action --format=json --target=$ARM_T 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc" and (.arguments | join(" ") | test("biquad")))
             | .arguments | join(" ")')
_last_cmd="graph --target=$ARM_T | biquad.c の引数"; OUT="$got"; RC=0
! printf '%s' "$got" | grep -q -- '-ffreestanding'
fact $? "and is not, for the ones that have it"

# 機械の旗は2か所（core の腕と fw の目標）に書いてある。文法に束ねる手立てが
# 無いので、**実際に同じ旗が出ていること**をグラフから確かめる。食い違えば
# 呼び出し規約の違う書庫ができ、現れるのはリンカの苦情である。
lib_f=$("$DOWEL" -C fw graph --kind=action --format=json --target=$FW_T 2>/dev/null |
        jq -r '.steps[] | select(.kind == "cc" and (.arguments | join(" ") | test("biquad")))
               | [.arguments[] | select(test("^-m"))] | join(" ")')
use_f=$("$DOWEL" -C fw graph --kind=action --format=json --target=$FW_T 2>/dev/null |
        jq -r '.steps[] | select(.kind == "cc" and (.arguments | join(" ") | test("src/onhw[.]c")))
               | [.arguments[] | select(test("^-m"))] | join(" ")')
_last_cmd="graph | -m* of the library   vs   -m* of its consumer"
OUT="library: ${lib_f:-(none)}"$'\n'"consumer: ${use_f:-(none)}"; RC=0
[ -n "$lib_f" ] && [ "$lib_f" = "$use_f" ]
fact $? "the machine flags the library and its consumer are built with agree, though nothing binds them"

# ------------------------------------------------------------ 5. ライブラリが道具立てを持てない
#
# 三つ組ごとのコンパイラはライブラリの知識である。しかし置き場所は
# 使う側にしか無い。dowel は依存の宣言を読んでいて、それでも「無い」と言う。

probe=$(mktemp -d)
mkdir -p "$probe/lib/src" "$probe/app/src"
cat >"$probe/lib/dowel.toml" <<TOML
[package]
name = "mylib"
version = "0.1.0"
edition = "2026"

[toolchain.$ARM_T]
c  = "aarch64-linux-gnu-gcc"
ar = "aarch64-linux-gnu-ar"
TOML
printf '[lib.mylib]\nsources = [file("src/lib.c")]\n' >"$probe/lib/dowel.build"
echo 'int answer(void){ return 42; }' >"$probe/lib/src/lib.c"
cat >"$probe/app/dowel.toml" <<'TOML'
[package]
name = "app"
version = "0.1.0"
edition = "2026"

[[dependencies]]
name = "mylib"
path = "../lib"
TOML
printf '[bin.app]\nsources = [file("src/main.c")]\n\n[bin.app.private]\ndeps = [dep("mylib")]\n' \
    >"$probe/app/dowel.build"
echo 'int answer(void); int main(void){ return answer()==42?0:1; }' >"$probe/app/src/main.c"

run build --no-compdb --target=$ARM_T -C "$probe/app"
said=$OUT
_last_cmd="dowel build --target=$ARM_T  (toolchain declared only in the dependency)"
OUT=$(printf '%s' "$said" | grep -m4 'error\|warning\|note')
RC=0
printf '%s' "$said" | grep -q 'missing-toolchain'
fact $? "a dependency's toolchain declaration does not reach the build that uses it"

# dowel はその宣言を読んでいる。同じ出力の中で読み上げている。
_last_cmd="the same output"; OUT=$(printf '%s' "$said" | grep -m2 'toolchain-mismatch'); RC=0
printf '%s' "$said" | grep -q 'toolchain-mismatch'
fact $? "though it read the declaration, and says so in the same output"

# 見つけたものを言う（F-054 の修正）。診断が依存の宣言を読み上げ、値まで出し、
# **なぜ効かないか**を言う。効かないこと自体は設計である——道具立ては build
# 全体の性質であって依存の性質ではない（ADR-0031）。それを言わない診断は、
# 利用者に「宣言したのに無視された」としか読めない。
#
# 診断そのもの（error の行と、それに続く `= note:` だけ）を取り出す。
# 直後の `warning[toolchain-mismatch]` には依存の名前があるので、そこまで
# 含めると「言及している」と誤って読める。見たいのは**利用者が最初に読む
# 行が答を指しているか**である。
block=$(printf '%s\n' "$said" | awk '
    /^error\[missing-toolchain\]/ { inb = 1; print; next }
    inb && /^[[:space:]]*= /        { print; next }
    inb                             { exit }
')
_last_cmd="the missing-toolchain diagnostic alone, without the warnings that follow"
OUT="$block"
RC=0
printf '%s' "$block" | grep -q 'mylib'
fact $? "the error for a missing toolchain mentions the declaration a dependency already carries"

_last_cmd="the same diagnostic"; OUT="$block"; RC=0
printf '%s' "$block" | grep -q 'aarch64-linux-gnu-gcc'
fact $? "quoting the value, so the line to write is in front of the reader"

_last_cmd="the same diagnostic"; OUT="$block"; RC=0
printf '%s' "$block" | grep -qi 'property of the build'
fact $? "and why it does not apply, which is what makes the refusal read as a design"

rm -rf "$probe"

# ------------------------------------------------------------ 6. 目標を三つ組で絞る
#
# ライブラリの検査はホスト向けである（libc を使う）。ベアメタルの三つ組では
# 組めない。それを**目標ごとの `targets`** で言う（F-055 の修正）。
#
# 書けなかった頃は、使う側を名指しせずに組むとライブラリの検査が混ざって
# 落ちた。使う側のマニフェストに誤りは無いのに、である。`[package] targets`
# はパッケージ全体に掛かるので使えない——このパッケージは4つすべてへ組む。

ok "a consumer builds for a triple its dependency's tests cannot be built for" \
    -C fw build --no-compdb --target=$FW_T

# 依存の検査は、どの三つ組でも使う側からは組まれない。ホスト付きの側でも
# 同じ規則である——以前はここだけ「余計に組まれる」形で無害に見えていた。
built=$("$DOWEL" -C cli build --no-compdb 2>&1 | sed -n 's/^built: //p' | sed 's|.*/||' | sort | paste -sd' ' -)
_last_cmd="dowel -C cli build | built:"; OUT="${built:-(nothing)}"; RC=0
! printf '%s' "$built" | grep -q 'vectors'
fact $? "a consumer never builds the dependency's own tests, on a hosted triple either"

# 絞られた目標は、その三つ組の計画に**現れない**。誤りではなく圏外である。
n=$("$DOWEL" -C core graph --kind=action --format=json --target=$FW_T 2>/dev/null |
    jq -r '[.steps[] | select(.arguments | join(" ") | test("vectors"))] | length')
_last_cmd="graph --target=$FW_T | vectors を含む手順の数"; OUT="steps: ${n:-?}"; RC=0
[ "${n:-1}" = 0 ]
fact $? "a target outside its triples does not appear in that triple's plan"

# しかし名指しは断る。名指しは要求であり、黙って何も作らない build は
# 成功に読める。
run build vectors --no-compdb --target=$FW_T -C core
_last_cmd="dowel build vectors --target=$FW_T"
OUT=$(printf '%s' "$OUT" | grep -m3 'error\|note')
[ "$RC" -ne 0 ]
fact $? "while naming it there is refused, because a build that quietly produces nothing reads as success"

# 圏内の三つ組では、同じ目標が普通に組まれて走る。
ok "and on a triple it does declare, the same target builds and runs" \
    -C core test --no-compdb --target=$ARM_T

# ------------------------------------------------------------ 7. 重い依存を持つ使う側
#
# 4番目の使い方。cairo を引く木からも、同じ算法がそのまま引ける。

ok "a consumer that pulls a system library builds against the same algorithm" \
    -C gui build --no-compdb

# 算法の側は何も変わらない。cairo はこの使う側の private な依存であり、
# core の翻訳にも成果物にも現れない。
got=$("$DOWEL" -C gui graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc" and (.arguments | join(" ") | test("biquad")))
             | .arguments | join(" ")')
_last_cmd="graph | biquad.c の引数（gui から）"; OUT="$got"; RC=0
! printf '%s' "$got" | grep -q 'cairo'
fact $? "and the algorithm's own translation never sees that library"

view=$(bin_for gui dspview $HOST_T)
said=$("${view:-/nonexistent}" --out drawn.ppm 2>&1)
_last_cmd="dspview --out drawn.ppm"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'rough_in=1342514 rough_out=98452'
fact $? "the picture is drawn from the same numbers the other three triples printed"

# 描いたものを読み返す。窓ではなく画素を見る。
_last_cmd="head -2 drawn.ppm"; OUT=$(head -2 drawn.ppm 2>&1 | tr '\n' ' '); RC=0
[ "$(sed -n '2p' drawn.ppm 2>/dev/null)" = "512 200" ]
fact $? "and what it wrote has the dimensions it reported"

# 隅は背景のままである。単色で塗ってあるので厳密に一致する。
corner=$(python3 -c '
import sys
d = open("drawn.ppm","rb").read()
i = 0
for _ in range(3):
    i = d.index(b"\n", i) + 1
print("%02x%02x%02x" % (d[i], d[i+1], d[i+2]))
' 2>&1)
_last_cmd="drawn.ppm の最初の画素"; OUT="$corner"; RC=0
[ "$corner" = "101418" ]
fact $? "with the corner left exactly the declared background colour"

# ------------------------------------------------------------ 8. 対象が混ざらない

n=$(ls -d core/.dowel/build/*/ 2>/dev/null | wc -l)
_last_cmd="ls core/.dowel/build"; RC=0
OUT=$(ls -d core/.dowel/build/*/ 2>/dev/null | sed 's|.*/build/||')
[ "$n" -ge 3 ]
fact $? "each triple keeps its own build directory"

# 同じ書庫の名前が、対象ごとに別の中身である。
a_lib=$(md5sum "core/.dowel/build/$ARM_T-debug/lib/libdsp.a" 2>/dev/null | cut -c1-8)
r_lib=$(md5sum "core/.dowel/build/$RV_T-debug/lib/libdsp.a" 2>/dev/null | cut -c1-8)
_last_cmd="md5 libdsp.a (ARM)   vs   (RISC-V)"
OUT="ARM:    ${a_lib:-?}"$'\n'"RISC-V: ${r_lib:-?}"; RC=0
[ -n "$a_lib" ] && [ -n "$r_lib" ] && [ "$a_lib" != "$r_lib" ]
fact $? "and the archive of the same name differs between them, as it must"

# ------------------------------------------------------------ 9. 増分
#
# 対象が増えると、組み直しが対象をまたいで波及しないことが効いてくる。

"$DOWEL" -C core build --no-compdb --target=$ARM_T >/dev/null 2>&1
runs_actions 0 "a second build for one triple runs nothing" \
    -C core --no-compdb --target=$ARM_T

printf '\n/* touched */\n' >>core/src/biquad.c
build_direct -C core --no-compdb --target=$ARM_T
rebuilt "biquad.c" "editing the algorithm recompiles it for the triple being built"
not_rebuilt "crc32.c" "and leaves the other source alone"

# 別の対象は、まだ古いままである。触れていない対象の成果物を、
# 触った対象のビルドが道連れにしない。
runs_actions "+" "while another triple is rebuilt only when it is asked for" \
    -C core --no-compdb --target=$RV_T
