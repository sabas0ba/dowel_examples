# apps/plot — GUI
#
# GUI は「走らせて見る」ことができない層だと思われがちである。実際には、
# 確かめられないのは**窓が綺麗かどうか**だけであって、その手前はすべて
# 機械にかけられる。境目をどこに引くかが設計であり、それを支えられるかが
# ビルドツールへの問いになる。
#
#   core/   描画。画素の並びを作るところまで。cairo にだけ依存し、窓を知らない
#   ui/     見せる側。窓を開く実装とファイルへ書く実装があり、選ばれた側だけ翻訳される
#
# この層でしか問われないもの。
#
#   - **任意の依存**。窓を開く構成だけが X11 を要る。要らない構成の成果物に
#     X11 が残っていたら、それは配布先の前提を1つ増やしたということである
#   - **システムの依存が複数**。cairo と X11 を pkg-config 経由で引き、
#     解決を `dowel.lock` に残す
#   - **描いたものを読み返す**。窓ではなく画素を見る
#   - **窓を開くところまで走らせる**。Xvfb の上でなら、GUI でもそこまで行ける
#   - **実装を排他に選ぶ書き方**。`when` を2つ並べる形は排他にならない（F-031）

XVFB=xvfb-run

# ------------------------------------------------------------ 道具立て

# plot <構成識別子の末尾> — その構成の実行ファイル（絶対パス）。
# 末尾で合わせる。`-debug-headless` は `-debug-headless+plot-core/sanitize…`
# に一致してはならない（計装した版は別物である）。
plot() {
    local p
    p=$(find "$PWD/ui/.dowel/build" -type f -path "*$1/bin/plot" 2>/dev/null | head -1)
    printf '%s' "${p:-/nonexistent}"
}

# needed <実行ファイル> — 実行時に要る共有ライブラリ。
needed() {
    readelf -d "$1" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' | sort
}

# link_args [dowel args...] — plot のリンク引数。
link_args() {
    "$DOWEL" -C ui graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r '.steps[] | select(.kind == "link" and (.target | test("plot:plot")))
               | ([.program] + .arguments) | join(" ")'
}

# shells [dowel args...] — 翻訳された shell_*.c の名前。
shells() {
    "$DOWEL" -C ui graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r '.steps[] | select(.kind == "cc") | ([.program] + .arguments)[]' |
        grep -o 'shell_[a-z0-9]*\.c' | sort -u | paste -sd' ' -
}

# on_display <実行ファイル> <引数...> — Xvfb の上で走らせる。
SAID=""
on_display() {
    local bin=$1; shift
    SAID=$($XVFB -a "$bin" "$@" 2>&1)
    RC=$?
    _last_cmd="xvfb-run -a plot $*"
    return 0
}

# ppm_pixel <ファイル> <番号> — PPM の n 番目の画素を 0xRRGGBB で。
ppm_pixel() {
    python3 - "$1" "$2" <<'PY'
import sys
data = open(sys.argv[1], "rb").read()
# P6\n<w> <h>\n255\n のあと本体。見出しは3行である。
head, body = data.split(b"\n", 3)[:3], data.split(b"\n", 3)[3]
i = int(sys.argv[2]) * 3
print("0x%02X%02X%02X" % (body[i], body[i + 1], body[i + 2]))
PY
}

# ------------------------------------------------------------ 1. 組める

ok "the drawing package passes check" -C core check
ok "and builds"                       -C core build --no-compdb
ok "its pixel tests pass"             -C core test

ok "the default configuration of the shell builds" -C ui build --no-compdb
ok "and so does the one that opens a window" \
    -C ui build --no-compdb --no-default-features --features=x11

# ------------------------------------------------------------ 2. システムの依存
#
# cairo は `version` 依存であり、pkg-config が解決する。描画は cairo の
# **private** な利用者である。使う側は cairo の見出しを知らなくてよいが、
# リンクの閉包には乗らなければならない（F-018 で入った性質）。

_last_cmd="graph --kind=action | select(.kind==\"link\")"
OUT=$(link_args)
RC=0
printf '%s' "$OUT" | grep -q -- '-lcairo'
fact $? "the system library the drawing package uses reaches the link of the shell"

got=$("$DOWEL" -C ui graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc" and (.target | test("plot:plot")))
             | ([.program] + .arguments) | join(" ")')
_last_cmd="cc_args plot:plot"; OUT="$got"; RC=0
! printf '%s' "$got" | grep -q 'include/cairo'
fact $? "but its headers do not, because the dependency was declared private"

# 解決は記録される。同じ機械でしか通らない前提を、記録の外に置かないため。
assert "the resolution is written to a lock file" test -f ui/dowel.lock
_last_cmd="cat ui/dowel.lock"
OUT=$(cat ui/dowel.lock 2>/dev/null)
RC=0
printf '%s' "$OUT" | grep -q 'name *= *"cairo"'
fact $? "and the lock names the package that was resolved"

lock=$(cat ui/dowel.lock 2>/dev/null)
printf '%s' "$lock" | grep -q 'source *= *"pkg-config"'
v=$?; RC=0; _last_cmd="cat ui/dowel.lock"; OUT="$lock"
fact $v "with the mechanism that resolved it"

# ------------------------------------------------------------ 3. 任意の依存
#
# 窓を開く構成だけが X11 を要る。要らない構成の成果物に X11 が残っていたら、
# それは配布先の前提を1つ増やしたということである。GUI のアプリでは、
# 「表示の無い機械でも動く版」が要ることは珍しくない。

hl=$(plot '-debug-plot--headless')
x=$(plot '-debug-plot--x11')

got=$(needed "$hl")
! printf '%s' "$got" | grep -q 'libX11'
v=$?; RC=0; _last_cmd="readelf -d plot | NEEDED   # 既定の構成"
OUT="$got"
fact $v "the configuration that opens no window does not need X11 at run time"

printf '%s' "$got" | grep -q 'libcairo'
v=$?; RC=0; _last_cmd="readelf -d plot | NEEDED   # 既定の構成"
OUT="$got"
fact $v "though it still needs the drawing library it actually uses"

got=$(needed "$x")
printf '%s' "$got" | grep -q 'libX11'
v=$?; RC=0; _last_cmd="readelf -d plot | NEEDED   # --features=x11"
OUT="$got"
fact $v "and the configuration that does open one needs X11"

# 依存の辺そのものが現れたり消えたりする。引数に出ているだけではなく、
# 有効でないときはパッケージが読み込まれてすらいない。
OUT=$(link_args)
RC=0; _last_cmd="graph --kind=action | select(.kind==\"link\")   # 既定の構成"
! printf '%s' "$OUT" | grep -q -- '-lX11'
fact $? "the optional dependency is absent from the plan, not merely unused"

# 実装の差し替えも同じ形である。選ばれなかった側は翻訳されない。
got=$(shells)
[ "$got" = "shell_headless.c" ]
v=$?; RC=0; _last_cmd="graph --kind=action | 翻訳された shell_*.c"
OUT="compiled: ${got:-(none)}"
fact $v "only the chosen shell is compiled"

got=$(shells --no-default-features --features=x11)
[ "$got" = "shell_x11.c" ]
v=$?; RC=0; _last_cmd="graph ... --features=x11 | 翻訳された shell_*.c"
OUT="compiled: ${got:-(none)}"
fact $v "and choosing the other feature compiles the other one"

# 成果物自身に名乗らせる。引数の形だけでは、翻訳された側が実際に
# リンクされたかどうかは分からない。
got=$("$hl" --shell 2>&1)
[ "$got" = "headless" ]
v=$?; RC=0; _last_cmd="plot --shell"; OUT="said: ${got:-(nothing)}"
fact $v "the default artifact says which shell it carries"

got=$("$x" --shell 2>&1)
[ "$got" = "x11" ]
v=$?; RC=0; _last_cmd="plot --shell   # --features=x11"; OUT="said: ${got:-(nothing)}"
fact $v "and the windowed artifact says the other one"

# ------------------------------------------------------------ 3.5 排他の宣言 (F-031)
#
# 見せ方は択一である。機能は加算なので、`--features=x11` は既定の
# `headless` を落とさない。両方立った木は組み上がってはならない。
#
# 以前は宣言する場所が無く、`bin` ではリンカの `multiple definition`、
# `lib` では**黙って片方が勝つ**という形で現れた。F-031 / #82 として報告し、
# `exclusive` が入った。

_last_cmd="grep exclusive ui/dowel.toml"
OUT=$(grep -n 'exclusive' ui/dowel.toml)
RC=0
[ -n "$OUT" ]
fact $? "a package can declare which of its features are exclusive"

diag conflicting-features "and asking for both at once is refused" \
    -C ui check --features=x11

run -C ui check --features=x11
said=$OUT
_last_cmd="dowel -C ui check --features=x11"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'comes from `default`'
fact $? "the diagnostic says the other one came from default, which is the usual cause"

ok "dropping the defaults and asking for one builds" \
    -C ui check --no-default-features --features=x11

# 択一が守られているので、翻訳される見せ方は常に1つである。
got=$(shells --no-default-features --features=x11)
[ "$got" = "shell_x11.c" ]
v=$?; RC=0; _last_cmd="graph ... --no-default-features --features=x11"
OUT="compiled: ${got:-(none)}"
fact $v "and exactly one shell is compiled, whichever way the flag goes"

# ------------------------------------------------------------ 4. 描いたものを読み返す
#
# 「窓が綺麗か」は確かめられない。「何が描かれたか」は確かめられる。
# 描画をライブラリに切り出したのは、そこに境目を引くためである。

sh_run "$hl" --out out.ppm --size 64x32
_last_cmd="plot --out out.ppm --size 64x32"
[ "$RC" -eq 0 ] && [ -f out.ppm ]
fact $? "rendering to a file succeeds"

_last_cmd="head -c 15 out.ppm"
OUT=$(head -c 15 out.ppm 2>/dev/null | tr '\n' ' ')
RC=0
printf '%s' "$OUT" | grep -q '^P6 64 32 255'
fact $? "the file carries the size that was asked for"

# 背景は単色で塗る。したがって隅の画素は厳密にその値になる。
got=$(ppm_pixel out.ppm 0)
[ "$got" = "0x101418" ]
v=$?; RC=0; _last_cmd="out.ppm の最初の画素"
OUT="want: 0x101418 (PLOT_BACKGROUND)"$'\n'"got:  ${got:-(nothing)}"
fact $v "and the first pixel is exactly the background colour the header declares"

# 見出しは3行である。その後ろが本体で、1画素 3 バイト。
head_len=$(python3 -c '
import sys
d = open("out.ppm", "rb").read()
n = 0
for _ in range(3):
    n = d.index(b"\n", n) + 1
print(n)
' 2>/dev/null)
n=$(stat -c%s out.ppm 2>/dev/null)
[ -n "$head_len" ] && [ "$n" = "$((head_len + 64 * 32 * 3))" ]
v=$?; RC=0; _last_cmd="stat -c%s out.ppm"
OUT="header: ${head_len:-?} bytes + 64*32*3 = $((${head_len:-0} + 64 * 32 * 3))"$'\n'"got:    ${n:-?}"
fact $v "the body holds one pixel for each pixel of the canvas"
rm -f out.ppm

# ------------------------------------------------------------ 5. 窓を開くところまで
#
# ここから上は画素では確かめられない。Xvfb を相手にすれば、**本物の
# X の伺服体に繋いで窓を作り、画素を置く**ところまで実際に走らせられる。
# 組み込みで qemu を相手にするのと同じ形である。

on_display "$x" --size 64x32
said=$SAID
[ "$RC" -eq 0 ]
v=$?
OUT="$said"; RC=0
fact $v "the windowed build runs against a real X server"

printf '%s' "$said" | grep -q 'drew 64x32 on the display'
fact $? "and it gets as far as putting the image on the window"

# 表示が無いのは異常ではなく、よくある状況である。落ちてはならない。
sh_run env -u DISPLAY "$x" --size 64x32
said=$OUT; rc=$RC
_last_cmd="DISPLAY を外して plot"
OUT="rc: $rc"$'\n'"$said"; RC=0
[ "$rc" -eq 3 ]
fact $? "without a display it exits with a status of its own, not a signal"

_last_cmd="DISPLAY を外して plot"; OUT="$said"; RC=0
printf '%s' "$said" | grep -q 'cannot open display'
fact $? "and it says what is missing rather than dying inside the library"

# 表示が無くても、窓を開かない構成は動く。配布先の前提が本当に減っている
# ことを、成果物の NEEDED ではなく実行で確かめる。
sh_run env -u DISPLAY "$hl" --out headless.ppm --size 8x8
_last_cmd="DISPLAY を外して plot   # 既定の構成"
[ "$RC" -eq 0 ] && [ -f headless.ppm ]
fact $? "while the other configuration renders with no display at all"
rm -f headless.ppm

# ------------------------------------------------------------ 6. 実行時に落ちないこと
#
# 描画は境界の計算だらけである。大きさ、範囲、割り算。計装して実際に食わせる。

ok "the instrumented configuration builds" -C ui build --no-compdb --features=sanitize
ok "and its tests pass"                    -C core test --features=sanitize

hs=$(plot 'plot--sanitize')
report=$(PLOT="$hs" python3 - <<'PY' 2>&1
import os, subprocess

bin = os.environ["PLOT"]
cases = {
    "a 1x1 canvas":                ["--size", "1x1"],
    "a canvas with no area":       ["--size", "0x0"],
    "a negative size":             ["--size", "-3x7"],
    "a size that is not a size":   ["--size", "zzz"],
    "a very wide canvas":          ["--size", "4000x3"],
    "a very tall canvas":          ["--size", "3x4000"],
    "one data point":              ["7"],
    "two equal points":            ["5", "5"],
    "values that are not numbers": ["1", "nan", "inf", "-inf", "2"],
    "more points than fit":        [str(i) for i in range(200)],
    "an unwritable output":        ["--out", "/proc/nope/out.ppm"],
    "no arguments at all":         [],
}
bad = []
for name, argv in cases.items():
    p = subprocess.run([bin, "--out", "/dev/null"] + argv, capture_output=True)
    why = []
    if p.returncode < 0:
        why.append("killed by signal %d" % -p.returncode)
    elif p.returncode not in (0, 2):
        why.append("exit %d" % p.returncode)
    err = p.stderr
    if b"runtime error" in err or b"Sanitizer" in err:
        why.append(err.decode("utf-8", "replace").strip().splitlines()[0])
    if why:
        bad.append("%s: %s" % (name, "; ".join(why)))
print("\n".join(bad) if bad else "%d canvases, none crashed" % len(cases))
PY
)
printf '%s' "$report" | grep -q 'none crashed'
v=$?
RC=0; _last_cmd="draw 12 awkward canvases with the instrumented build"
OUT="$report"
fact $v "awkward sizes and values are refused or drawn, never crash the renderer"

# 窓を開く経路も計装して走らせる。X の伺服体との往復は、画素の計算とは
# 別の記憶を触る。
ok "the windowed configuration builds instrumented too" \
    -C ui build --no-compdb --no-default-features --features=x11,sanitize

xs=$(plot 'plot--sanitize+plot--x11')
on_display "$xs" --size 32x16
said=$SAID
[ "$RC" -eq 0 ]
v=$?
OUT="$said"; RC=0
fact $v "and opening a real window under instrumentation reports nothing"

printf '%s' "$said" | grep -qE 'runtime error|Sanitizer'
verdict=$?
_last_cmd="xvfb-run plot   # --features=x11,sanitize"; OUT="$said"; RC=0
[ "$verdict" -ne 0 ]
fact $? "the image handed to the server is not read past its own buffer"

# ------------------------------------------------------------ 7. 増分

"$DOWEL" -C ui build --no-compdb >/dev/null 2>&1
runs_actions 0 "a second build of the same configuration runs nothing" -C ui --no-compdb

printf '\n/* touched */\n' >>core/src/render.c
build_direct -C ui --no-compdb
rebuilt "render.c" "editing the drawing source recompiles it"
rebuilt "plot"     "and the shell is linked again"
not_rebuilt "canvas.c" "while its neighbour is left alone"
