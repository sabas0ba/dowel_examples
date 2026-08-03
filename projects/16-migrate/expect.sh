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

# ------------------------------------------------------------ 道具立て

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
    OUT=$("$DOWEL" migrate verify "$1" --format=json 2>&1)
    RC=$?
    SAID=$OUT
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
# 実行ごとに検査名が変わり、文書からも掲示からも同じ行を指せなくなる
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

# dowel は今のところ静的な書庫しか作らない。同じ [lib.*] へ写しておきながら
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

# リンクの側。同じ集合が link_flags には残っている（F-021）。下書きの
# 見出しは「写していない」と述べているため、中身と食い違っている。
known_issue F-021
absent 'NDEBUG' from-release/dowel.build \
    "the draft carries no NDEBUG from a release CMake build type"

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
