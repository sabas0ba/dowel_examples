# 見出しの側。同じ種から宣言だけを書く。
seed=$1

printf 'extern const int rows[];\nextern const int rows_len;\n' > rows.h
printf '#define ROWS_SEEN %s\n' "$(wc -w < "$seed")" >> rows.h
