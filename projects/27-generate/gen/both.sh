# 1度に2つ書く生成器。bison の `-d`、protoc、flex --header-file が取る形で
# ある。make はこの形の段を取れない。
seed=$1

printf 'extern const int rows[];\nextern const int rows_len;\n' > rows.h
printf '#define ROWS_SEEN %s\n' "$(wc -w < "$seed")" > seen.h
