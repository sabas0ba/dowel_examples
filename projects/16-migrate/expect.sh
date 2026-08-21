# 16-migrate — 既存のビルドからの移行
#
# 移行は片道である。下書きが黙って何かを落としても、利用者は組み上がった
# ものを見て「移った」と読む。落ちたものは、そのプロジェクトが動かなく
# なったときに初めて分かる。ここで固定するのは次の2つ。
#
#   1. 下書きに何が写り、何が写らないと明示されるか（migrate import）
#   2. 写した結果が元と同じ翻訳になるか（migrate verify）
#
# 2 は 1 の答合わせであり、import 自身が出力の最後で指している手順である。

# ------------------------------------------------------------ 下ごしらえ

# configure <src> <build> <type> — File API の問い合わせを置いてから構成する。
# migrate import が読むのは compile_commands.json ではなく codemodel-v2 の
# 応答であり、これは問い合わせを置いた場合にのみ書かれる。
configure() {
    mkdir -p "$2/.cmake/api/v1/query"
    : > "$2/.cmake/api/v1/query/codemodel-v2"
    cmake -S "$1" -B "$2" -G Ninja -DCMAKE_BUILD_TYPE="$3" >/dev/null 2>&1
}

# absent <文字列> <ファイル> <desc> — その文字列がファイルに無いこと。
# 「写らない」ことの検査は不在でしか観測できない。grep -v は「その語を
# 含まない行がある」を意味するため、この用途には使えない。
absent() {
    _last_cmd="grep -nF -- '$1' $2"
    OUT=$(grep -nF -- "$1" "$2" 2>&1)
    RC=0
    [ -z "$OUT" ]; _verdict $? "$3"
}

# ref <name> — 参照を複製先の絶対パスへ差し替えて置き、その道を返す。
# 参照の中の道は走らせる場所によって変わるため、雛形から毎回書き出す。
ref() {
    mkdir -p .refs
    sed "s|@ROOT@|$PWD|g" "refs/$1.json.in" >".refs/$1.json"
    printf '%s' "$PWD/.refs/$1.json"
}

# counts <参照> — verify を走らせ、4つのバケツの数を EQ / DIFF / UNPORTED /
# ONLY に、終了状態を RC に、出力を SAID に置く。
#
# 部分シェルで包むと呼び出し側に値が戻らない。また _verdict は次の検査へ
# 持ち越さないよう OUT を消すため、2つ以上の判定に使う出力は SAID に取る。
EQ=0; DIFF=0; UNPORTED=0; ONLY=0; SAID=""
counts() {
    _last_cmd="dowel migrate verify $1 --format=json"
    # 機械可読の答は stdout に出る。stderr は診断と進行であり、混ぜると
    # 警告1つで JSON が読めなくなる（docs/60-cli.md の出力の分け方）。
    SAID=$("$DOWEL" migrate verify "$1" --format=json 2>/dev/null)
    RC=$?
    OUT=$SAID
    EQ=$(printf '%s' "$SAID"       | jq -r '.equivalent'           2>/dev/null)
    DIFF=$(printf '%s' "$SAID"     | jq -r '.differing     | length' 2>/dev/null)
    UNPORTED=$(printf '%s' "$SAID" | jq -r '.unported      | length' 2>/dev/null)
    ONLY=$(printf '%s' "$SAID"     | jq -r '.only_in_dowel | length' 2>/dev/null)
}

# same <参照の名前> <desc> — その参照が dowel の計画と全件等価であること。
# 正規化の検査はすべてこの形になる。書き方を変えても答が変わらないこと、
# が見たいものだからである。
same() {
    counts "$(ref "$1")"
    [ "$RC" = 0 ] && [ "$EQ" = 2 ] && [ "$DIFF" = 0 ]
    fact $? "$2"
}

# reports <期待> <下書きの場所> <構成> <desc> — 下書きを組み、report に
# 翻訳された構成を名乗らせる（cmake-project/src/report.c）。
#
# 期待と実際は検査名ではなく、落ちたときの材料へ回す。名前に混ぜると
# 実行ごとに検査名が変わり、文書からも publish からも同じ行を指せなくなる
# （docs/00-design.md 6節）。名乗りは複数行であり、1検査1行の記録も壊す。
reports() {
    local want=$1 dir=$2 cfg=$3 desc=$4 bin got v
    "$DOWEL" -C "$dir" build --config="$cfg" --no-compdb >/dev/null 2>&1
    bin=$(find "$dir/.dowel/build" -type f -path "*-$cfg/bin/report" 2>/dev/null | head -1)
    _last_cmd="dowel -C $dir build --config=$cfg && ${bin:-<not built>}"
    got=$([ -n "$bin" ] && "$bin" 2>&1)
    [ "$got" = "$want" ]
    v=$?
    OUT="want: ${want//$'\n'/ }"$'\n'"got:  ${got//$'\n'/ }"
    fact "$v" "$desc"
}

# ------------------------------------------------------------ 取り込み
#
# 移行元を構成ごとに別の複製へ取り込む。import は上書きしないため、
# 1つの木へ2度は取り込めない。

cp -r cmake-project from-debug
cp -r cmake-project from-release
cp -r cmake-shapes  shapes

configure from-debug   bd-debug   Debug
configure from-release bd-release Release
configure shapes       bd-shapes  Debug

assert "cmake writes a compile database for the reference build" \
    test -f bd-debug/compile_commands.json

run migrate import bd-debug
imported=$OUT
[ "$RC" = 0 ]
fact $? "import drafts a manifest pair from the CMake File API"

assert "import writes a package manifest" test -f from-debug/dowel.toml
assert "import writes a build manifest"   test -f from-debug/dowel.build

assert "the package manifest is marked as an unverified draft" \
    grep -q 'UNVERIFIED DRAFT' from-debug/dowel.toml
assert "the build manifest is marked as an unverified draft" \
    grep -q 'UNVERIFIED DRAFT' from-debug/dowel.build

printf '%s' "$imported" | grep -q 'migrate verify'
fact $? "import points at the verify step that checks its own output"

assert "the package takes its name from the CMake project" \
    grep -q 'name *= *"demo"' from-debug/dowel.toml

# 対象の種類の対応。EXECUTABLE は bin、STATIC_LIBRARY は lib になる。
assert "an executable becomes a bin target" \
    grep -q '^\[bin\.demo\]' from-debug/dowel.build
assert "a static library becomes a lib target" \
    grep -q '^\[lib\.greet\]' from-debug/dowel.build

# glob() で書くと、取り込んだ時点の木と後の木が食い違っても気づけない。
# 下書きは「その構成の写像」であり、写した瞬間の一覧でなければならない。
assert "sources are listed one by one" \
    grep -q 'file("src/greet.c")' from-debug/dowel.build
absent 'glob(' from-debug/dowel.build \
    "globbing is not used for the imported sources"

assert "an in-project link becomes a target() dependency" \
    grep -q 'target("greet")' from-debug/dowel.build

# File API は「その include が依存元にも要るのか」を持たない。分からない
# ものを public にすると、伝播してはならないものが伝播する。分からない側へ
# 倒すのが安全であり、下書きは全て private で出す。
assert "includes and defines land in a private block" \
    grep -q '^\[lib\.greet\.private\]' from-debug/dowel.build
absent '.public]' from-debug/dowel.build \
    "nothing is drafted as public"

# ------------------------------------------------------------ 下書きが動くこと

ok "the drafted manifests pass check" -C from-debug check
ok "the drafted manifests build"      -C from-debug build --no-compdb

demo=$(find from-debug/.dowel/build -type f -path '*-debug/bin/demo' | head -1)
assert "the binary built from the draft runs and agrees with the CMake build" \
    "$PWD/${demo:-nonexistent}"

# ------------------------------------------------------------ 取り込みの拒否
#
# 移行は1回で終わらない。何度か試すのが普通であり、そのたびに手を入れた
# 下書きが消えるようでは使えない。

before=$(cat from-debug/dowel.build)
run migrate import bd-debug
said=$OUT
[ "$RC" -ne 0 ]
fact $? "import refuses to overwrite manifests that are already there"

[ "$(cat from-debug/dowel.build)" = "$before" ]
fact $? "the refusal leaves the existing manifest untouched"

printf '%s' "$said" | grep -qi 'already'
fact $? "the refusal says the manifests are already there"

mkdir -p bare-build
run migrate import bare-build
said=$OUT
[ "$RC" -ne 0 ]
fact $? "a build directory with no File API reply is refused"

printf '%s' "$said" | grep -q 'codemodel-v2'
fact $? "the refusal says how to produce the reply"

# ------------------------------------------------------------ 対象の種類
#
# CMake の対象の種類は dowel の語彙より多い。写せないものを黙って落とすと、
# 利用者は欠けた木を「移行できたもの」として組むことになる。

ok "every buildable target kind is imported" migrate import bd-shapes

assert "an object library becomes a lib target" \
    grep -q '^\[lib\.objs\]' shapes/dowel.build
assert "a shared library becomes a lib target too" \
    grep -q '^\[lib\.shr\]' shapes/dowel.build

# dowel は今のところ静的な archive しか作らない。同じ [lib.*] へ写しておきながら
# 何も言わないと、共有ライブラリのつもりの利用者が黙って別のものを得る。
assert "the draft says out loud that a shared library became a static one" \
    grep -q 'was a SHARED_LIBRARY' shapes/dowel.build

# INTERFACE ライブラリは翻訳単位を持たない。対象にはならないが、
# 使う側へ渡していた include は消えてはならない。
absent 'iface' shapes/dowel.build \
    "an interface library does not become a target of its own"
assert "what an interface library handed to its users survives" \
    grep -q 'includes = \[dir("include")\]' shapes/dowel.build

assert "a system library becomes a link flag" \
    grep -q '"-lm"' shapes/dowel.build

# ------------------------------------------------------------ 突き合わせ
#
# 以下は normalize/ の中で行う。移行の産物ではなく手で書いたパッケージを
# 相手にする。取り込みの側が変わっても、正規化の期待値は動かない。

cd normalize || exit 1

# 比べているのは計画であって成果物ではない。組まずに答が出ることは、
# 移行の途中（まだ通らない木）でも突き合わせられることを意味する。
counts "$(ref baseline)"
[ "$RC" = 0 ] && [ "$EQ" = 2 ] && [ ! -d .dowel/build ]
fact $? "verify compares plans, so it needs no build of its own"

same baseline  "the compiler name, -c, -o and the -MD family are not differences"
same spellings "-DA, -D A=1 and -DA=1 are the same define"
same relative  "a relative include is resolved against the entry's directory"
same shuffled  "the order of the arguments is not a difference"

# 正規化が効きすぎていないこと。上の4つだけでは、何を渡されても等価と
# 答える実装も通ってしまう。
counts "$(ref differing)"
[ "$DIFF" = 1 ] && [ "$EQ" = 1 ]
fact $? "a genuine difference is still reported"

printf '%s' "$SAID" |
    jq -e '.differing[0] | (.missing | index("-DEXTRA=1")) and (.extra | index("-Wall"))' \
    >/dev/null 2>&1
fact $? "the difference names both what the reference had and what dowel has"

[ "$RC" -ne 0 ]
fact $? "a differing entry makes the comparison fail"

# 差でないものは終了状態を変えない。移行の途中では、まだ移していない
# ファイルも、dowel 側にしかないテストも、どちらも普通に居る。
counts "$(ref partial)"
[ "$RC" = 0 ] && [ "$EQ" = 1 ] && [ "$ONLY" = 1 ]
fact $? "a file only dowel builds is counted apart, and does not fail"

counts "$(ref unported)"
[ "$RC" = 0 ] && [ "$UNPORTED" = 1 ]
fact $? "a file the reference builds and dowel does not is counted as not ported"

# 表示の形が変わっても、答が変わってはならない。
text=$("$DOWEL" migrate verify "$(ref differing)" 2>&1)
printf '%s' "$text" | grep -q '1 equivalent, 1 differing'
fact $? "the text form reports the same four buckets as the json form"

# ------------------------------------------------------------ 誤った参照

fails "a reference that is not there is refused" \
    migrate verify "$PWD/.refs/nowhere.json"
fails "a reference that is not JSON is refused" \
    migrate verify "$(ref broken)"
fails "an empty reference is refused" \
    migrate verify "$(ref empty)"

cd .. || exit 1

# ------------------------------------------------------------ 構成が決めるもの
#
# 最適化・デバッグ情報・NDEBUG は dowel の `--config` が決める。CMake 側では
# CMAKE_BUILD_TYPE が決める。**両方が同じことを別々に決める**ため、これらを
# 下書きへ写すと後勝ちで `--config` が効かなくなり、突き合わせでは常に差に
# なる。取り込みにも比較にも持ち込まないのが正しい（F-017）。
#
# 移行元は構成のフラグを CMake の既定のままにしてある。dowel の debug とも
# release とも一致しないため、持ち込まれていればここで必ず差が出る。

ok "a release build directory is imported the same way" migrate import bd-release

# 翻訳の側。#54 の修正はここに効いている。
absent 'flags    = ["-O' from-release/dowel.build \
    "the draft carries no optimization flag from the CMake build type"
absent 'defines  = { NDEBUG' from-release/dowel.build \
    "the CMake build type does not become a define in the draft"

# リンクの側。かつて同じ集合が link_flags に残っており、下書きの見出しが
# 述べる内容と食い違っていた（F-021）。見出しは NDEBUG に言及するため、
# 注釈の行は数えない。
_last_cmd="grep -v '^#' from-release/dowel.build | grep -F NDEBUG"
OUT=$(grep -v '^#' from-release/dowel.build | grep -nF -- 'NDEBUG' 2>&1)
RC=0
[ -z "$OUT" ]
fact $? "the draft carries no NDEBUG from a release CMake build type"

# 構成は dowel の側だけが決める。取り込み元がどちらでも、組んだ構成が
# そのまま出る。
reports $'assertions\nunoptimized' from-debug debug \
    "the drafted debug build of a debug import is unoptimized"
reports $'ndebug\noptimized' from-debug release \
    "the drafted release build is actually optimized"
reports $'assertions\nunoptimized' from-release debug \
    "the drafted debug build keeps assertions"
reports $'ndebug\noptimized' from-release release \
    "the drafted release build of a release import is optimized"

# import 自身が最後に指している手順。下書きが元と同じ翻訳を出すなら、
# これは何も報せずに終わる。
cd from-debug || exit 1
counts "$PWD/../bd-debug/compile_commands.json"
[ "$RC" = 0 ] && [ "$DIFF" = 0 ]
fact $? "the workflow that import prints verifies clean"

# 構成が決めるものは比較の両側から落ちる。したがって取り込み元の構成と
# 組む構成が食い違っていても、移行の忠実さの判定は変わらない。
counts "$PWD/../bd-release/compile_commands.json"
[ "$RC" = 0 ] && [ "$DIFF" = 0 ]
fact $? "verify ignores the build type on both sides, so any pairing is clean"
cd .. || exit 1

# ------------------------------------------------------------ Meson からの移行
#
# 移行元は CMake だけではない。Meson は `build/meson-info/` を自分で書くので、
# 問い合わせを置く手順が要らない。どちらから来たかは**ディレクトリを見て**
# 決まる（`--from=` は無い）。
#
# 渡す情報の形が違う。CMake は引数を仕分け済みで渡し、木の中の依存を名指し
# する。Meson は目標ごとに `parameters` 配列を1本渡すだけなので、仕分けは
# dowel が行い、依存の辺は分からないままになる（文書に明記されている）。
#
# その仕分けがまだ粗い。配列にはリンクと archive の引数も混ざっており、それが
# 翻訳の `flags` に入るため、**下書きがそのままでは組めない**（F-057）。

MESON_SRC=$PWD/meson-shapes
MESON_BUILD=$PWD/meson-build

command -v meson >/dev/null 2>&1 || {
    printf 'meson is missing; the migration layer needs it\n' >&2
    exit 2
}

rm -rf "$MESON_BUILD" "$MESON_SRC/dowel.toml" "$MESON_SRC/dowel.build"
sh_run meson setup "$MESON_BUILD" "$MESON_SRC"
_last_cmd="meson setup"
[ -d "$MESON_BUILD/meson-info" ]
fact $? "meson writes its introspection without being asked, unlike CMake's File API"

ok "import reads a Meson build directory" -C "$MESON_SRC" migrate import "$MESON_BUILD"

draft=$(cat "$MESON_SRC/dowel.build" 2>/dev/null)
_last_cmd="cat dowel.build"; OUT="$draft"; RC=0
printf '%s' "$draft" | grep -q 'UNVERIFIED DRAFT'
fact $? "and the draft says it is unverified, the same as one imported from CMake"

# 移行元の種別は書かれる。どちらから来たかで下書きの限界が違うので、
# 読む側にそれが分からなければ、何を疑えばよいかが決まらない。
_last_cmd="cat dowel.build | 見出し"; OUT=$(printf '%s' "$draft" | head -12); RC=0
printf '%s' "$draft" | grep -qi 'meson'
fact $? "naming Meson as where it came from"

# 写るもの。ソース、include、define。
_last_cmd="cat dowel.build"; OUT="$draft"; RC=0
printf '%s' "$draft" | grep -q 'src/area.c' && printf '%s' "$draft" | grep -q 'src/perim.c'
fact $? "the sources of each target are listed explicitly"

_last_cmd="cat dowel.build"; OUT="$draft"; RC=0
printf '%s' "$draft" | grep -q 'SHAPES_BUILD' && printf '%s' "$draft" | grep -q 'TOOL'
fact $? "with the defines sorted out of the parameters array"

_last_cmd="cat dowel.build"; OUT="$draft"; RC=0
printf '%s' "$draft" | grep -q 'dir("include")'
fact $? "and the include directories too"

# 構成の旗は写らない。Release から取り込んだ下書きが、最適化された NDEBUG の
# 「debug」を作ることになるためである。
# 見出しの注記には NDEBUG の語が出るので、宣言の行だけを見る。
_last_cmd="cat dowel.build | 宣言の行の -O / NDEBUG"
OUT=$(printf '%s' "$draft" | grep -v '^#' | grep '^flags')
RC=0
! printf '%s' "$draft" | grep -v '^#' | grep -qE '"-O[0-9s]"|NDEBUG'
fact $? "while the configuration-level flags are not, since dowel's own --config supplies them"

# 依存の辺は空のまま。Meson の introspection がリンクの関係を言わないので、
# 出力ファイル名から推測すれば、**未検証の下書きに誤った辺**が入る。
_last_cmd="cat dowel.build | deps"; OUT="$draft"; RC=0
! printf '%s' "$draft" | grep -q 'deps.*target('
fact $? "and deps is left empty, because Meson does not say which target links which"

# ------------------------------------------------------------ 引数の仕分け
#
# `parameters` には翻訳の引数だけでなく、リンクと archive の引数も混ざっている。
# かつてはそれが丸ごと翻訳の `flags` に入り、下書きがそのままでは組めな
# かった（F-057）。いまは行き先ごとに分けられる。

_last_cmd="cat dowel.build | flags"
OUT=$(printf '%s' "$draft" | grep '^flags')
RC=0
! printf '%s' "$draft" | grep -qE '^flags.*(-Wl,|\.a"|"csrDT")'
fact $? "the compile flags carry nothing that belongs to the link or the archiver"

_last_cmd="cat dowel.build | link_flags"
OUT=$(printf '%s' "$draft" | grep '^link_flags')
RC=0
printf '%s' "$draft" | grep -qE '^link_flags.*-Wl,'
fact $? "the linker's own arguments go to link_flags instead"

# 落としたものは**黙って**落とさない。下書きは未検証であり、消えたものが
# あることは読む側に伝わっていなければならない。
_last_cmd="cat dowel.build | 落としたものの註"
OUT=$(printf '%s' "$draft" | grep -i 'link input')
RC=0
printf '%s' "$draft" | grep -qi 'link input, not a compile flag'
fact $? "and what was dropped is noted rather than removed silently"

_last_cmd="同じ註"; OUT=$(printf '%s' "$draft" | grep -i 'link input'); RC=0
printf '%s' "$draft" | grep -q 'libshapes.a' && printf '%s' "$draft" | grep -q 'csrDT'
fact $? "naming both the archive it saw and the archiver's argument string"

# 註は行き先も言う。`deps` が空なのは Meson がリンクの関係を言わないためで
# あり（上で見た）、手で書くしかない。何を書けばよいかが註に出ている。
_last_cmd="同じ註"; OUT=$(printf '%s' "$draft" | grep -i 'link input'); RC=0
printf '%s' "$draft" | grep -qi 'declare it as a dep'
fact $? "and says what to write instead, which is the edge Meson never reported"

# 下書きはまだそのままでは組めない。ただし理由が変わった——`flags` の
# 混入ではなく、**書かれていない `deps`** である。これは文書どおりの限界で
# あり、註がその1行を指している。
run -C "$MESON_SRC" build --no-compdb
_last_cmd="dowel build  # Meson から取り込んだ下書き"
OUT=$(printf '%s' "$OUT" | grep -m3 'undefined reference\|error')
RC=0
printf '%s' "$OUT" | grep -q 'undefined reference'
fact $? "so what still stops the draft is the missing edge, not the arguments"

# `verify` は残る差分を挙げる。ここでは `-Wall` が参照側に2つ（Meson の
# 既定の警告水準と、明示した `c_args`）あり、dowel は1つに畳んでいる。
# 安全網が働いていることの確認であって、畳んだこと自体は誤りではない。
run -C "$MESON_SRC" migrate verify "$MESON_BUILD/compile_commands.json"
_last_cmd="dowel migrate verify"; OUT=$(printf '%s' "$OUT" | grep -m4 '^  [-+]'); RC=0
printf '%s' "$OUT" | grep -q 'in the reference, not in dowel'
fact $? "while verify still reports what differs, which is what makes the draft checkable"

# 対照。同じ木を CMake から取り込めば、そのまま組める。壊れているのが
# 移行そのものではなく Meson 側の仕分けであることが、これで読める。
rm -rf "$MESON_SRC/dowel.toml" "$MESON_SRC/dowel.build" "$MESON_SRC/cm"
cat >"$MESON_SRC/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(shapes C)
add_library(shapes STATIC src/area.c src/perim.c)
target_include_directories(shapes PRIVATE include)
target_compile_definitions(shapes PRIVATE SHAPES_BUILD=1)
add_executable(shapetool src/main.c)
target_include_directories(shapetool PRIVATE include)
target_link_libraries(shapetool shapes)
CMAKE
configure "$MESON_SRC" "$MESON_SRC/cm" Debug
ok "the same tree imports from CMake as well" -C "$MESON_SRC" migrate import "$MESON_SRC/cm"
ok "and that draft builds without editing" -C "$MESON_SRC" build --no-compdb
rm -f "$MESON_SRC/CMakeLists.txt"
rm -rf "$MESON_SRC/cm" "$MESON_BUILD"

# ------------------------------------------------------------ 取り込んだ印（ADR-0053）
#
# 下書きは verify に落ちない。**通る。** Meson も CMake も、結合の関係を
# 翻訳の引数に混ぜて報せるので、取り込み器はそれを落として註に書く。
# 偽ったことは何も無いので `check` に文句の付けようが無い。欠けているのは
# **誰も在ると主張していない `deps` の辺**であり、失敗は結合の段に、
# 結合器の言葉で、記号について返る。
#
# だから下げるものが無い。誤りを警告へ格下げする様式は、下書きが踏みも
# しない検査を抑え、しかも移行の途中で人が足した宣言まで抑えてしまう。
# 決定は「印を置く。何も緩めない」である。

cd from-debug || exit 1

assert "import marks every target it drafted" \
    grep -q '^unverified = true$' dowel.build

n=$(grep -c '^unverified = true$' dowel.build)
_last_cmd="grep -c 'unverified = true' dowel.build"; OUT="$n target(s) marked"; RC=0
[ "$n" -eq 3 ]
fact $? "one mark per target, the unit of migration being the target"

# 印は毎回の計画で報される。結合の中で気づくのではなく、その前に述べる。
diag unverified-import "every plan reports what is still unverified" check
diag_where unverified-import '.severity == "warning"' \
    "as a warning, so the draft still builds and runs" check
ok "and the draft does build with the mark in place" build --no-compdb

# 何が確かめられていないかを言う。「未検証」だけでは、利用者は次に何を
# 見ればよいか決められない。
out_has "came in private" "saying that everything came in private" check
out_has "not \`deps\` yet" "and that dropped link inputs are not dependencies yet" check
out_has "migrate verify" "and pointing at the step that checks it" check

# 機械可読の側にも出る。「どこまで移ったか」が記憶ではなく数になる。
codes=$("$DOWEL" check --message-format=json 2>/dev/null |
        jq -r 'select(.code == "unverified-import") | .message' | grep -c .)
_last_cmd="dowel check --message-format=json | unverified-import"
OUT="$codes warning(s)"; RC=0
[ "$codes" -eq 3 ]
fact $? "the mark is machine readable, so an editor can underline it"

# `migrate verify` が残りを数える。移行の単位が目標なので、進み方の単位も
# 目標である。
left=$("$DOWEL" migrate verify "$PWD/../bd-debug/compile_commands.json" --format=json 2>/dev/null |
       jq -r '.unverified | length')
_last_cmd="dowel migrate verify --format=json | .unverified"
OUT="$left target(s) still marked"; RC=0
[ "$left" -eq 3 ]
fact $? "verify counts what is still marked, beside the source-level verdict"

# 「等価」と「未検証」は矛盾しない。翻訳の行は一致しており、結合は
# ビルド以外の何にも見られていない——それが正直な状態である。
counts "$PWD/../bd-debug/compile_commands.json"
[ "$RC" = 0 ] && [ "$DIFF" = 0 ]
fact $? "and reporting the compile lines as equivalent is not a contradiction with that"

# 消すのは人だけである。`verify` は翻訳の引数を比べるだけで、落とした
# 結合入力が `deps` として戻されたことも、private と public の分け方が
# 意図どおりであることも知らない。印を消すことは「私が確かめた」という
# 主張であり、dowel はそれを利用者の代わりに言える立場にない。
before=$(grep -c '^unverified = true$' dowel.build)
"$DOWEL" migrate verify "$PWD/../bd-debug/compile_commands.json" >/dev/null 2>&1
after=$(grep -c '^unverified = true$' dowel.build)
_last_cmd="dowel migrate verify   # 通ったあと"; OUT="$before -> $after"; RC=0
[ "$after" -eq "$before" ]
fact $? "a clean verify does not clear the mark, that claim being the user's to make"

# 人が消せば消える。そして黙る。
sed -i '0,/^unverified = true$/{/^unverified = true$/d}' dowel.build
left2=$("$DOWEL" migrate verify "$PWD/../bd-debug/compile_commands.json" --format=json 2>/dev/null |
        jq -r '.unverified | length')
_last_cmd="dowel migrate verify --format=json   # 印を1つ消した"
OUT="$left2 target(s) still marked"; RC=0
[ "$left2" -eq 2 ]
fact $? "removing a line by hand is what moves the count"

# 手で書いても構わない。古いビルドを読んで手で起こした目標は、
# 下書きと同じ立場に在る。
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t + '\n[lib.byhand]\nsources = [file("src/greet.c")]\nunverified = true\n')
PY
diag unverified-import "a mark written by hand is reported the same way" check
PY_LEFT=$("$DOWEL" migrate verify "$PWD/../bd-debug/compile_commands.json" --format=json 2>/dev/null |
          jq -r '.unverified | length')
_last_cmd="dowel migrate verify --format=json   # 手で書いた印を足した"
OUT="$PY_LEFT target(s) still marked"; RC=0
[ "$PY_LEFT" -eq 3 ]
fact $? "and counted the same way, dowel not distinguishing who wrote it"

cd ..
