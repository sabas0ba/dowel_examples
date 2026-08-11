# apps/vision — 大きい依存
#
# ここまでのアプリが使ってきたシステムの依存は、cairo と X11 が最大だった
# （`-lcairo -lX11` の2つ）。実務で当たるのはそれより一桁大きい。OpenCV の
# `.pc` は**リンク旗を 55 個**出す。しかも中身は C++ であり、GL は C である。
#
#   core/   描いて数える。OpenGL（OSMesa）で描画し、OpenCV で解析する
#   cli/    使う側。C で書いてあり、GL も OpenCV も知らない
#
# この層でしか問われないもの。
#
#   - **旗の量。** 55 個が順序も重複も崩さずに届くか。静的にリンクする木では
#     並びが意味を持つので、「全部ある」だけでは足りない
#   - **2つの大きい依存が1つの成果物に乗る。** GL は C、OpenCV は C++
#   - **面を保てるか。** 中が C++ でも、使う側が C なら C ABI の境界になる。
#     使う側の翻訳に GL も OpenCV も現れてはならない
#   - **表示を持たない機械で GL を走らせる。** OSMesa は文脈を作れるので、
#     「窓が開いたか」ではなく**何が描かれたか**を機械にかけられる

RE=readelf

# link_args [dowel args...] — 使う側のリンク引数。
link_args() {
    "$DOWEL" -C cli graph --kind=action --format=json "$@" 2>/dev/null |
        jq -r '.steps[] | select(.kind == "link" and (.target | test("vision:vis")))
               | .arguments[]'
}

# cc_args_of <目標> — その目標の翻訳引数。
cc_args_of() {
    "$DOWEL" -C cli graph --kind=action --format=json 2>/dev/null |
        jq -r --arg t "$1" '.steps[] | select(.kind == "cc" and .target == $t)
               | .arguments | join(" ")'
}

# vis <引数...> — 使う側の実行ファイルを走らせる。
vis() {
    local b
    b=$(find cli/.dowel/build -type f -path '*-debug/bin/vis' 2>/dev/null | head -1)
    "${b:-/nonexistent}" "$@" 2>&1
}

# field <出力> <名前> — `size=64x48 bright=962` から1つ取り出す。
field() {
    printf '%s' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p"
}

# ------------------------------------------------------------ 1. 組める

ok "the drawing package passes check" -C core check
ok "and builds"                       -C core build --no-compdb
ok "the C consumer builds against it" -C cli  build --no-compdb

# ------------------------------------------------------------ 2. 旗の量
#
# `.pc` が 55 個の旗を出す依存は、`-lcairo` 1つとは別の問題を持つ。
# 全部届くか、重複していないか、そして**順序が保たれているか**。
# 静的にリンクする木では並びが解決の順序そのものである。

want=$(pkg-config --libs opencv4 2>/dev/null | tr ' ' '\n' | grep -c '^-lopencv_')
got=$(link_args | grep -c '^-lopencv_')
[ -n "$want" ] && [ "$want" -gt 20 ] && [ "$got" = "$want" ]
v=$?; RC=0; _last_cmd="graph | link の -lopencv_*   vs   pkg-config --libs opencv4"
OUT="pkg-config: ${want:-?}"$'\n'"reached the link: ${got:-?}"
fact $v "every library a large pkg-config package names reaches the link"

diff <(pkg-config --libs opencv4 2>/dev/null | tr ' ' '\n' | grep '^-lopencv_') \
     <(link_args | grep '^-lopencv_') >/dev/null 2>&1
v=$?; RC=0; _last_cmd="diff <(pkg-config --libs) <(graph の -l)"
OUT="the order a static link resolves in must not be rearranged"
fact $v "in the order the package gave them, which is what a static link reads"

n=$(link_args | grep '^-l' | sort | uniq -d | wc -l)
[ "$n" = 0 ]
v=$?; RC=0; _last_cmd="graph | link の -l | sort | uniq -d"
OUT="duplicated flags: ${n:-?}"$'\n'"$(link_args | grep '^-l' | sort | uniq -d)"
fact $v "and without repeating any of them"

# 2つ目の大きい依存も同じ行に乗る。片方が他方を押し出さないこと。
link_args | grep -q '^-lOSMesa'
v=$?; RC=0; _last_cmd="graph | link の -lOSMesa"
OUT=$(link_args | grep '^-l' | head -3 | paste -sd' ' -)
fact $v "a second system dependency lands on the same link line"

# ------------------------------------------------------------ 3. 面を保つ
#
# 中は C++ で、GL と OpenCV に依存している。使う側は C であり、
# どちらも知らない。private な依存は翻訳には届かず、リンクには届く。

got=$(cc_args_of "vision:vis")
_last_cmd="cc_args vision:vis"; OUT="$got"; RC=0
! printf '%s' "$got" | grep -q 'opencv'
fact $? "the consumer's translation never sees the image library's headers"

_last_cmd="cc_args vision:vis"; OUT="$got"; RC=0
printf '%s' "$got" | grep -q 'core/include'
fact $? "only the one public include directory reaches it"

# 面は C ABI を名乗る。使う側は C（gnu11）であり、中は C++（c++17）である。
_last_cmd="grep abi core/dowel.build cli/dowel.build"
OUT=$(grep -h '^abi' core/dowel.build cli/dowel.build)
RC=0
printf '%s' "$OUT" | grep -q '"c"'
fact $? "the C++ library declares the C ABI boundary, so a C consumer may differ"

# 閉包に C++ があるので、リンクは C++ のドライバを通る。使う側が C でも
# C++ の実行時が要る——それを利用者に書かせないのが閉包の仕事である。
got=$("$DOWEL" -C cli graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "link" and (.target | test("vision:vis"))) | .program')
case $got in *++*|*clang++*) v=0 ;; *) v=1 ;; esac
RC=0; _last_cmd="graph | link | .program"; OUT="linker driver: ${got:-(none)}"
fact $v "and the link runs through the C++ driver although the consumer is C"

# 言語ごとの標準が別々に届く。C++ の側に c11 は行かない。
got=$(cc_args_of "vision:vis")
printf '%s' "$got" | grep -q 'std=c11'
v=$?; RC=0; _last_cmd="cc_args vision:vis | -std"
OUT="$got"
fact $v "the C consumer is compiled to the C standard it declared"

got=$("$DOWEL" -C core graph --kind=action --format=json 2>/dev/null |
      jq -r '.steps[] | select(.kind == "cc" and (.target | test("vis"))) | .arguments | join(" ")' |
      head -1)
printf '%s' "$got" | grep -q 'std=c++17'
v=$?; RC=0; _last_cmd="cc_args vision-core:vis | -std"
OUT="$got"
fact $v "while the C++ library is compiled to its own"

# ------------------------------------------------------------ 4. 実行時に要るもの

bin=$(find cli/.dowel/build -type f -path '*-debug/bin/vis' | head -1)
needed=$($RE -d "${bin:-/nonexistent}" 2>/dev/null |
         sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' | sort)
printf '%s' "$needed" | grep -q 'libOSMesa'
v=$?; RC=0; _last_cmd="readelf -d vis | NEEDED"; OUT="$needed"
fact $v "the artifact needs the graphics library at run time"

printf '%s' "$needed" | grep -q 'libopencv_core'
v=$?; RC=0; _last_cmd="readelf -d vis | NEEDED"; OUT="$needed"
fact $v "and the parts of the image library it actually calls"

# 55 個を渡しても、実際に要るのは呼んだものだけである。リンカが落とす。
n=$(printf '%s' "$needed" | grep -c 'libopencv_')
[ "$n" -lt 20 ]
v=$?; RC=0; _last_cmd="readelf -d vis | NEEDED | grep opencv"
OUT="linked: 55 flags"$'\n'"needed at run time: ${n:-?} of them"$'\n'"$needed"
fact $v "though far fewer than the flags it was given, because the linker drops the rest"

# ------------------------------------------------------------ 5. 走らせて答が合う
#
# GL は表示を持たない機械でも文脈を作れる（OSMesa）。だから「窓が開いたか」
# ではなく**何が描かれたか**を機械にかけられる。背景は単色で塗るので、
# 隅の画素は厳密に一致する。

said=$(vis --blank)
_last_cmd="vis --blank"; OUT="$said"; RC=0
[ "$(field "$said" corner)" = "101418" ]
fact $? "a blank render leaves the corner exactly the declared background colour"

[ "$(field "$said" bright)" = "0" ]
v=$?; RC=0; _last_cmd="vis --blank"; OUT="$said"
fact $v "and nothing on it is bright"

said=$(vis)
_last_cmd="vis"; OUT="$said"; RC=0
n=$(field "$said" bright)
[ -n "$n" ] && [ "$n" -gt 0 ] && [ "$n" -lt 3072 ]
fact $? "drawing a triangle marks some of the image but not all of it"

[ "$(field "$said" corner)" = "101418" ]
v=$?; RC=0; _last_cmd="vis"; OUT="$said"
fact $v "and the corner stays background, because a triangle does not reach it"

said=$(vis --size 128x96)
_last_cmd="vis --size 128x96"; OUT="$said"; RC=0
[ "$(field "$said" size)" = "128x96" ]
fact $? "the size asked for is the size rendered"

# 数えたものが解析の結果であること。閾値を上げれば減る。
a=$(field "$(vis --threshold 8)" bright)
b=$(field "$(vis --threshold 250)" bright)
[ -n "$a" ] && [ -n "$b" ] && [ "$a" -ge "$b" ]
v=$?; RC=0; _last_cmd="vis --threshold 8   vs   --threshold 250"
OUT="threshold 8: ${a:-?}"$'\n'"threshold 250: ${b:-?}"
fact $v "raising the threshold never counts more pixels, so the count is really measured"

ok "the library's own cases all pass" -C core test

# ------------------------------------------------------------ 6. 実行時に落ちないこと
#
# 描画も解析も境界の計算だらけである。計装して、無理のある寸法を食わせる。
#
# 大きい依存を計装すると、下敷きのライブラリ自身が返さない割り当てが出る。
# OSMesa は文脈を捨てても内部の表を解放しない。計装されていない `.so` の
# 中の話なので、こちらの漏れと見分けはつかない。黙らせる先を教える口は
# 環境変数しか無く、それを宣言に書けるのが `[test.<name>.cases]` の `env`
# である。相対で書けるのは case の作業ディレクトリがパッケージの根だと
# 約束されているためで、この2つは組で効く。

ok "the instrumented configuration builds" -C cli build --no-compdb --features=sanitize
ok "and the library's cases pass under it" -C core test --features=sanitize

# 上が緑なのは、漏れを見ていないからではない。同じ実行ファイルを、宣言が
# 指す抑制の一覧**なしで**走らせると、下敷きの漏れがそのまま出る。つまり
# 検知は生きており、通ったのは `env` が届いたからである。
sanunit=$(find core/.dowel/build -type f -path '*sanitize*/bin/unit' | head -1)
sanunit=$([ -n "$sanunit" ] && (cd "$(dirname "$sanunit")" && printf '%s/unit' "$PWD"))
bare=$(cd core && LSAN_OPTIONS=suppressions=/dev/null "${sanunit:-/nonexistent}" triangle 2>&1)
v=$?
_last_cmd="LSAN_OPTIONS=suppressions=/dev/null unit triangle"
OUT=$(printf '%s' "$bare" | grep -m3 'LeakSanitizer\|SUMMARY')
[ "$v" != 0 ] && printf '%s' "$bare" | grep -q 'LeakSanitizer'
fact $? "the same binary reports leaks when the suppressions the manifest named are withheld"

# 抑制は名指しである。こちらの翻訳単位から出た漏れは黙らない。
_last_cmd="cat core/lsan.supp"; OUT=$(grep -v '^#' core/lsan.supp | grep .); RC=0
[ "$(printf '%s' "$OUT" | grep -c .)" = 1 ] && printf '%s' "$OUT" | grep -q '^leak:lib'
fact $? "and what it suppresses is one named library, not leak detection itself"

sanbin=$(find cli/.dowel/build -type f -path '*sanitize*/bin/vis' | head -1)
report=$(VIS="${sanbin:-/nonexistent}" \
         SUPP="$PWD/core/lsan.supp" python3 - <<'PY' 2>&1
import os, subprocess

bin = os.path.abspath(os.environ["VIS"])
env = dict(os.environ, LSAN_OPTIONS="suppressions=" + os.environ["SUPP"])
cases = {
    "a 1x1 image":                 ["--size", "1x1"],
    "an image with no area":       ["--size", "0x0"],
    "a negative size":             ["--size", "-4x8"],
    "a size that is not a size":   ["--size", "zzz"],
    "a very wide image":           ["--size", "2000x2"],
    "a very tall image":           ["--size", "2x2000"],
    "a threshold below the range": ["--threshold", "-5"],
    "a threshold above it":        ["--threshold", "999"],
    "a blank 1x1":                 ["--blank", "--size", "1x1"],
    "an unknown argument":         ["--nope"],
}
bad = []
for name, argv in cases.items():
    p = subprocess.run([bin] + argv, capture_output=True, timeout=300, env=env)
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
print("\n".join(bad) if bad else "%d renders, none crashed" % len(cases))
PY
)
printf '%s' "$report" | grep -q 'none crashed'
v=$?
RC=0; _last_cmd="render 10 awkward sizes with the instrumented build"
OUT="$report"
fact $v "awkward sizes and thresholds are refused or rendered, never crash"

# ------------------------------------------------------------ 7. 増分
#
# 依存が大きいと、組み直しの費用は「触った量」ではなく「触られた翻訳単位」で
# 決まってほしい。OpenCV の見出しは重く、1つ余計に翻訳すると体感に出る。

"$DOWEL" -C cli build --no-compdb >/dev/null 2>&1
runs_actions 0 "a second build of the consumer runs nothing" -C cli --no-compdb

printf '\n/* touched */\n' >>core/src/measure.cc
build_direct -C cli --no-compdb
rebuilt "measure.cc" "editing the analysis source recompiles it"
not_rebuilt "render.cc" "and leaves the drawing source alone, though both use the same big library"
rebuilt "vis" "while the consumer is linked again"
