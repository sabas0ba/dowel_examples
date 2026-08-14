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

# --------------------------------------------------------------- 5. 綴りの境目
#
# `.asm` は MASM と NASM の綴りであり、C の駆動器は受け付けない。
# 決定は「アセンブリとして認識しない」である。

cp src/masm.asm.keep src/masm.asm
python3 - <<'PY'
p="dowel.build"
t=open(p).read().replace('file("src/pre.S")', 'file("src/pre.S"), file("src/masm.asm")')
open(p,"w").write(t)
PY

# 認識されない綴りは C の駆動器へ行く。`cc -c` はそれを結合器への入力と
# みなし、警告を出して終了状態 0 で返り、目的ファイルを書かない。
# dowel は書かれない出力を宣言したまま先へ進み、結合が path で落ちる
# （[F-063](../../docs/10-findings.md#f-063)）。
rm -rf .dowel
fails "a source the C driver cannot compile fails the build" build --no-compdb

known_issue F-063
diag_where compile-produced-nothing '.message' \
    "and says which source produced no object" build --no-compdb

# 計画の段では何も言わない。`check` は翻訳器の存在も依存の解決も見るが、
# 「この綴りは組めない」は見ない。
known_issue F-063
fails "check refuses a source the C driver cannot compile" check

# 収束もしない。出力の現れないアクションは常に古いままであり、
# 直さない限り毎回同じものを組み直す。
run build --no-compdb --backend=ninja
n1=$(run build --no-compdb --backend=ninja; printf '%s' "$OUT" | grep -c 'CC \|AS ')
_last_cmd="dowel build (twice, nothing changed)"; OUT="recompiled $n1 sources"; RC=0
known_issue F-063
[ "$n1" -eq 0 ]
fact $? "a build that failed this way still converges"

rm -f src/masm.asm
python3 - <<'PY'
p="dowel.build"
t=open(p).read().replace(', file("src/masm.asm")', '')
open(p,"w").write(t)
PY
rm -rf .dowel compile_commands.json
