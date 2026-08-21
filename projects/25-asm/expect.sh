# 25-asm — アセンブリを第3の言語として扱う（ADR-0048）
#
# 拡張子で言語を選ぶ規則は「C++ の綴りなら C++、それ以外は C」だった。
# 手書きのアセンブリは `cc` に渡せば実際に組み上がるので、既に動いている
# ように見えていた。出てきたものを measure すると3つ違っていた——C の標準と
# C の旗が渡り、`.note.GNU-stack` が付かず、書かれない依存ファイルを
# 宣言していた。
#
# どれも「利用者の代わりにビルドシステムが正しくやる」種類のものである。
# だから検査も、宣言ではなく**出てきた引数**と**出てきた成果物**を見る。

# bdir — ビルドディレクトリ。構成ごとに分かれるため、名前は決め打ちにしない。
bdir() { find .dowel/build -mindepth 1 -maxdepth 1 -type d | head -1; }

# --------------------------------------------------------------- 1. 組めて、動く

ok "a target mixing C and assembly builds" build --no-compdb
prints "7 11" "and the program it produced runs" "$(bdir)/bin/app"

# 進行の行が `AS` と言う。`CC` と出ていると、隣に並んだ C の旗が
# もっともらしく見えてしまう——それが3つの取り違えを見過ごさせていた。
rm -rf .dowel
run build --no-compdb --backend=ninja
said=$OUT
printf '%s' "$said" | grep -q 'AS .*plain\.s'
fact $? "the progress line for assembly says AS"
printf '%s' "$said" | grep -q 'CC .*main\.c'
fact $? "and the one for C still says CC"

# 同じことがアクショングラフの記述にも出る。背骨を問わずここを読めば分かる。
_last_cmd="graph --kind=action | descriptions"
OUT=$("$DOWEL" graph --kind=action --format=json 2>/dev/null | jq -r '.steps[].description'); RC=0
printf '%s' "$OUT" | grep -q '^AS .*plain\.s'
fact $? "the action graph describes it as an assembly step"

# --------------------------------------------------------------- 2. 言語ごとの旗の行き先
#
# `flags` は言語に依らないもの。`c_flags` / `asm_flags` はそれぞれの言語の
# ものである。C の標準をアセンブラに渡すのは、C ではないファイルに C の
# 方言を告げることであり、gcc が黙って受けるので誰も気づかない。

asm_args=$(cc_args asmx:app | grep 'plain\.s')
c_args=$(cc_args asmx:app | grep 'main\.c')
pre_args=$(cc_args asmx:app | grep 'pre\.S')

_last_cmd="graph --kind=action | the plain.s action"; OUT=$asm_args; RC=0
printf '%s' "$asm_args" | grep -q '\-DBOTH=1'
fact $? "a language-independent flag reaches assembly"
_last_cmd="graph --kind=action | the plain.s action"; OUT=$asm_args; RC=0
! printf '%s' "$asm_args" | grep -q '\-std='
fact $? "a C standard does not reach assembly"
_last_cmd="graph --kind=action | the plain.s action"; OUT=$asm_args; RC=0
! printf '%s' "$asm_args" | grep -q '\-DONLY_C=1'
fact $? "a C-only flag does not reach assembly"
_last_cmd="graph --kind=action | the plain.s action"; OUT=$asm_args; RC=0
printf '%s' "$asm_args" | grep -q '\-DONLY_ASM=1'
fact $? "an assembly-only flag reaches assembly"

_last_cmd="graph --kind=action | the main.c action"; OUT=$c_args; RC=0
! printf '%s' "$c_args" | grep -q '\-DONLY_ASM=1'
fact $? "an assembly-only flag does not reach C"
_last_cmd="graph --kind=action | the main.c action"; OUT=$c_args; RC=0
printf '%s' "$c_args" | grep -q '\-std=c17' && printf '%s' "$c_args" | grep -q '\-DONLY_C=1'
fact $? "C still gets its own standard and flags"

# 前処理を通る側も、言語としてはアセンブリである。
_last_cmd="graph --kind=action | the pre.S action"; OUT=$pre_args; RC=0
printf '%s' "$pre_args" | grep -q '\-DONLY_ASM=1' && ! printf '%s' "$pre_args" | grep -q '\-std='
fact $? "a preprocessed assembly source is assembly too"

# --------------------------------------------------------------- 3. dowel が自分で足すもの
#
# `-Wa,--noexecstack` は共有ライブラリの `-fPIC` と同じ種類の引数である。
# 出てくるものの正しさがそれに依り、他に足す者がいない。

_last_cmd="graph --kind=action | the plain.s action"; OUT=$asm_args; RC=0
printf '%s' "$asm_args" | grep -q '\-Wa,--noexecstack'
fact $? "dowel adds the flag that marks the stack non-executable"

# 宣言を見るだけでは足りない。出てきた実行ファイルの側で、
# 実行可能スタックを要求していないことを読む。C の翻訳器は自分の出力に
# 印を付けるが、手書きのアセンブリには誰も付けない。
_last_cmd="readelf -lW bin/app | GNU_STACK"
OUT=$(readelf -lW "$(bdir)/bin/app" 2>&1 | grep GNU_STACK); RC=0
printf '%s' "$OUT" | grep -qE 'RW[^E]*$'
fact $? "the executable it produced does not ask for an executable stack"

# 利用者が明示すれば覆せる。dowel の足す引数は先に来る。
_last_cmd="graph --kind=action | the plain.s action"; OUT=$asm_args; RC=0
pos_dowel=$(printf '%s' "$asm_args" | grep -bo '\-Wa,--noexecstack' | head -1 | cut -d: -f1)
pos_user=$(printf '%s' "$asm_args" | grep -bo '\-DONLY_ASM=1' | head -1 | cut -d: -f1)
[ -n "$pos_dowel" ] && [ -n "$pos_user" ] && [ "$pos_dowel" -lt "$pos_user" ]
fact $? "what dowel adds comes before what the target declares, so the target can override it"

# --------------------------------------------------------------- 4. 依存ファイル
#
# 書かれない依存ファイルを宣言することは、現れない出力を宣言することで
# あり、増分ビルドが収束しなくなる形である。`.S` は前処理を通るので
# 見出しの依存を持ち、`.s` は持たない。

_last_cmd="graph --kind=action | the pre.S action"; OUT=$pre_args; RC=0
printf '%s' "$pre_args" | grep -q '\-MD'
fact $? "a preprocessed assembly source asks for a depfile"
_last_cmd="graph --kind=action | the plain.s action"; OUT=$asm_args; RC=0
! printf '%s' "$asm_args" | grep -q '\-MD'
fact $? "a plain assembly source does not, because none would be written"

# 宣言が在るだけでは、依存が辿られていることにならない。取り込んだ見出しを
# 書き換えて、組み直されることを見る。
build_direct --no-compdb
sed -i 's/11/13/' include/value.h
build_direct --no-compdb
rebuilt "pre.S" "editing a header a preprocessed assembly source includes rebuilds it"
prints "7 13" "and the change reaches the program" "$(bdir)/bin/app"
sed -i 's/13/11/' include/value.h
build_direct --no-compdb

# 収束すること。3つの背骨すべてで見る——「依存ファイルは無い」の綴りは
# 背骨ごとに違い、ninja では変数を束ねないと自分自身に解決して循環になる。
for backend in direct ninja make; do
    rm -rf .dowel
    run build --no-compdb --backend="$backend"
    build_direct --no-compdb
    not_rebuilt "plain.s" "the $backend backend leaves nothing to redo on the next build"
done

# --------------------------------------------------------------- 5. 綴りは閉じている（ADR-0051）
#
# 言語は拡張子で決まり、**それ以外は C** という落とし前が付いていた。それは
# 未知の綴りについての判断ではなく、`.c` についての判断を、全部を飲み込む
# 書き方でしたものだった。
#
# 何を払っていたかは C の駆動器を測ると出る——警告つきの成功、終了状態 0、
# 目的ファイル無し。失敗は1段あとに、結合器の言葉で、ビルドディレクトリの
# 中の道について返ってくる。ソースの名前も行も診断コードも無い
# （[F-063](../../docs/10-findings.md#f-063)）。

cp dowel.build dowel.build.keep
cp dowel.toml  dowel.toml.keep

# add_source <綴り> — その名前のソースを1つ足す。
add_source() {
    python3 - "$1" <<'PY'
import sys
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t.replace('file("src/pre.S")',
                             'file("src/pre.S"), file("src/%s")' % sys.argv[1]))
PY
}

cp src/plain.s src/note.txt
add_source note.txt

rm -rf .dowel
diag unknown-source-language "a spelling dowel cannot compile is refused" check
fails "and check does not pass a tree that holds one" check

# 位置は**ソースを宣言したところ**である。結合まで持ち越すと、返ってくる
# のは目的ファイルの道であり、そこから元のファイルは逆算できない。
diag_where unknown-source-language '.labels[0].line' \
    "with the position where it was declared as a source" check
out_has "note.txt" "naming the file, not an object inside the build directory" check

# 何なら書けるのかを言う。閉じた集合であることは、一覧が出て初めて
# 利用者の側で使える情報になる。
out_has "sources are C" "and listing the languages it does compile" check

# なぜそうなるのかも言う。`cc` が黙って受けることが、この落とし前が
# 気づかれなかった理由そのものである。
out_has "writes no object" \
    "and saying what the C driver would have done with it" check

cp dowel.build.keep dowel.build
rm -f src/note.txt

# 拡張子の無いソースも同じである。以前は C として組まれていたが、
# `note.txt` も受ける落とし前の下では、その2つを区別する手立てが無かった。
cp src/main.c src/bare
add_source bare
diag unknown-source-language "a source with no extension is refused too" check
cp dowel.build.keep dowel.build
rm -f src/bare

# 前処理を通した C は受ける。駆動器が受け、`.c` の隣に置かれうる形である。
cp src/main.c src/pre.i
add_source pre.i
ok "a preprocessed C source is accepted, being C the driver takes" check
cp dowel.build.keep dowel.build
rm -f src/pre.i

# --------------------------------------------------------------- 6. 出したはずのものが無い実行は失敗（ADR-0051）
#
# 拡張子の検査は、マニフェストから見えるものしか覆えない。宣言された道具が
# 黙って何もしない場合には別の網が要る。網は2つ在り、dowel が実際に見て
# いる2つの層に置かれている。

mkdir -p tools
cat > tools/silent.sh <<'EOF'
#!/bin/sh
# 何も書かずに成功する道具。ADR-0051 が名指している形そのものである。
echo "silent: pretending to work" >&2
exit 0
EOF
chmod +x tools/silent.sh

printf '\n[bin.app.artifacts]\nghost = { tool = "objcopy", args = ["-O", "binary"] }\n' >> dowel.build
printf '\n[toolchain]\nobjcopy = "%s/tools/silent.sh"\n' "$PWD" >> dowel.toml

# direct は段ごとに出力を見る。成功した命令とその stderr まで出せるのは
# こちらだけである——道具が自分について何か言っていれば、そこに在る。
rm -rf .dowel
run build --no-compdb --backend=direct
said=$OUT; rc=$RC
[ "$rc" -ne 0 ]
_verdict $? "the direct backend fails when a tool writes nothing it was asked for"
printf '%s' "$said" | grep -q 'without writing'
fact $? "and says that the command exited 0 without writing its output"
printf '%s' "$said" | grep -q 'silent: pretending'
fact $? "showing the tool's own words, which usually explain it"

# ninja と make はどちらも出力が無いことでは落ちない。だから網はビルドの
# あとに置かれている——`built:` として刷る先が在るかどうかを見る。
for backend in ninja make; do
    rm -rf .dowel
    run build --no-compdb --backend="$backend"
    said=$OUT; rc=$RC
    [ "$rc" -ne 0 ]
    _verdict $? "the $backend backend fails there too, the net being after the build"
    printf '%s' "$said" | grep -q 'did not produce'
    fact $? "and the $backend failure names the artifact that never appeared"
done

cp dowel.build.keep dowel.build
cp dowel.toml.keep  dowel.toml
rm -rf tools .dowel

# 対照。書く道具なら通る。上の失敗が「道具を宣言すると落ちる」では
# ないことは、これが無いと言えない。
ok "a tool that does write its output still succeeds" build --no-compdb

rm -f dowel.build.keep dowel.toml.keep
rm -rf .dowel compile_commands.json

# --------------------------------------------------------------- 7. 自前の assembler（ADR-0050）
#
# ADR-0048 が開けたまま残したもの——「別の assembler を選ぶ手立てが無い。
# `[toolchain] c` が組み立てるので、`nasm` が要るプロジェクトはそう言えない」。
#
# 要るのは dowel の相手そのものである。暗号や符号のライブラリは x86 向けに
# NASM のソースを配る——OpenSSL も BoringSSL も、生成器が Unix の三つ組へは
# gas を、Windows へは NASM を吐く。Windows の側は C の駆動器が聞いたことも
# ない道具を要る。
#
# `.asm` を認識しないという判断は、道具が固定である間だけ正しかった。
# 名指せるなら `.asm` は「assembler が宣言されたアセンブリ」であり、
# 宣言が無ければ dowel は何が足りないかを正確に言える。

NASMD=$PWD/nasm
bdir_at() { find "$1/.dowel/build" -mindepth 1 -maxdepth 1 -type d | head -1; }

if ! command -v nasm >/dev/null 2>&1; then
    fact 1 "nasm is available, this section needing a second assembler"
else

ok "a package that declares its own assembler builds" -C nasm build --no-compdb
prints "5" "and the program it produced runs" "$(bdir_at "$NASMD")/bin/app"

asm_step=$("$DOWEL" -C nasm graph --kind=action --format=json 2>/dev/null |
           jq -r '.steps[] | select(.description | test("five\\.asm")) |
                  "\(.description) || \(.program) \(.arguments | join(" "))"')
_last_cmd="graph --kind=action | the five.asm step"; OUT=$asm_step; RC=0
said=$asm_step

printf '%s' "$said" | grep -q ' nasm '
fact $? "the declared assembler is what assembles, not the C driver"

# dowel が渡すのは入力と出力と `asm_flags` だけである。翻訳の行の残りは
# C の駆動器のために綴られたものであり、assembler はそれではない。
_last_cmd="graph --kind=action | the five.asm step"; OUT=$said; RC=0
printf '%s' "$said" | grep -q '\-f elf64'
fact $? "and asm_flags reach it, being where what it needs is written"
_last_cmd="graph --kind=action | the five.asm step"; OUT=$said; RC=0
! printf '%s' "$said" | grep -q '\-g \|\-O0'
fact $? "while the C driver's own flags do not"
_last_cmd="graph --kind=action | the five.asm step"; OUT=$said; RC=0
! printf '%s' "$said" | grep -q 'NOT_FOR_THE_ASSEMBLER'
fact $? "and neither does what the target declared for every language"

# `asm_flags` は List<Word> なので、道をそのまま書ける。文字列の連結が
# 無い以上、これが無ければ木の中のディレクトリを指せない。
_last_cmd="graph --kind=action | the five.asm step"; OUT=$said; RC=0
printf '%s' "$said" | grep -q "\-I $NASMD/src"
fact $? "a path written in asm_flags arrives as a path, there being no concatenation"

# 依存ファイルは要求しない。書かれないものを宣言するのは、ADR-0048 が
# `.s` について断ったのと同じ形である。
_last_cmd="graph --kind=action | the five.asm step"; OUT=$said; RC=0
! printf '%s' "$said" | grep -q '\-MD\|\-MF'
fact $? "no depfile is asked for, its spelling being that assembler's and not the tool slot's"

# 実行可能スタックの主張は、最後に dowel が言える場所へ移る。
# `-Wa,--noexecstack` は C の駆動器の綴りであり、宣言された assembler には
# 渡せない。結合器の綴りなら dowel は知っている。
link_step=$("$DOWEL" -C nasm graph --kind=action --format=json 2>/dev/null |
            jq -r '.steps[] | select(.kind == "link") | (.arguments | join(" "))')
_last_cmd="graph --kind=action | the link step"; OUT=$link_step; RC=0
printf '%s' "$link_step" | grep -q '\-z noexecstack'
fact $? "the link carries the claim about the stack instead"

_last_cmd="readelf -lW nasm bin/app | GNU_STACK"
OUT=$(readelf -lW "$(bdir_at "$NASMD")/bin/app" 2>&1 | grep GNU_STACK); RC=0
printf '%s' "$OUT" | grep -qE 'RW[^E]*$'
fact $? "and the executable that came out does not ask for an executable stack"

fi

# 宣言が無ければ `.asm` は組めない。C の駆動器へ渡すと、2段あとに
# 「file format not recognized」が結合器から返る——駆動器が黙って
# 通した相手について。
cp dowel.build dowel.build.keep
cp nasm/src/five.asm src/five.asm
python3 - <<'PY'
p = "dowel.build"
t = open(p).read()
open(p, "w").write(t.replace('file("src/pre.S")', 'file("src/pre.S"), file("src/five.asm")'))
PY
diag missing-assembler "a .asm source with no assembler declared is refused" check
out_has "five.asm" "naming the file that needs one" check
out_has "MASM or NASM" "and saying what that spelling is" check
out_has 'asm = ' "and how to declare one" check

# 位置は隣の診断と揃っていない。文言は「ここでソースが宣言されている」と
# 言うのに、下線が付くのは `[bin.app]` の行である。目標が大きいほど、
# どのソースなのかは本文の文字列から探すことになる
# （[F-067](../../docs/10-findings.md#f-067)）。
srcline=$("$DOWEL" check --message-format=json 2>/dev/null |
          jq -r 'select(.code == "missing-assembler") | .labels[0].line')
declline=$(grep -n 'five\.asm' dowel.build | head -1 | cut -d: -f1)
_last_cmd="dowel check --message-format=json | .labels[0].line"
OUT="the label points at line ${srcline:-?}; the source is declared on line ${declline:-?}"
RC=0
known_issue F-067
[ "$srcline" = "$declline" ]
fact $? "and points at the source, as its sibling diagnostic does"
cp dowel.build.keep dowel.build
rm -f src/five.asm dowel.build.keep
rm -rf .dowel compile_commands.json nasm/.dowel nasm/compile_commands.json
