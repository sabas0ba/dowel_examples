# 実行ラッパの代わり。渡された引数と作業ディレクトリを残してから起動する。
# 末尾が成果物のパスであり、その手前は dowel.build の args そのままである。
printf 'cwd=%s\nargv=%s\n' "$PWD" "$*" > runner-argv.txt
eval exec "\${$#}"
