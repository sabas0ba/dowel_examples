# 26-prebuilt — 既に在るライブラリを依存として書く（ADR-0049 / ADR-0042）
#
# C や C++ のプログラムは、dowel が組まなかったものを繋ぐことが多い——Rust の
# staticlib、Zig の build-lib、Go の c-archive、vendor の SDK。これまでの綴りは
# 使う側それぞれに書く2つの旗だった。
#
#   link_flags = ["-L", dir("target/release"), "-lengine"]
#
# それは依存ではないので、見出しの経路を伝えず、ABI 札を持たず、
# `dowel why` に現れず、他の全ての検査に参加しない。**ビルドの中心にある
# ファイルが、dowel が意味を解さないまま通す2つの旗で書かれている。**
#
# 記述されているものは目標そのものである。面を持ち、要求を持ち、使う側が
# 依存する。欠けているのはソースだけである。
#
# ここは同時に、ABI 札が初めて**確かめる価値のある辺**を得た場所でもある
# （ADR-0042）。片側が手元で組まれていない場合こそ、札の比較が意味を持つ。

# vendor/ の中身は dowel の外側のビルドである。dowel はこれを走らせない
# （ADR-0001）。走らせてしまうと、汎用のビルドシステムになる。
make -C vendor libengine.a >/dev/null 2>&1

bdir() { find .dowel/build -mindepth 1 -maxdepth 1 -type d | head -1; }

# --------------------------------------------------------------- 1. 普通の目標である

ok "a target that names a prebuilt library builds"  build --no-compdb
prints "6.00" "and the program it produced runs" "$(bdir)/bin/app"

# 繋がったこと自体は、旗を2つ書いても起きる。目標であることの中身は、
# 面が伝わることの方にある。
_last_cmd="cc_args linkage:app"
OUT=$(cc_args linkage:app); RC=0
printf '%s' "$OUT" | grep -q 'include'
fact $? "a consumer of a prebuilt library compiles against its published headers"

# 何も組まない。翻訳も書庫化も起きず、使う側の翻訳だけが走る。
build_direct --no-compdb
rm -rf .dowel
build_direct --no-compdb
not_rebuilt "engine" "building a prebuilt library runs no compile and no archive of its own"
rebuilt "main.c" "while its consumer is compiled as usual"

# `dowel why` が辿れること。2つの旗だった頃はここに現れなかった。
out_has "engine" "why traces a value back to the prebuilt target" \
        why app link_flags
out_has "-lm" "and the link flags it publishes arrive with it" \
        why app link_flags

# --------------------------------------------------------------- 2. 無ければ計画の段で言う
#
# 結合に任せると、翻訳器の言葉で1段遅れて返る（issue #50 と同じ論法）。

mv vendor/libengine.a vendor/libengine.a.keep
fails "a prebuilt library that is not there fails" check
diag missing-prebuilt "and says so with its own code" check
diag_where missing-prebuilt '.labels[0].line' "with the position of the declaration" check
out_has "vendor/libengine.a" "naming the path it looked for" check

# 誰が作るはずだったのかまで言う。dowel が走らせない以上、次の一手は
# 利用者の側にある。
out_has "does not run the build that produces it" \
        "and saying that dowel does not produce it" check
mv vendor/libengine.a.keep vendor/libengine.a

# 中身が変われば繋ぎ直す。他のあらゆる入力と同じく、同一性で見る。
build_direct --no-compdb
touch vendor/engine.c
make -C vendor libengine.a >/dev/null 2>&1
build_direct --no-compdb
rebuilt "bin/app" "replacing the prebuilt library relinks its consumer"

# --------------------------------------------------------------- 3. 書けないもの
#
# ここで組むのか、他所で組まれたのか。両方は答えが無い。

cp dowel.build dowel.build.keep

python3 - <<'PY'
p="dowel.build"
t=open(p).read().replace('prebuilt = file("vendor/libengine.a")',
                         'prebuilt = file("vendor/libengine.a")\nsources  = [file("src/main.c")]')
open(p,"w").write(t)
PY
diag prebuilt-with-sources "declaring both sources and prebuilt is refused" check
out_has "not both" "and says a target is built here or was built elsewhere" check
cp dowel.build.keep dowel.build

# 繋ぐ相手であって、走らせる物ではない。
printf '\n[bin.blob]\nprebuilt = file("vendor/libengine.a")\n' >> dowel.build
diag prebuilt-not-a-library "a bin that names a prebuilt library is refused" check
out_has "library to link against" "and says what a prebuilt is for" check
cp dowel.build.keep dowel.build

# --------------------------------------------------------------- 4. ABI 札の辺
#
# 「1つのビルドの中では道具立ても構成も一様である」（ADR-0031）ため、
# **手元で組んだもの同士**の札はいつも一致し、比較は空虚だった。片側が
# 他所で組まれている場合に初めて、札が食い違いうる。

python3 - <<'PY'
p="dowel.build"
t = open(p).read()
open(p, "w").write(t.replace('{ libc = "gnu" }', '{ libc = "musl" }'))
PY
fails "a prebuilt library requiring another libc than the build is refused" check
diag abi-mismatch "with the code the label system already had" check
out_has "musl" "naming what the surface requires" check
out_has "x86_64-unknown-linux-gnu" "and the triple the build actually is" check

# 何が起きるはずだったのかも言う。結合は通ってしまい、壊れるのは実行時で
# ある——だから計画の段で止める価値がある。
out_has "the link succeeds" "and says why nothing later would catch it" check

# 同じ診断が、札を受け取る目標の数だけ出る。文面には目標の名前が入って
# いないため、読む側には同じ誤りの写しに見える
# （[F-064](../../docs/10-findings.md#f-064)）。
n=$("$DOWEL" check --message-format=json 2>/dev/null | jq -r 'select(.code=="abi-mismatch")|.code' | grep -c .)
_last_cmd="dowel check --message-format=json | abi-mismatch"
OUT="emitted $n times for one declaration"; RC=0
known_issue F-064
[ "$n" -eq 1 ]
fact $? "one wrong declaration produces one diagnostic"
cp dowel.build.keep dowel.build

# 対照。ビルドと合っていれば通る。上の拒否が「札を書くと落ちる」ではなく
# 「合っていないと落ちる」であることは、これが無いと言えない。
ok "a prebuilt library requiring the libc the build has passes" check

# 相手が名指さない成分は制約ではない。知らない側が黙っていられることが、
# 粒度を選ばずに済ませる仕掛けである。
python3 - <<'PY'
p="dowel.build"
t = open(p).read()
open(p, "w").write(t.replace('{ libc = "gnu" }', '{ libc = "gnu", cxx_stdlib = "libstdc++" }'))
PY
ok "a surface may say more than the other side without blocking it" check
out_has "cxx_stdlib" "and the merged label is the union of what was said" \
        why app abi
out_has "libc" "keeping what the other side said too" why app abi
cp dowel.build.keep dowel.build

rm -f dowel.build.keep vendor/libengine.a vendor/engine.o
rm -rf .dowel compile_commands.json
