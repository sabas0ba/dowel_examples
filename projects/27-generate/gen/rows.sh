# 生成器の代わり。bison や protoc が置かれる位置に在る。
#
# 走る場所は自分の出力が落ちる場所であり（ADR-0054）、種は引数で受ける。
# 出力を相対名で書けるのはそのためである。
seed=$1

printf 'const int rows[] = {' > rows.c
n=0
for w in $(cat "$seed"); do
    printf ' %s,' "$w" >> rows.c
    n=$((n + 1))
done
printf ' 0 };\nconst int rows_len = %s;\n' "$n" >> rows.c
