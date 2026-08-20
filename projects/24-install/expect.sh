# 24-install — 組んだものを prefix の下へ出す（ADR-0041 / ADR-0043）
#
# ここまでの決定は全て1つのビルド木の中の話だった。共有ライブラリを宣言し
# （ADR-0038）、面を宣言して確かめ（ADR-0039）、世代を付けられる（ADR-0040）
# ——それらを置く先が無かった。`dowel install --prefix=<dir>` がその先である。
#
# 見るべきものは2つある。
#
#   1. 出した先で動くこと。共有ライブラリを繋いだ成果物は、ビルド木への
#      絶対パスを記録する。写しただけでは、木が在る間だけ動き、受け取った
#      側が壊れに気づく。自分からの相対で探すのが決定である。
#
#   2. 出した先が見つかること。置いただけでは誰にも引けない。dowel は
#      pkg-config を読む側でありながら書けなかった。段階的な移行という
#      前提が崩れるのはここだった（ADR-0043）。
#
# 2 は「dowel を知らない使う側が、dowel 無しで繋げること」でしか確かめられ
# ない。記述子の中身を読むだけでは足りない——読める記述子と、通る記述子は
# 別である。

LIB=$PWD/lib
APP=$PWD/app
CONS=$PWD/consumer
PFX=$PWD/prefix
STG=$PWD/staged

# pc <モジュール> <引数...> — 出した記述子だけを見て pkg-config を引く。
# 検索路をこの prefix に限る。機械に入っている同名のものを引いてしまうと、
# 何を確かめたのか分からなくなる。
pc() { PKG_CONFIG_PATH="$1/lib/pkgconfig" PKG_CONFIG_LIBDIR="$1/lib/pkgconfig" \
       pkg-config "${@:2}" 2>&1; }

# --------------------------------------------------------------- 1. 何が出るか

rm -rf "$PFX"
ok "installing a library succeeds" -C "$LIB" install --prefix="$PFX"

for f in lib/libshapes.so.2 lib/libshapes.so lib/librender.a \
         include/shapes.h include/render.h \
         lib/pkgconfig/shapes.pc lib/pkgconfig/render.pc; do
    if [ -e "$PFX/$f" ]; then fact 0 "installing a library writes $f"
    else                      fact 1 "installing a library writes $f"; fi
done

# 世代付きの実体には、世代なしの別名が付く（ADR-0040）。`-lshapes` が
# 引き当てるのはこちらであり、無ければ記述子の `Libs` は書庫を指す。
if [ -L "$PFX/lib/libshapes.so" ]; then
    fact 0 "the unversioned name of a versioned library is a symlink"
else
    fact 1 "the unversioned name of a versioned library is a symlink"
fi

# 出るのは公表したディレクトリの中身だけである。`public.includes` は
# 「使う側はこのディレクトリに対して翻訳する」という宣言そのものであり、
# 推測ではない。翻訳単位はそこに置かれていないので出ない。
if [ -e "$PFX/include/shapes.h" ] && [ ! -e "$PFX/include/render.c" ]; then
    fact 0 "what is installed is the published directory, not the sources beside it"
else
    fact 1 "what is installed is the published directory, not the sources beside it"
fi

# 組み直さない。試したものと配るものが同じバイト列であることが、
# 試した意味を支えている。
B=$LIB/.dowel/build/*/lib/libshapes.so.2
if cmp -s $B "$PFX/lib/libshapes.so.2"; then
    fact 0 "what is installed is the same bytes that were built"
else
    fact 1 "what is installed is the same bytes that were built"
fi

# 行き先が既定を持たない。`/usr/local` は root を要り、書ける既定は誰も
# 望まない場所になる。憶測で書くより、1つ覚える方が安い。
fails "installing without a destination is refused" -C "$LIB" install
out_has "--prefix" "refusing it names the option that is missing" \
        -C "$LIB" install

# --------------------------------------------------------------- 2. 何が出ないか
#
# `test` と `bench` は、物を確かめる道具であって物ではない。

rm -rf "$PFX"
ok "installing a package with a test target succeeds" -C "$APP" install --prefix="$PFX"
if [ -e "$PFX/bin/app" ]; then fact 0 "a bin target is installed"
else                           fact 1 "a bin target is installed"; fi
if [ -e "$PFX/bin/smoke" ]; then fact 1 "a test target is not installed"
else                             fact 0 "a test target is not installed"; fi

# 実行できるものが要るのは、繋いだ共有ライブラリである。別のパッケージの
# ものでも写す——ADR-0038 の境界を跨ぐが、越えなければ動かない物が出る。
if [ -e "$PFX/lib/libshapes.so.2" ]; then
    fact 0 "a shared library the executable needs is installed with it"
else
    fact 1 "a shared library the executable needs is installed with it"
fi

# 使う側のパッケージからは、依存の見出しは出ない。実行ファイルを配るのに
# 相手の見出しは要らない。
if [ -e "$PFX/include/shapes.h" ]; then
    fact 1 "installing a binary does not bring its dependency's headers"
else
    fact 0 "installing a binary does not bring its dependency's headers"
fi

# 名指しは既定を上書きする。`build` と同じ規則である。
rm -rf "$PFX"
ok "naming a target installs that one" -C "$APP" install app --prefix="$PFX"
if [ -e "$PFX/bin/app" ]; then fact 0 "the named target is installed"
else                           fact 1 "the named target is installed"; fi

# --------------------------------------------------------------- 3. 自分からの相対で探す
#
# ここが ADR-0041 の要である。写しただけの実行ファイルはビルド木を指し、
# 木が在る間は動く。壊れるのは受け取った側の機械で、作った側では再現しない。

rm -rf "$PFX"
run -C "$APP" install --prefix="$PFX"

_last_cmd="readelf -d $PFX/bin/app"
OUT=$(readelf -d "$PFX/bin/app" 2>&1); RC=0
said=$OUT
printf '%s' "$said" | grep -q 'ORIGIN/../lib'
fact $? "an installed executable records a search path relative to itself"

# ビルド木への絶対パスは残る。この変更は足すものであって、木の中の
# 振る舞いを変えない。
printf '%s' "$said" | grep -qF "$APP/.dowel"
fact $? "the build tree path stays alongside it"

# 動かして確かめる。木を消し、prefix ごと別の場所へ移す。記録が絶対パス
# だけなら、ここで loader が libshapes を見つけられない。
MOVED=$PWD/moved
rm -rf "$MOVED"
cp -a "$PFX" "$MOVED"
rm -rf "$APP/.dowel"
prints "3.1416" "the installed tree runs after it is moved and the build tree is gone" \
       "$MOVED/bin/app"

# 3つの背骨すべてで同じことが起きること。`$` は ninja にとっても make に
# とっても、make の行を走らせる shell にとっても意味を持つ記号である。
# 引用を1つ落とすと、実行ファイルは繋がり、木の中では動き、移した後にだけ
# 壊れる——最も見つけにくい形になる。
for backend in direct ninja make; do
    rm -rf "$APP/.dowel" "$PFX"
    run -C "$APP" install --prefix="$PFX" --backend="$backend" --no-compdb
    _last_cmd="dowel -C app install --backend=$backend; readelf -d prefix/bin/app"
    OUT=$(readelf -d "$PFX/bin/app" 2>&1); RC=0
    printf '%s' "$OUT" | grep -q 'ORIGIN/../lib'
    fact $? "the $backend backend records the relative search path unmangled"
done

# --------------------------------------------------------------- 4. staging
#
# packager が要るのはこちらである。`--destdir` は行き先だけを前へずらし、
# 記述子の中身は本来の prefix を述べ続ける。

rm -rf "$STG"
ok "installing into a staging directory succeeds" \
   -C "$LIB" install --prefix=/opt/shapes --destdir="$STG"
if [ -e "$STG/opt/shapes/lib/libshapes.so.2" ]; then
    fact 0 "--destdir prepends a staging root to every destination"
else
    fact 1 "--destdir prepends a staging root to every destination"
fi
grep -q '^prefix=/opt/shapes$' "$STG/opt/shapes/lib/pkgconfig/shapes.pc"
fact $? "the descriptor names the real prefix, not the staging directory"

# 記録した探索路は相対であるため、staging した木と本来の木は同じに振る舞う。
# 見るのは実行ファイルの側である——共有ライブラリを繋いだ成果物だけが
# 探索路を記録する。何も繋いでいないライブラリには記録するものが無い。
rm -rf "$STG"
run -C "$APP" install --prefix=/opt/app --destdir="$STG"
_last_cmd="readelf -d $STG/opt/app/bin/app"
OUT=$(readelf -d "$STG/opt/app/bin/app" 2>&1); RC=0
printf '%s' "$OUT" | grep -q 'ORIGIN/../lib'
fact $? "a staged executable carries the same relative search path"

# staging した木をそのまま本来の場所へ展開すれば動く。これが
# 「staged と final が同じに振る舞う」ということである。
UNSTG=$PWD/unstaged
rm -rf "$UNSTG"; cp -a "$STG/opt/app" "$UNSTG"
rm -rf "$APP/.dowel"
prints "3.1416" "a staged tree unpacked somewhere else runs" "$UNSTG/bin/app"

rm -rf "$STG"
run -C "$LIB" install --prefix=/opt/shapes --destdir="$STG"

# 何を書いたかの記録は残らない。空の staging へ出したものが、その一覧である。
n=$(find "$STG" -type f -o -type l | wc -l)
[ "$n" -ge 4 ]
fact $? "installing into an empty staging directory yields the file list"

# --------------------------------------------------------------- 5. 記述子の中身
#
# 新しく宣言するものは無い。記述子は `public` 区画を別の記法で書いたもので
# あり、dowel の使う側と pkg-config の使う側が受け取る面は同じものである。

rm -rf "$PFX"
run -C "$LIB" install --prefix="$PFX"
PC=$PFX/lib/pkgconfig/shapes.pc

_last_cmd="cat $PC"; OUT=$(cat "$PC"); RC=0
said=$OUT

printf '%s' "$said" | grep -q '^Name: shapes$'
fact $? "the descriptor names the target"
printf '%s' "$said" | grep -q '^Version: 1.2.3$'
fact $? "the descriptor carries the package version"
printf '%s' "$said" | grep -q '^Description: areas of simple shapes$'
fact $? "the descriptor carries the declared description"
printf '%s' "$said" | grep -q 'includedir'
fact $? "Cflags points at the installed include directory"
printf '%s' "$said" | grep -q 'SHAPES_SHARED'
fact $? "Cflags carries the defines the library publishes"
printf '%s' "$said" | grep -q '\-lshapes'
fact $? "Libs names the library itself"
printf '%s' "$said" | grep -q '\-lm'
fact $? "Libs carries the link flags the library publishes"

# pkg-config 自身に読ませる。書式として妥当であることは、目で読んでも
# 分からない——変数の展開も必須項目も、あちら側の規則である。
assert "the descriptor validates as pkg-config input" \
       env PKG_CONFIG_PATH="$PFX/lib/pkgconfig" PKG_CONFIG_LIBDIR="$PFX/lib/pkgconfig" \
           pkg-config --validate shapes

# 翻訳の対象になるものだけが記述子を持つ。`bin` は繋ぐ相手ではない。
rm -rf "$PFX"
run -C "$APP" install --prefix="$PFX"
if [ -e "$PFX/lib/pkgconfig/app.pc" ]; then
    fact 1 "a bin target gets no pkg-config descriptor"
else
    fact 0 "a bin target gets no pkg-config descriptor"
fi

# --------------------------------------------------------------- 6. dowel を知らない使う側
#
# ADR-0043 が在る理由そのものである。段階的な移行とは、使う側が CMake でも
# Meson でも Makefile でも構わないということであり、それは記述子1つで繋がる
# ことでしか成り立たない。

rm -rf "$PFX"
run -C "$LIB" install --prefix="$PFX"
CFLAGS_LIBS=$(pc "$PFX" --cflags --libs shapes)

_last_cmd="cc consumer/main.c \$(pkg-config --cflags --libs shapes)"
OUT=$(cc "$CONS/main.c" -o "$PWD/consumer.bin" $CFLAGS_LIBS 2>&1); RC=$?
[ "$RC" -eq 0 ]
fact $? "a consumer that knows nothing about dowel compiles against the installed library"

prints "12.5664" "and the program it produced runs" \
       env LD_LIBRARY_PATH="$PFX/lib" "$PWD/consumer.bin"

# 同じパッケージの、上に乗るライブラリ。こちらは書庫なので、`-lrender`
# だけでは下の実体が引かれない。記述子が下を名指していなければ、使う側の
# 結合は未定義参照で落ちる（[F-062](../../docs/10-findings.md#f-062)）。
#
# 共有ライブラリなら `DT_NEEDED` が隠してしまうため、**静的にしたときに
# だけ**現れる。ここを書庫のままにしてあるのはそのためである。
RENDER_FLAGS=$(pc "$PFX" --cflags --libs render)
_last_cmd="cc consumer/render.c \$(pkg-config --cflags --libs render)"
OUT=$(cc "$CONS/render.c" -o "$PWD/render.bin" $RENDER_FLAGS 2>&1); RC=$?
[ "$RC" -eq 0 ]
fact $? "a consumer links against an installed library that sits on a sibling"

prints "1.0000" "and the program it produced runs" \
       env LD_LIBRARY_PATH="$PFX/lib" "$PWD/render.bin"

# 名指す先は隣に書いた記述子である。「確かに在るものだけを名指す」という
# 規則が満たされるのは、同じ実行で両方を出したこの場合だけである。
_last_cmd="cat $PFX/lib/pkgconfig/render.pc"
OUT=$(cat "$PFX/lib/pkgconfig/render.pc" 2>&1); RC=0
said=$OUT
printf '%s' "$said" | grep -q '^Requires: .*shapes'
fact $? "the descriptor of a library that sits on a sibling names what it requires"

if [ -e "$PFX/lib/pkgconfig/shapes.pc" ]; then
    fact 0 "and what it names was written by the same run, beside it"
else
    fact 1 "and what it names was written by the same run, beside it"
fi

# `Requires` で名指すと、下の `Cflags` も届く。`Libs` に `-lshapes` を
# 足すだけの形では、公開している定義や旗が落ちる。
_last_cmd="pkg-config --cflags render"
OUT=$(pc "$PFX" --cflags render); RC=0
printf '%s' "$OUT" | grep -q 'SHAPES_SHARED'
fact $? "so a define the sibling publishes reaches the consumer too"

rm -rf "$PFX" "$STG" "$MOVED" "$UNSTG" "$PWD/consumer.bin" "$PWD/render.bin" \
       "$LIB/.dowel" "$APP/.dowel" "$LIB/compile_commands.json" "$APP/compile_commands.json"
