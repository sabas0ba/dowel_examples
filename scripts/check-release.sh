#!/usr/bin/env bash
#
# 公開された release を、利用者と同じ経路で確かめる。
#
#   ./scripts/check-release.sh 0.1.0
#
# `run.sh` の外に置いてある。本スイートは「環境によって走る検査が変わると、
# 結果を過去の実行と比べられなくなる」という規則で動いており、上流の release
# に触れる検査はその規則と両立しない——本リポジトリを何も変えていないのに、
# 上流の資産が差し替われば結果が動く。
#
# それでも要るのは、**確かめられるのがここだけ**だからである。手元の mirror
# に対する `projects/09-acquisition` は取得の規則を固定するが、公開された
# バイト列が本当にその形で置かれているかは言えない。release は人が作る
# 手順の産物であり、壊れ方も人の手順の壊れ方をする——資産が1つ欠ける、
# digest を貼り忘れる、書庫の中身が変わる。
#
# 見るのは「新しい利用者が最初にすること」である。

set -uo pipefail

VERSION=${1:-}
UPSTREAM=${DOWEL_UPSTREAM:-https://github.com/sabas0ba/dowel}

if [ -z "$VERSION" ]; then
    printf 'usage: %s <version>   # e.g. 0.1.0\n' "$0" >&2
    exit 2
fi
TAG=v$VERSION

# 公開すると宣言されている三つ組（release の本文）。1つでも欠ければ、
# その機械の利用者は「配られている」という記述に裏切られる。
TRIPLES="
x86_64-unknown-linux-gnu
aarch64-unknown-linux-gnu
x86_64-apple-darwin
aarch64-apple-darwin
x86_64-pc-windows-msvc
"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
c_pass=$'\033[32m'; c_fail=$'\033[31m'; c_off=$'\033[0m'
[ -t 1 ] || { c_pass=""; c_fail=""; c_off=""; }

# ok <good> <desc> [材料...]
ok() {
    local good=$1 desc=$2; shift 2
    if [ "$good" -eq 0 ]; then
        pass=$((pass + 1)); printf '  %sok%s   %s\n' "$c_pass" "$c_off" "$desc"
    else
        fail=$((fail + 1)); printf '  %sFAIL%s %s\n' "$c_fail" "$c_off" "$desc"
        local line
        for line in "$@"; do printf '       %s\n' "$line"; done
    fi
}

asset_url() { printf '%s/releases/download/%s/dowel-%s-%s.tar.gz' "$UPSTREAM" "$TAG" "$TAG" "$1"; }

printf 'checking the published release %s at %s\n\n' "$TAG" "$UPSTREAM"

# ---------------------------------------------------------------- 1. 置かれているもの
#
# 配ると書いた三つ組それぞれに、書庫と digest が在ること。取れるかどうかは
# 頭だけ問い合わせれば分かる——数百 MB を5つ落とす必要は無い。

# 1バイトだけ求める。HEAD は release の配布経路（署名付きの転送先へ跳ぶ）で
# 通らないことがあり、「置かれているか」の答としては当てにならない。
reachable() { curl -fsSL -r 0-0 "$1" -o /dev/null 2>/dev/null; }

for triple in $TRIPLES; do
    url=$(asset_url "$triple")
    reachable "$url"
    ok $? "an archive is published for $triple" "$url"

    sum=$(curl -fsSL "$url.sha256" 2>/dev/null | awk '{print $1}')
    printf '%s' "$sum" | grep -qE '^[0-9a-f]{64}$'
    ok $? "and a checksum is published beside it" "got: ${sum:-(none)}"
done

# ---------------------------------------------------------------- 2. 中身
#
# 手元の機械の三つ組だけを実際に落とす。残りは上で「在る」ことまで。

HOST=$(uname -m)-unknown-linux-gnu
case $(uname -s) in
    Darwin) HOST=$(uname -m)-apple-darwin ;;
esac

url=$(asset_url "$HOST")
if curl -fsSL "$url" -o "$WORK/asset.tar.gz" 2>/dev/null; then
    ok 0 "the archive for this machine ($HOST) can be fetched"
else
    ok 1 "the archive for this machine ($HOST) can be fetched" "$url"
fi

published=$(curl -fsSL "$url.sha256" 2>/dev/null | awk '{print $1}')
actual=$(sha256sum "$WORK/asset.tar.gz" 2>/dev/null | awk '{print $1}')
[ -n "$published" ] && [ "$published" = "$actual" ]
ok $? "the archive matches the checksum published beside it" \
     "published: ${published:-(none)}" "actual:    ${actual:-(none)}"

mkdir -p "$WORK/unpacked"
tar xzf "$WORK/asset.tar.gz" -C "$WORK/unpacked" 2>/dev/null
ok $? "the archive unpacks"

# release の本文が「どちらも入っている」と書いている。入っていなければ、
# そこに書かれた手順は2行目で止まる。
[ -x "$WORK/unpacked/dowel" ]
ok $? "it holds dowel" "$(ls "$WORK/unpacked" 2>&1 | paste -sd' ' -)"
[ -x "$WORK/unpacked/dowelup" ]
ok $? "and dowelup, as the release notes say"

said=$("$WORK/unpacked/dowel" --version 2>&1)
[ "$said" = "dowel $VERSION" ]
ok $? "the dowel it holds reports the version this release is named for" \
     "want: dowel $VERSION" "got:  $said"

# ---------------------------------------------------------------- 3. 最初にすること
#
# release の本文に書かれている手順を、書かれているとおりに。Rust の道具立ては
# 使わない——それを要らなくするのがこの配り方の目的である。

export DOWELUP_HOME=$WORK/home
mkdir -p "$WORK/bin"
"$WORK/unpacked/dowelup" shim "$WORK/bin" >/dev/null 2>&1
[ -L "$WORK/bin/dowel" ] || [ -x "$WORK/bin/dowel" ]
ok $? "dowelup shim creates a dowel in the directory it was given"

out=$("$WORK/unpacked/dowelup" default "$VERSION" 2>&1)
rc=$?
ok $rc "dowelup default fetches the version and sets it" "$out"

printf '%s' "$out" | grep -q 'from a release asset'
ok $? "taking the published binary rather than building it" "$out"

said=$("$WORK/bin/dowel" --version 2>&1)
[ "$said" = "dowel $VERSION" ]
ok $? "and the shim runs the version that was asked for" \
     "want: dowel $VERSION" "got:  $said"

# 記録された digest が、公開された `.sha256` と一致すること。利用者が
# あとから突き合わせられる唯一の値である。
recorded=$(grep -h '^asset_sha256=' "$DOWELUP_HOME"/versions/*/origin 2>/dev/null | head -1 | cut -d= -f2)
[ -n "$recorded" ] && [ "$recorded" = "$published" ]
ok $? "the digest it recorded is the one published beside the asset" \
     "published: ${published:-(none)}" "recorded:  ${recorded:-(none)}"

# ---------------------------------------------------------------- 4. 働くこと
#
# 名乗るだけでは足りない。落としてきたもので小さな木を組む。

mkdir -p "$WORK/probe/src"
cat > "$WORK/probe/dowel.toml" <<'EOF'
[package]
name    = "probe"
version = "0.1.0"
edition = "2026"
EOF
printf '[bin.probe]\nsources = [file("src/main.c")]\n' > "$WORK/probe/dowel.build"
printf '#include <stdio.h>\nint main(void){ printf("probe ok\\n"); return 0; }\n' \
    > "$WORK/probe/src/main.c"

out=$("$WORK/bin/dowel" -C "$WORK/probe" build --no-compdb 2>&1)
rc=$?
ok $rc "the dowel that was fetched builds a package" "$out"

built=$(find "$WORK/probe/.dowel/build" -type f -name probe 2>/dev/null | head -1)
said=$([ -n "$built" ] && "$built" 2>&1)
[ "$said" = "probe ok" ]
ok $? "and what it built runs" "want: probe ok" "got:  ${said:-(nothing)}"

# ---------------------------------------------------------------- 結果

printf '\n%s checks: %s passed, %s failed\n' "$((pass + fail))" "$pass" "$fail"
[ "$fail" -eq 0 ]
