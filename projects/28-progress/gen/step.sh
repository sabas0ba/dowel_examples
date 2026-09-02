# 同時に走っているかを、**時間ではなく段自身に観測させる**。
#
# 各段は走っている間だけ自分の印を置き、少し待ち、その時点で見えた印の数を
# 記録して、印を片づける。逐次なら常に1、並列なら2以上が現れる。壁時計の
# 閾値に頼ると、負荷の高い機械で falsely 落ちる検査になる
# （docs/00-design.md 6節）。
name=$1
run=$2

: > "$run/$name.running"
sleep 0.5
ls "$run" | grep -c '\.running$' > "$run/$name.seen"
rm -f "$run/$name.running"

# 出てくる見出しは走り方に依らない。依らせると、組み上がったものが
# 同時性の副産物になってしまう。
printf '#define %s_OK 1\n' "$name" > "$name.h"
